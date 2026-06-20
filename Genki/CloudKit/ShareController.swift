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

        if let existing = await manager.fetchZoneShareIfExists() {
            try await upsertFamilyGroupRoot(rootRecordName: rootRecordName, name: family.name, zoneID: manager.zoneID)
            stampShareMetadata(on: family, rootRecordName: rootRecordName, zoneName: manager.zoneID.zoneName)
            return (existing, manager.container)
        }

        if let existing = await manager.fetchHierarchyShare(forRootRecordName: rootRecordName, zoneID: manager.zoneID) {
            stampShareMetadata(on: family, rootRecordName: rootRecordName, zoneName: manager.zoneID.zoneName)
            return (existing, manager.container)
        }

        let defaultZoneID = CKRecordZone.default().zoneID
        if let existing = await manager.fetchHierarchyShare(forRootRecordName: rootRecordName, zoneID: defaultZoneID) {
            stampShareMetadata(on: family, rootRecordName: rootRecordName, zoneName: defaultZoneID.zoneName)
            return (existing, manager.container)
        }

        var errors: [Error] = []

        try await manager.ensureCustomZone()
        do {
            let share = try await createZoneWideShare(for: family)
            try await upsertFamilyGroupRoot(rootRecordName: rootRecordName, name: family.name, zoneID: manager.zoneID)
            stampShareMetadata(on: family, rootRecordName: rootRecordName, zoneName: manager.zoneID.zoneName)
            return (share, manager.container)
        } catch {
            logger.error("zone-wide share failed: \(error.localizedDescription, privacy: .public)")
            errors.append(error)
        }

        do {
            try await manager.resetCustomZone()
            let share = try await createHierarchyShare(for: family,
                                                       rootRecordName: rootRecordName,
                                                       zoneID: manager.zoneID)
            stampShareMetadata(on: family, rootRecordName: rootRecordName, zoneName: manager.zoneID.zoneName)
            return (share, manager.container)
        } catch {
            logger.error("hierarchy share (custom zone) failed: \(error.localizedDescription, privacy: .public)")
            errors.append(error)
        }

        do {
            let share = try await createHierarchyShare(for: family,
                                                       rootRecordName: rootRecordName,
                                                       zoneID: defaultZoneID)
            stampShareMetadata(on: family, rootRecordName: rootRecordName, zoneName: defaultZoneID.zoneName)
            return (share, manager.container)
        } catch {
            logger.error("hierarchy share (default zone) failed: \(error.localizedDescription, privacy: .public)")
            errors.append(error)
        }

        throw errors.last ?? GenkiCloudError.shareNotFound
    }

    private func createZoneWideShare(for family: FamilyGroup) async throws -> CKShare {
        let share = CKShare(recordZoneID: manager.zoneID)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue
        return try await manager.saveZoneShare(share)
    }

    private func createHierarchyShare(for family: FamilyGroup,
                                      rootRecordName: String,
                                      zoneID: CKRecordZone.ID) async throws -> CKShare {
        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: zoneID)
        let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        root["name"] = family.name as CKRecordValue
        let share = CKShare(rootRecord: root)
        share[CKShare.SystemFieldKey.title] = "\(family.name)（Genki）" as CKRecordValue

        let saved = try await manager.saveRecords([root, share], in: manager.privateDB, savePolicy: .allKeys)
        if let ckShare = saved[share.recordID] as? CKShare { return ckShare }
        if let fetched = await manager.fetchHierarchyShare(forRootRecordName: rootRecordName, zoneID: zoneID) {
            return fetched
        }
        throw GenkiCloudError.shareNotFound
    }

    private func upsertFamilyGroupRoot(rootRecordName: String, name: String, zoneID: CKRecordZone.ID) async throws {
        let rootID = CKRecord.ID(recordName: rootRecordName, zoneID: zoneID)
        let root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
        root["name"] = name as CKRecordValue
        _ = try await manager.saveRecords([root], in: manager.privateDB, savePolicy: .allKeys)
    }

    private func stampShareMetadata(on family: FamilyGroup, rootRecordName: String, zoneName: String) {
        family.shareRecordName = rootRecordName
        family.cloudKitZoneName = zoneName
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
        let zoneName = metadata.share.recordID.zoneID.zoneName
        let sharedZoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: zoneOwnerName)
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
