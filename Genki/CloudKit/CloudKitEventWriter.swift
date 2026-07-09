import Foundation
import CloudKit
import SwiftData
import os

/// チェックイン・完了などの家族イベントを CloudKit 共有ゾーンへ書き込む。
enum CloudKitEventWriter {
    private static let logger = Logger(subsystem: "com.itoguchi.Genki", category: "CloudKitSync")

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static func dayKey(for date: Date = .now) -> String {
        dayFormatter.string(from: date)
    }

    static func checkInRecordName(memberID: UUID, day: Date = .now) -> String {
        "\(memberID.uuidString)_\(dayKey(for: day))"
    }

    static func completionRecordName(reminderID: UUID, day: Date = .now) -> String {
        "\(reminderID.uuidString)_\(dayKey(for: day))"
    }

    static func publishCheckIn(member: Member,
                               level: GenkiLevel,
                               note: String?,
                               family: FamilyGroup) async {
        guard FeatureFlags.cloudKitEnabled,
              family.shareRecordName != nil,
              FeatureGate.canSyncToFamily(family: family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)
        let recordID = CKRecord.ID(
            recordName: checkInRecordName(memberID: member.id),
            zoneID: zoneID
        )

        let record: CKRecord
        if let existing = await manager.fetchRecordIfExists(with: recordID, in: db) {
            record = existing
        } else {
            record = CKRecord(recordType: CloudKitManager.checkInRecordType, recordID: recordID)
        }
        record["memberName"] = member.name as CKRecordValue
        record["memberID"] = member.id.uuidString as CKRecordValue
        record["date"] = Date.now as CKRecordValue
        record["level"] = level.rawValue as CKRecordValue
        if let note, !note.isEmpty {
            record["note"] = note as CKRecordValue
        }

        do {
            _ = try await manager.saveRecords([record], in: db)
        } catch {
            logger.error("publish check-in error: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func publishCompletion(member: Member,
                                  reminder: Reminder,
                                  family: FamilyGroup) async {
        guard FeatureFlags.cloudKitEnabled,
              family.shareRecordName != nil,
              FeatureGate.canSyncToFamily(family: family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)
        let recordID = CKRecord.ID(
            recordName: completionRecordName(reminderID: reminder.id),
            zoneID: zoneID
        )

        let record: CKRecord
        if let existing = await manager.fetchRecordIfExists(with: recordID, in: db) {
            record = existing
        } else {
            record = CKRecord(recordType: CloudKitManager.completionRecordType, recordID: recordID)
        }
        record["memberName"] = member.name as CKRecordValue
        record["memberID"] = member.id.uuidString as CKRecordValue
        record["reminderTitle"] = reminder.title as CKRecordValue
        record["reminderID"] = reminder.id.uuidString as CKRecordValue
        record["date"] = Date.now as CKRecordValue

        do {
            _ = try await manager.saveRecords([record], in: db)
        } catch {
            logger.error("publish completion error: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 共有ゾーンの変更を取り込み、必要ならローカル通知も出す。
    @MainActor
    static func handleRemoteChange(in context: ModelContext) async {
        guard FeatureFlags.cloudKitEnabled else { return }
        let families = (try? context.fetch(FetchDescriptor<FamilyGroup>())) ?? []

        for family in families where family.shareRecordName != nil {
            await PremiumSync.refreshPremium(from: family, in: context)
            await FamilyDataSync.pullFamilyData(for: family, in: context)
            await FamilyDataSync.pullCheckIns(for: family, in: context)
            await FamilyDataSync.pullCompletions(for: family, in: context)

            guard FeatureGate.canSyncToFamily(family: family) else { continue }
            await notifyRecentActivity(for: family)
        }
    }

    @MainActor
    private static func notifyRecentActivity(for family: FamilyGroup) async {
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)

        await notifyNewRecords(ofType: CloudKitManager.checkInRecordType, in: db, zoneID: zoneID) { record in
            let name = record["memberName"] as? String ?? String(localized: "family")
            let levelValue = intValue(record["level"]) ?? GenkiLevel.great.rawValue
            let level = GenkiLevel(rawValue: levelValue) ?? .great
            NotificationManager.shared.notifyCheckIn(memberName: name, level: level)
        }
        await notifyNewRecords(ofType: CloudKitManager.completionRecordType, in: db, zoneID: zoneID) { record in
            let name = record["memberName"] as? String ?? String(localized: "family")
            let title = record["reminderTitle"] as? String ?? String(localized: "default_reminder_title")
            NotificationManager.shared.notifyCompletion(memberName: name, reminderTitle: title)
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
                if let memberID = record["memberID"] as? String,
                   let myID = CurrentUser.myMemberID?.uuidString,
                   memberID == myID {
                    continue
                }
                notify(record)
            }
        } catch {
            logger.error("fetch \(type, privacy: .public) error: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func intValue(_ value: CKRecordValueProtocol?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}
