import Foundation
import CloudKit
import SwiftData
import os

/// 共有ゾーンへの Member / Reminder の push / pull。premium とは独立して動作する。
enum FamilyDataSync {
    private static let logger = Logger(subsystem: "com.itoguchi.Genki", category: "FamilyDataSync")

    private static func canSync(_ family: FamilyGroup) -> Bool {
        FeatureFlags.cloudKitEnabled && family.shareRecordName != nil
    }

    // MARK: - Push

    static func pushMember(_ member: Member, family: FamilyGroup) async throws {
        guard canSync(family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)
        let recordID = CKRecord.ID(recordName: member.id.uuidString, zoneID: zoneID)

        let record: CKRecord
        if let existing = await manager.fetchRecordIfExists(with: recordID, in: db) {
            record = existing
        } else {
            record = CKRecord(recordType: CloudKitManager.memberRecordType, recordID: recordID)
        }
        record["name"] = member.name as CKRecordValue
        record["colorIndex"] = member.colorIndex as CKRecordValue
        record["joinedAt"] = member.joinedAt as CKRecordValue

        _ = try await manager.saveRecords([record], in: db)
    }

    static func pushReminder(_ reminder: Reminder, family: FamilyGroup) async throws {
        guard canSync(family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)
        let recordID = CKRecord.ID(recordName: reminder.id.uuidString, zoneID: zoneID)

        let record: CKRecord
        if let existing = await manager.fetchRecordIfExists(with: recordID, in: db) {
            record = existing
        } else {
            record = CKRecord(recordType: CloudKitManager.reminderRecordType, recordID: recordID)
        }
        record["title"] = reminder.title as CKRecordValue
        record["symbolName"] = reminder.symbolName as CKRecordValue
        record["hour"] = reminder.hour as CKRecordValue
        record["minute"] = reminder.minute as CKRecordValue
        record["weekdays"] = encodeWeekdays(reminder.weekdays) as CKRecordValue
        if let oneTimeDate = reminder.oneTimeDate {
            record["oneTimeDate"] = oneTimeDate as CKRecordValue
        }
        record["createdAt"] = reminder.createdAt as CKRecordValue
        if let ownerID = reminder.owner?.id {
            record["ownerID"] = ownerID.uuidString as CKRecordValue
        }

        _ = try await manager.saveRecords([record], in: db)
    }

    static func deleteMember(id: UUID, family: FamilyGroup) async {
        guard canSync(family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        do {
            try await manager.deleteRecords(withIDs: [recordID], in: db)
        } catch {
            logger.error("deleteMember error: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func deleteReminder(id: UUID, family: FamilyGroup) async {
        guard canSync(family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)
        let recordID = CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
        do {
            try await manager.deleteRecords(withIDs: [recordID], in: db)
        } catch {
            logger.error("deleteReminder error: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    static func pushAllLocalData(for family: FamilyGroup, in context: ModelContext) async throws {
        guard canSync(family) else { return }
        for member in family.sortedMembers {
            try await pushMember(member, family: family)
        }
        for reminder in family.sortedReminders {
            try await pushReminder(reminder, family: family)
        }
    }

    /// 失敗しても続行する再同期（家族タブ表示時など）。
    @MainActor
    static func pushAllLocalDataBestEffort(for family: FamilyGroup, in context: ModelContext) async {
        do {
            try await pushAllLocalData(for: family, in: context)
        } catch {
            logger.error("pushAllLocalDataBestEffort error: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Pull

    @MainActor
    static func pullFamilyData(for family: FamilyGroup, in context: ModelContext) async {
        guard canSync(family) else { return }
        let manager = CloudKitManager.shared
        guard let zoneID = manager.zoneID(for: family) else { return }
        let db = manager.database(for: family)

        let memberRecords = await manager.fetchAllRecords(
            ofType: CloudKitManager.memberRecordType,
            in: db,
            zoneID: zoneID
        )
        let reminderRecords = await manager.fetchAllRecords(
            ofType: CloudKitManager.reminderRecordType,
            in: db,
            zoneID: zoneID
        )

        var memberByID: [UUID: Member] = [:]

        for record in memberRecords {
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            let member = findOrCreateMember(id: id, family: family, in: context)
            member.name = record["name"] as? String ?? member.name
            if let colorIndex = record["colorIndex"] as? Int {
                member.colorIndex = colorIndex
            } else if let colorIndex = (record["colorIndex"] as? NSNumber)?.intValue {
                member.colorIndex = colorIndex
            }
            if let joinedAt = record["joinedAt"] as? Date {
                member.joinedAt = joinedAt
            }
            member.family = family
            memberByID[id] = member
        }

        let myID = CurrentUser.myMemberID
        for member in memberByID.values {
            member.isMe = (myID != nil && member.id == myID)
        }

        for record in reminderRecords {
            guard let id = UUID(uuidString: record.recordID.recordName) else { continue }
            let reminder = findOrCreateReminder(id: id, family: family, in: context)
            reminder.title = record["title"] as? String ?? reminder.title
            reminder.symbolName = record["symbolName"] as? String ?? reminder.symbolName
            if let hour = record["hour"] as? Int {
                reminder.hour = hour
            } else if let hour = (record["hour"] as? NSNumber)?.intValue {
                reminder.hour = hour
            }
            if let minute = record["minute"] as? Int {
                reminder.minute = minute
            } else if let minute = (record["minute"] as? NSNumber)?.intValue {
                reminder.minute = minute
            }
            reminder.weekdays = decodeWeekdays(record["weekdays"] as? String)
            reminder.oneTimeDate = record["oneTimeDate"] as? Date
            if let createdAt = record["createdAt"] as? Date {
                reminder.createdAt = createdAt
            }
            reminder.family = family
            if let ownerIDString = record["ownerID"] as? String,
               let ownerID = UUID(uuidString: ownerIDString) {
                reminder.owner = memberByID[ownerID]
            }
        }

        try? context.save()
        FamilyActions.rebuildSnapshot(in: context)
    }

    // MARK: - Helpers

    @MainActor
    private static func findOrCreateMember(id: UUID, family: FamilyGroup, in context: ModelContext) -> Member {
        if let existing = fetchMember(id: id, in: context) {
            return existing
        }
        let member = Member(id: id, name: "", colorIndex: 0)
        member.family = family
        context.insert(member)
        return member
    }

    @MainActor
    private static func findOrCreateReminder(id: UUID, family: FamilyGroup, in context: ModelContext) -> Reminder {
        if let existing = fetchReminder(id: id, in: context) {
            return existing
        }
        let reminder = Reminder(id: id, title: "")
        reminder.family = family
        context.insert(reminder)
        return reminder
    }

    @MainActor
    private static func fetchMember(id: UUID, in context: ModelContext) -> Member? {
        let targetID = id
        var descriptor = FetchDescriptor<Member>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private static func fetchReminder(id: UUID, in context: ModelContext) -> Reminder? {
        let targetID = id
        var descriptor = FetchDescriptor<Reminder>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func encodeWeekdays(_ weekdays: [Int]) -> String {
        weekdays.sorted().map(String.init).joined(separator: ",")
    }

    private static func decodeWeekdays(_ value: String?) -> [Int] {
        guard let value, !value.isEmpty else { return [] }
        return value.split(separator: ",").compactMap { Int($0) }
    }
}
