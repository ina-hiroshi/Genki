import Foundation
import CloudKit
import SwiftData
import os

/// 家族グループの CKShare 発行・受諾を扱う。共有リンクで家族を招待する。
final class ShareController {
    private let manager: CloudKitManager
    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "ShareController")

    init(manager: CloudKitManager = .shared) {
        self.manager = manager
    }

    /// 家族グループ用の CKShare を取得または作成する。
    func prepareShare(for family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        try await manager.requireAvailableAccount()
        try await manager.ensureCustomZone()

        let rootRecordName = family.id.uuidString
        logger.info("prepareShare start root=\(rootRecordName, privacy: .public) container=\(GenkiConstants.iCloudContainerID, privacy: .public)")

        if let stored = family.shareRecordName, stored != rootRecordName {
            family.shareRecordName = nil
        }

        if let existing = await manager.fetchShareIfExists(forRootRecordName: rootRecordName) {
            logger.info("prepareShare reuse existing share url=\(existing.url?.absoluteString ?? "nil", privacy: .public)")
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (existing, manager.container)
        }

        try await manager.deleteBrokenRootShare(forRootRecordName: rootRecordName)

        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
        let serverRoot = try await upsertRootRecord(id: rootID, name: family.name)

        if let existing = await manager.fetchShareIfExists(forRootRecordName: rootRecordName) {
            logger.info("prepareShare share appeared after root upsert")
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (existing, manager.container)
        }

        let share = makeShare(for: family, root: serverRoot)
        let saved = try await manager.saveRecords([share],
                                                  in: manager.privateDB,
                                                  savePolicy: .allKeys)
        logger.info("prepareShare saved share count=\(saved.count)")
        return try await resolveShare(from: saved, share: share, rootRecordName: rootRecordName, family: family)
    }

    /// 1) root をサーバーに保存 → 2) 最新 root を取得、という Apple 推奨フロー。
    private func upsertRootRecord(id rootID: CKRecord.ID, name: String) async throws -> CKRecord {
        if let existing = await manager.fetchRecordIfExists(with: rootID, in: manager.privateDB) {
            logger.info("prepareShare update existing root")
            existing["name"] = name as CKRecordValue
            _ = try await manager.saveRecords([existing],
                                              in: manager.privateDB,
                                              savePolicy: .changedKeys)
        } else {
            logger.info("prepareShare create root on server")
            let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
            root["name"] = name as CKRecordValue
            _ = try await manager.saveRecords([root],
                                              in: manager.privateDB,
                                              savePolicy: .allKeys)
        }

        guard let serverRoot = await manager.fetchRecordIfExists(with: rootID, in: manager.privateDB) else {
            throw GenkiCloudError.shareNotFound
        }
        return serverRoot
    }

    private func makeShare(for family: FamilyGroup, root: CKRecord) -> CKShare {
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        share.publicPermission = .none
        return share
    }

    private func resolveShare(from saved: [CKRecord.ID: CKRecord],
                              share: CKShare,
                              rootRecordName: String,
                              family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        stampShareMetadata(on: family, rootRecordName: rootRecordName)

        if let savedShare = saved[share.recordID] as? CKShare {
            logger.info("prepareShare return saved CKShare url=\(savedShare.url?.absoluteString ?? "nil", privacy: .public)")
            return (savedShare, manager.container)
        }

        if let fetched = await manager.fetchShareIfExists(forRootRecordName: rootRecordName) {
            logger.info("prepareShare re-fetched share url=\(fetched.url?.absoluteString ?? "nil", privacy: .public)")
            return (fetched, manager.container)
        }

        logger.info("prepareShare fallback to local share url=\(share.url?.absoluteString ?? "nil", privacy: .public)")
        return (share, manager.container)
    }

    private func stampShareMetadata(on family: FamilyGroup, rootRecordName: String) {
        family.shareRecordName = rootRecordName
        family.cloudKitRootZoneOwnerName = manager.zoneID.ownerName
    }

    /// 受け取った共有メタデータを受諾し、参加オンボーディング用の状態を保存する。
    func accept(_ metadata: CKShare.Metadata) async throws {
        try await manager.requireAvailableAccount()

        let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
        op.qualityOfService = .userInitiated
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            manager.container.add(op)
        }

        let rootRecordID = metadata.hierarchicalRootRecordID ?? metadata.rootRecordID
        guard let root = await manager.fetchRecordIfExists(with: rootRecordID, in: manager.sharedDB) else {
            throw GenkiCloudError.shareNotFound
        }
        let familyName = root["name"] as? String ?? "家族"
        ShareAcceptanceStore.storePendingJoin(
            rootRecordName: rootRecordID.recordName,
            familyName: familyName,
            zoneOwnerName: rootRecordID.zoneID.ownerName
        )
    }

    /// 参加オンボーディング完了時に、共有ゾーンの家族をローカル SwiftData に取り込む。
    @MainActor
    func completeJoin(name: String,
                      colorIndex: Int,
                      rootRecordName: String,
                      familyName: String,
                      zoneOwnerName: String,
                      in context: ModelContext) throws {
        let familyID = UUID(uuidString: rootRecordName) ?? UUID()
        let family = FamilyGroup(id: familyID, name: familyName)
        family.shareRecordName = rootRecordName
        family.cloudKitRootZoneOwnerName = zoneOwnerName
        context.insert(family)

        let me = Member(name: name, colorIndex: colorIndex, isMe: true)
        me.family = family
        context.insert(me)
        try context.save()

        CurrentUser.myMemberID = me.id
        CurrentUser.myName = me.name
        CurrentUser.isOnboarded = true
        ShareAcceptanceStore.clear()
        FamilyActions.rebuildSnapshot(in: context)
    }
}
