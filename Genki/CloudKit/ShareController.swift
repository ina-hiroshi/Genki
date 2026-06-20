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

    func prepareShare(for family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        try await manager.requireAvailableAccount()
        try await manager.deleteLegacyZoneIfNeeded()
        try await manager.ensureCustomZone()

        let rootRecordName = family.id.uuidString
        logger.info("prepareShare start root=\(rootRecordName, privacy: .public) zone=\(CloudKitManager.zoneName, privacy: .public)")

        if let stored = family.shareRecordName, stored != rootRecordName {
            family.shareRecordName = nil
        }

        if let existing = await manager.fetchZoneShareIfExists() {
            logger.info("prepareShare reuse zone share url=\(existing.url?.absoluteString ?? "nil", privacy: .public)")
            try await upsertFamilyGroupRoot(rootRecordName: rootRecordName, name: family.name)
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (existing, manager.container)
        }

        do {
            let share = try await createZoneShareOnEmptyZone(for: family)
            try await upsertFamilyGroupRoot(rootRecordName: rootRecordName, name: family.name)
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (share, manager.container)
        } catch {
            logger.error("prepareShare failed, resetting zone: \(error.localizedDescription, privacy: .public)")
            try await manager.resetCustomZone()
            let share = try await createZoneShareOnEmptyZone(for: family)
            try await upsertFamilyGroupRoot(rootRecordName: rootRecordName, name: family.name)
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (share, manager.container)
        }
    }

    /// 空のカスタムゾーンに zone-wide share だけを先に保存する（Apple 推奨順序）。
    private func createZoneShareOnEmptyZone(for family: FamilyGroup) async throws -> CKShare {
        let share = CKShare(recordZoneID: manager.zoneID)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        let savedShare = try await manager.saveZoneShare(share)
        logger.info("prepareShare created zone share url=\(savedShare.url?.absoluteString ?? "nil", privacy: .public)")
        return savedShare
    }

    private func upsertFamilyGroupRoot(rootRecordName: String, name: String) async throws {
        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
        let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        root["name"] = name as CKRecordValue
        _ = try await manager.saveRecords([root], in: manager.privateDB, savePolicy: .allKeys)
    }

    private func stampShareMetadata(on family: FamilyGroup, rootRecordName: String) {
        family.shareRecordName = rootRecordName
        family.cloudKitRootZoneOwnerName = manager.zoneID.ownerName
    }

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

        let zoneOwnerName = metadata.share.recordID.zoneID.ownerName
        let sharedZoneID = CKRecordZone.ID(zoneName: manager.zoneID.zoneName, ownerName: zoneOwnerName)
        let rootRecordName = await manager.fetchFamilyGroupRootRecordName(
            in: sharedZoneID,
            database: manager.sharedDB
        ) ?? metadata.share.recordID.recordName

        let familyName = metadata.share[CKShare.SystemFieldKey.title] as? String ?? "家族"
        ShareAcceptanceStore.storePendingJoin(
            rootRecordName: rootRecordName,
            familyName: familyName.replacingOccurrences(of: "（Genki）", with: ""),
            zoneOwnerName: zoneOwnerName
        )
    }

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
