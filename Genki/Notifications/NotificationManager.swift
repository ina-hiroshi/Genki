import Foundation
import UserNotifications
import os

/// ローカル通知・家族への通知・SOS（Time Sensitive）を扱う。
///
/// 「完了したら家族に通知」はサーバー側では CKSubscription 経由のサイレントプッシュで届き、
/// 受信端末がここのローカル通知ヘルパーで可視通知に変換する。
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "Notifications")

    private init() {}

    // MARK: - 権限

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("authorization error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - リマインドの予約

    /// リマインドをローカル通知として予約する（繰り返し曜日対応）。
    func scheduleReminder(_ reminder: Reminder) {
        cancelReminder(id: reminder.id)

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "そろそろ時間です"
        content.sound = .default
        content.threadIdentifier = "reminder"

        var components = DateComponents()
        components.hour = reminder.hour
        components.minute = reminder.minute

        if reminder.isRepeating {
            for weekday in reminder.weekdays {
                var comps = components
                comps.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let request = UNNotificationRequest(
                    identifier: requestID(for: reminder.id, weekday: weekday),
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        } else {
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: requestID(for: reminder.id, weekday: nil),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelReminder(id: UUID) {
        let ids = (1...7).map { requestID(for: id, weekday: $0) } + [requestID(for: id, weekday: nil)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// 予約済みのローカル通知をすべて取り消す（データ削除時）。
    func removeAllScheduledNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - 家族への通知（受信側でローカル化）

    /// 「○○が△△を完了しました」を可視通知として表示する。
    func notifyCompletion(memberName: String, reminderTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(memberName)が\(reminderTitle)をしました"
        content.body = "リアクションを送って応援しよう"
        content.sound = .default
        content.threadIdentifier = "family"
        deliverNow(content)
    }

    /// 「○○が元気だよを送りました」。
    func notifyCheckIn(memberName: String) {
        let content = UNMutableNotificationContent()
        content.title = "\(memberName)が元気だよを送りました"
        content.body = "今日も安心ですね"
        content.sound = .default
        content.threadIdentifier = "family"
        deliverNow(content)
    }

    /// リアクションが届いたことを通知する。
    func notifyReaction(authorName: String, reaction: ReactionKind) {
        let content = UNMutableNotificationContent()
        content.title = "\(authorName)からリアクション"
        content.body = reaction.accessibilityLabel
        content.sound = .default
        content.threadIdentifier = "family"
        deliverNow(content)
    }

    // MARK: - SOS

    /// SOS 通知を送る。まずは Time Sensitive（申請不要でフォーカスをある程度貫通）。
    /// Critical Alerts のエンタイトルメント承認後は `.critical` に引き上げる。
    func sendSOS(fromMemberName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🆘 \(fromMemberName)からのSOS"
        content.body = "今すぐ連絡してください"
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = "sos"
        deliverNow(content)
    }

    // MARK: - Helpers

    private func deliverNow(_ content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(request)
    }

    private func requestID(for reminderID: UUID, weekday: Int?) -> String {
        if let weekday {
            return "reminder-\(reminderID.uuidString)-\(weekday)"
        }
        return "reminder-\(reminderID.uuidString)-once"
    }
}
