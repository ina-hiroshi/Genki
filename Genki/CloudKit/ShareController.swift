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
        logger.info("prepareShare start root=\(rootRecordName, privacy: .public)")

        // ローカルにだけ残った古い参照は破棄して作り直す
        if let stored = family.shareRecordName, stored != rootRecordName {
            family.shareRecordName = nil
        }

        // 1) 既存の共有があればそれを再利用する。
        if let existing = await manager.fetchShareIfExists(forRootRecordName: rootRecordName) {
            logger.info("prepareShare reuse existing share url=\(existing.url?.absoluteString ?? "nil", privacy: .public)")
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (existing, manager.container)
        }

        // 2) root レコードを用意（既存があれば再利用、無ければ新規）。
        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
        let root: CKRecord
        if let existingRoot = await manager.fetchRecordIfExists(with: rootID, in: manager.privateDB) {
            logger.info("prepareShare reuse existing root record")
            root = existingRoot
        } else {
            logger.info("prepareShare create new root record")
            root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        }
        root["name"] = family.name as CKRecordValue

        // 3) share を作成して root と同時に atomic 保存する。
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        share.publicPermission = .none

        let saved = try await manager.saveRecords([root, share],
                                                  in: manager.privateDB,
                                                  savePolicy: .allKeys)
        logger.info("prepareShare saveRecords ok count=\(saved.count)")

        stampShareMetadata(on: family, rootRecordName: rootRecordName)

        // 保存に成功していれば share は確実に存在する。
        // 戻り値を recordID で照合し、型が落ちている場合はローカル share に server メタデータをマージして返す。
        if let savedShare = saved[share.recordID] as? CKShare {
            logger.info("prepareShare return saved CKShare url=\(savedShare.url?.absoluteString ?? "nil", privacy: .public)")
            return (savedShare, manager.container)
        }

        // 念のためサーバーから取り直して URL を確実にする。
        if let fetched = await manager.fetchShareIfExists(forRootRecordName: rootRecordName) {
            logger.info("prepareShare re-fetched share url=\(fetched.url?.absoluteString ?? "nil", privacy: .public)")
            return (fetched, manager.container)
        }

        // 保存に成功している以上ローカル share はシェア可能。
        // CKModifyRecordsOperation により server メタデータ（URL 等）が反映済み。
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
