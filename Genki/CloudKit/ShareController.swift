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

    /// 既存の hierarchy share があれば返す。なければ nil（UICloudSharingController の preparationHandler で新規作成）。
    func existingShare(for family: FamilyGroup) async throws -> CKShare? {
        try await manager.requireAvailableAccount()
        await manager.deleteLegacyZoneIfNeeded()
        try await manager.ensureCustomZone()

        let rootRecordName = family.id.uuidString
        logger.info("existingShare lookup root=\(rootRecordName, privacy: .public) container=\(self.manager.container.containerIdentifier ?? "?", privacy: .public)")

        if let share = await manager.fetchHierarchyShare(forRootRecordName: rootRecordName, zoneID: manager.zoneID) {
            stampShareMetadata(on: family, rootRecordName: rootRecordName)
            return share
        }
        return nil
    }

    /// Apple サンプルどおり root + share を CKModifyRecordsOperation (.allKeys, atomic) で保存する。
    func saveNewHierarchyShare(for family: FamilyGroup,
                               completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) {
        Task {
            do {
                try await manager.requireAvailableAccount()
                try await manager.ensureCustomZone()

                let rootRecordName = family.id.uuidString
                let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: manager.zoneID)
                let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
                root["name"] = family.name as CKRecordValue

                let shareID = CKRecord.ID(recordName: UUID().uuidString, zoneID: manager.zoneID)
                let share = CKShare(rootRecord: root, shareID: shareID)
                share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
                share.publicPermission = .readWrite

                let op = CKModifyRecordsOperation(recordsToSave: [root, share], recordIDsToDelete: nil)
                op.savePolicy = .allKeys
                op.isAtomic = true
                op.qualityOfService = .userInitiated
                op.modifyRecordsCompletionBlock = { _, _, error in
                    if error == nil {
                        Task { @MainActor in
                            self.stampShareMetadata(on: family, rootRecordName: rootRecordName)
                        }
                    } else if let error {
                        self.logger.error("saveNewHierarchyShare failed: \(error.localizedDescription, privacy: .public)")
                    }
                    completion(share, self.manager.container, error)
                }
                manager.privateDB.add(op)
            } catch {
                completion(nil, nil, error)
            }
        }
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

        let zoneOwnerName = metadata.ownerIdentity.userRecordID?.recordName ?? CKCurrentUserDefaultName
        let zoneID = CKRecordZone.ID(zoneName: metadata.share.recordID.zoneID.zoneName, ownerName: zoneOwnerName)

        if let rootRecordID = metadata.hierarchicalRootRecordID {
            guard let root = await manager.fetchRecordIfExists(with: rootRecordID, in: manager.sharedDB) else {
                throw GenkiCloudError.shareNotFound
            }
            let familyName = root["name"] as? String ?? "家族"
            ShareAcceptanceStore.storePendingJoin(
                rootRecordName: rootRecordID.recordName,
                familyName: familyName,
                zoneOwnerName: zoneOwnerName
            )
            return
        }

        guard let rootRecordName = await manager.fetchFamilyGroupRootRecordName(in: zoneID, database: manager.sharedDB),
              let root = await manager.fetchRecordIfExists(
                with: CKRecord.ID(recordName: rootRecordName, zoneID: zoneID),
                in: manager.sharedDB
              ) else {
            throw GenkiCloudError.shareNotFound
        }
        let familyName = root["name"] as? String ?? "家族"
        ShareAcceptanceStore.storePendingJoin(
            rootRecordName: rootRecordName,
            familyName: familyName,
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
