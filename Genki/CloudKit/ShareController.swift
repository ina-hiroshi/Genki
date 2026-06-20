import Foundation
import CloudKit
import SwiftData
import os

/// 家族グループの CKShare 発行・受諾を扱う。
final class ShareController {
    private let manager: CloudKitManager
    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "ShareController")

    init(manager: CloudKitManager = .shared) {
        self.manager = manager
    }

    func prepareShare(for family: FamilyGroup) async throws -> (CKShare, CKContainer) {
        try await manager.requireAvailableAccount()
        try await manager.deleteLegacyZoneIfNeeded()

        let rootRecordName = family.id.uuidString
        logger.info("prepareShare start root=\(rootRecordName, privacy: .public)")

        if let stored = family.shareRecordName, stored != rootRecordName {
            family.shareRecordName = nil
            family.cloudKitZoneName = nil
        }

        if let existing = await manager.fetchHierarchyShare(forRootRecordName: rootRecordName,
                                                            zoneID: manager.zoneID) {
            logger.info("prepareShare reuse hierarchy share url=\(existing.url?.absoluteString ?? "nil", privacy: .public)")
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return (existing, manager.container)
        }

        // カスタムゾーンを空にして root + share を同時保存（Apple 公式 hierarchy share パターン）。
        try await manager.resetCustomZone()

        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
        let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        root["name"] = family.name as CKRecordValue

        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue

        let saved = try await manager.saveRecords([root, share],
                                                  in: manager.privateDB,
                                                  savePolicy: .allKeys)
        logger.info("prepareShare saved root+share count=\(saved.count)")

        let ckShare: CKShare
        if let savedShare = saved[share.recordID] as? CKShare {
            ckShare = savedShare
        } else if let fetched = await manager.fetchHierarchyShare(forRootRecordName: rootRecordName,
                                                                  zoneID: manager.zoneID) {
            ckShare = fetched
        } else {
            throw GenkiCloudError.shareNotFound
        }

        stampShareMetadata(on: family, rootRecordName: rootRecordName)
        return (ckShare, manager.container)
    }

    private func stampShareMetadata(on family: FamilyGroup, rootRecordName: String) {
        family.shareRecordName = rootRecordName
        family.cloudKitZoneName = manager.zoneID.zoneName
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
        family.cloudKitZoneName = CloudKitManager.zoneName
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
