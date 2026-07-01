import Foundation
import CloudKit
import SwiftData
import os

/// チェックイン・完了などの家族イベントを CloudKit 共有ゾーンへ書き込む。
enum CloudKitEventWriter {
    private static let logger = Logger(subsystem: "com.itoguchi.Genki", category: "CloudKitSync")

    static func publishCheckIn(memberName: String, level: GenkiLevel, family: FamilyGroup) async {
        guard FeatureFlags.cloudKitEnabled,
              family.shareRecordName != nil,
              FeatureGate.canSyncToFamily(family: family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = zoneID(for: family, manager: manager) else { return }

        let record = CKRecord(
            recordType: CloudKitManager.checkInRecordType,
            recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        )
        record["memberName"] = memberName as CKRecordValue
        record["date"] = Date.now as CKRecordValue
        record["level"] = level.rawValue as CKRecordValue

        do {
            let db = database(for: family, manager: manager)
            _ = try await manager.saveRecords([record], in: db)
        } catch {
            logger.error("publish check-in error: \(error.localizedDescription)")
        }
    }

    static func publishCompletion(memberName: String, reminderTitle: String, family: FamilyGroup) async {
        guard FeatureFlags.cloudKitEnabled,
              family.shareRecordName != nil,
              FeatureGate.canSyncToFamily(family: family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = zoneID(for: family, manager: manager) else { return }

        let record = CKRecord(
            recordType: CloudKitManager.completionRecordType,
            recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        )
        record["memberName"] = memberName as CKRecordValue
        record["reminderTitle"] = reminderTitle as CKRecordValue
        record["date"] = Date.now as CKRecordValue

        do {
            let db = database(for: family, manager: manager)
            _ = try await manager.saveRecords([record], in: db)
        } catch {
            logger.error("publish completion error: \(error.localizedDescription)")
        }
    }

    /// 共有ゾーンの新着イベントを取得し、家族向けローカル通知を表示する。
    @MainActor
    static func handleRemoteChange(in context: ModelContext) async {
        guard FeatureFlags.cloudKitEnabled else { return }
        let manager = CloudKitManager.shared
        let families = (try? context.fetch(FetchDescriptor<FamilyGroup>())) ?? []

        for family in families where family.shareRecordName != nil {
            await PremiumSync.refreshPremium(from: family, in: context)
            guard FeatureGate.canSyncToFamily(family: family) else { continue }
            guard let zoneID = zoneID(for: family, manager: manager) else { continue }
            let db = database(for: family, manager: manager)
            await notifyNewRecords(ofType: CloudKitManager.checkInRecordType, in: db, zoneID: zoneID) { record in
                let name = record["memberName"] as? String ?? String(localized: "family")
                let levelValue = record["level"] as? Int ?? GenkiLevel.great.rawValue
                let level = GenkiLevel(rawValue: levelValue) ?? .great
                NotificationManager.shared.notifyCheckIn(memberName: name, level: level)
            }
            await notifyNewRecords(ofType: CloudKitManager.completionRecordType, in: db, zoneID: zoneID) { record in
                let name = record["memberName"] as? String ?? String(localized: "family")
                let title = record["reminderTitle"] as? String ?? String(localized: "default_reminder_title")
                NotificationManager.shared.notifyCompletion(memberName: name, reminderTitle: title)
            }
        }
    }

    private static func notifyNewRecords(ofType type: String,
                                         in database: CKDatabase,
                                         zoneID: CKRecordZone.ID,
                                         notify: (CKRecord) -> Void) async {
        let since = Date.now.addingTimeInterval(-120)
        let predicate = NSPredicate(format: "date > %@", since as NSDate)
        let query = CKQuery(recordType: type, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                let author = record["memberName"] as? String ?? ""
                if author == CurrentUser.myName { continue }
                notify(record)
            }
        } catch {
            logger.error("fetch \(type) error: \(error.localizedDescription)")
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
