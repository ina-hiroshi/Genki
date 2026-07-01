import Foundation
import SwiftData

/// データ操作のコアロジック。UI と App Intent の双方から使えるよう、
/// ModelContext を受け取る静的関数として提供する。
@MainActor
enum FamilyActions {

    // MARK: - 取得

    /// この端末の本人（Member）を取得。無ければ最初のメンバー。
    static func currentMember(in context: ModelContext) -> Member? {
        let descriptor = FetchDescriptor<Member>()
        let members = (try? context.fetch(descriptor)) ?? []
        if let id = CurrentUser.myMemberID, let me = members.first(where: { $0.id == id }) {
            return me
        }
        return members.first(where: { $0.isMe }) ?? members.first
    }

    static func currentFamily(in context: ModelContext) -> FamilyGroup? {
        let descriptor = FetchDescriptor<FamilyGroup>()
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - チェックイン

    /// 体調チェックインを記録する。同日は更新（元気度・ひとことを変更可）。
    @discardableResult
    static func checkIn(member: Member,
                        level: GenkiLevel = .okay,
                        note: String? = nil,
                        in context: ModelContext,
                        fromAlarm: Bool = false) -> CheckIn? {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedNote = trimmedNote?.isEmpty == true ? nil : trimmedNote

        let checkIn: CheckIn
        let isUpdate: Bool
        if let existing = member.todaysCheckIn() {
            existing.genkiLevel = level
            existing.note = savedNote
            existing.date = .now
            if fromAlarm { existing.fromAlarm = true }
            checkIn = existing
            isUpdate = true
        } else {
            checkIn = CheckIn(level: level.rawValue, note: savedNote, fromAlarm: fromAlarm, member: member)
            context.insert(checkIn)
            isUpdate = false
        }

        try? context.save()
        rebuildSnapshot(in: context)

        if let family = member.family {
            Task {
                await CloudKitEventWriter.publishCheckIn(
                    memberName: member.name,
                    level: level,
                    family: family
                )
            }
        }

        if !isUpdate {
            NotificationManager.shared.notifyCheckIn(memberName: member.name, level: level)
        }

        return checkIn
    }

    // MARK: - 完了

    /// リマインドを完了として記録し、家族に通知する。
    @discardableResult
    static func complete(reminder: Reminder, by member: Member, in context: ModelContext) -> CompletionLog {
        let log = CompletionLog(reminder: reminder, member: member)
        context.insert(log)
        try? context.save()
        NotificationManager.shared.notifyCompletion(memberName: member.name, reminderTitle: reminder.title)
        rebuildSnapshot(in: context)
        if let family = reminder.family ?? member.family {
            Task {
                await CloudKitEventWriter.publishCompletion(
                    memberName: member.name,
                    reminderTitle: reminder.title,
                    family: family
                )
            }
        }
        return log
    }

    // MARK: - リアクション

    static func react(_ kind: ReactionKind, toCompletion log: CompletionLog, author: Member, in context: ModelContext) {
        let reaction = Reaction(kind: kind, authorName: author.name, completion: log)
        context.insert(reaction)
        try? context.save()
    }

    static func react(_ kind: ReactionKind, toCheckIn checkIn: CheckIn, author: Member, in context: ModelContext) {
        let reaction = Reaction(kind: kind, authorName: author.name, checkIn: checkIn)
        context.insert(reaction)
        try? context.save()
    }

    // MARK: - リマインド

    static func addReminder(title: String,
                            symbolName: String,
                            hour: Int,
                            minute: Int,
                            weekdays: [Int],
                            owner: Member?,
                            family: FamilyGroup?,
                            in context: ModelContext) {
        let reminder = Reminder(title: title, symbolName: symbolName, hour: hour, minute: minute, weekdays: weekdays)
        if weekdays.isEmpty {
            reminder.oneTimeDate = Calendar.current.startOfDay(for: .now)
        }
        reminder.owner = owner
        reminder.family = family
        context.insert(reminder)
        try? context.save()
        NotificationManager.shared.scheduleReminder(reminder)
        rebuildSnapshot(in: context)
    }

    static func delete(reminder: Reminder, in context: ModelContext) {
        NotificationManager.shared.cancelReminder(id: reminder.id)
        context.delete(reminder)
        try? context.save()
        rebuildSnapshot(in: context)
    }

    // MARK: - スナップショット（ウィジェット / Watch 用）

    /// 現在の状態を App Group の共有ストアに書き出す。
    static func rebuildSnapshot(in context: ModelContext) {
        guard let family = currentFamily(in: context) else {
            GenkiSharedStore().save(.empty)
            return
        }
        let members = family.sortedMembers.map { member in
            MemberStatus(id: member.id.uuidString,
                         name: member.name,
                         colorIndex: member.colorIndex,
                         checkedInToday: member.hasCheckedIn(),
                         genkiLevel: member.todaysGenkiLevel())
        }
        let upcoming = family.sortedReminders
            .filter { $0.isScheduled() }
            .prefix(5)
            .map { reminder in
                ReminderStatus(id: reminder.id.uuidString,
                               title: reminder.title,
                               ownerName: reminder.owner?.name ?? "",
                               time: reminder.timeText,
                               done: reminder.isCompleted(),
                               colorIndex: reminder.owner?.colorIndex ?? 0)
            }
        let snapshot = FamilySnapshot(familyName: family.name,
                                      members: members,
                                      upcoming: Array(upcoming),
                                      hasFullAccess: EntitlementStore.shared.hasFullAccess(for: family))
        GenkiSharedStore().save(snapshot)
        PhoneSessionManager.shared.send(snapshot: snapshot)
    }
}
