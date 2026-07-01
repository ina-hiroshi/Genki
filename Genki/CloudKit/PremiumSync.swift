import Foundation
import CloudKit
import SwiftData
import os

/// 家族フル版状態（`premiumUnlockedAt`）の CloudKit 読み書き。
enum PremiumSync {
    private static let logger = Logger(subsystem: "com.itoguchi.Genki", category: "PremiumSync")

    @MainActor
    static func writePremiumUnlocked(family: FamilyGroup, in context: ModelContext) async throws {
        guard FeatureFlags.cloudKitEnabled, let rootName = family.shareRecordName else {
            family.premiumUnlockedAt = family.premiumUnlockedAt ?? .now
            try? context.save()
            return
        }

        let manager = CloudKitManager.shared
        guard let zoneID = zoneID(for: family, manager: manager) else { return }
        let db = database(for: family, manager: manager)
        let rootID = CKRecord.ID(recordName: rootName, zoneID: zoneID)

        let root: CKRecord
        if let existing = await manager.fetchRecordIfExists(with: rootID, in: db) {
            root = existing
        } else {
            root = CKRecord(recordType: CloudKitManager.familyGroupRecordType, recordID: rootID)
            root["name"] = family.name as CKRecordValue
        }

        let unlockedAt = family.premiumUnlockedAt ?? .now
        root["premiumUnlockedAt"] = unlockedAt as CKRecordValue
        _ = try await manager.saveRecords([root], in: db)

        family.premiumUnlockedAt = unlockedAt
        try? context.save()
        logger.info("premiumUnlockedAt written to CloudKit")
    }

    @MainActor
    static func refreshPremium(from family: FamilyGroup?, in context: ModelContext) async {
        guard FeatureFlags.cloudKitEnabled,
              let family,
              let rootName = family.shareRecordName else { return }

        let manager = CloudKitManager.shared
        guard let zoneID = zoneID(for: family, manager: manager) else { return }
        let db = database(for: family, manager: manager)
        let rootID = CKRecord.ID(recordName: rootName, zoneID: zoneID)

        guard let root = await manager.fetchRecordIfExists(with: rootID, in: db),
              let premiumDate = root["premiumUnlockedAt"] as? Date else { return }

        if family.premiumUnlockedAt != premiumDate {
            family.premiumUnlockedAt = premiumDate
            try? context.save()
            FamilyActions.rebuildSnapshot(in: context)
        }
    }

    private static func zoneID(for family: FamilyGroup, manager: CloudKitManager) -> CKRecordZone.ID? {
        guard family.shareRecordName != nil else { return nil }
        let owner = family.cloudKitRootZoneOwnerName ?? manager.zoneID.ownerName
        let zoneName = family.cloudKitZoneName ?? manager.zoneID.zoneName
        return CKRecordZone.ID(zoneName: zoneName, ownerName: owner)
    }

    private static func database(for family: FamilyGroup, manager: CloudKitManager) -> CKDatabase {
        guard let storedOwner = family.cloudKitRootZoneOwnerName else {
            return manager.privateDB
        }
        return storedOwner == manager.zoneID.ownerName ? manager.privateDB : manager.sharedDB
    }
}
