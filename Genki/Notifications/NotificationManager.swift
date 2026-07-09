import Foundation
import UserNotifications
import os

/// ローカル通知・家族への通知・SOS（Time Sensitive）を扱う。
///
/// 「完了したら家族に通知」はサーバー側では CKSubscription 経由のサイレントプッシュで届き、
/// 受信端末がここのローカル通知ヘルパーで可視通知に変換する。
///
/// アプリ内マスタースイッチがオフのときはリマインド・チェックイン・完了・リアクションを止め、
/// SOS のみ常に配信する。OS の通知許可は設定アプリ側で管理する。
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "Notifications")
    private let defaults = UserDefaults(suiteName: GenkiConstants.appGroupID) ?? .standard

    private init() {
        registerCheckInCategory()
    }

    /// チェックイン通知カテゴリ（目覚まし連携の3アクション）。
    private func registerCheckInCategory() {
        let actions = GenkiLevel.allCases.map { level in
            UNNotificationAction(
                identifier: level.notificationActionID,
                title: level.shortLabel,
                options: []
            )
        }
        let category = UNNotificationCategory(
            identifier: Self.checkInPromptCategoryID,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    static let checkInPromptCategoryID = "CHECKIN_LEVEL"
    static let checkInPromptRequestID = "checkin-prompt"

    // MARK: - アプリ内設定

    /// アプリ内の通知マスタースイッチ。デフォルトはオン。SOS には影響しない。
    var areAppNotificationsEnabled: Bool {
        get {
            if defaults.object(forKey: GenkiConstants.notificationsEnabledKey) == nil {
                return true
            }
            return defaults.bool(forKey: GenkiConstants.notificationsEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: GenkiConstants.notificationsEnabledKey)
            if !newValue {
                removeAllScheduledNotifications()
            }
        }
    }

    /// OS の通知許可状態（UI 表示用。呼び出し側で refresh する）。
    private(set) var systemAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    var isSystemAuthorized: Bool {
        switch systemAuthorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        systemAuthorizationStatus = settings.authorizationStatus
    }

    /// リマインド・家族通知など（SOS 以外）を出してよいか。
    private var shouldDeliverNonSOS: Bool {
        areAppNotificationsEnabled
    }

    /// 目覚まし連携: 元気度を選ぶローカル通知を表示する。
    func scheduleCheckInPrompt() {
        guard shouldDeliverNonSOS else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif_check_in_prompt_title")
        content.body = String(localized: "notif_check_in_prompt_body")
        content.sound = .default
        content.categoryIdentifier = Self.checkInPromptCategoryID
        content.threadIdentifier = "checkin_prompt"

        let request = UNNotificationRequest(
            identifier: Self.checkInPromptRequestID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(request)
    }

    // MARK: - 権限

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            logger.error("authorization error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - リマインドの予約

    /// リマインドをローカル通知として予約する（繰り返し曜日対応）。
    func scheduleReminder(_ reminder: Reminder) {
        cancelReminder(id: reminder.id)
        guard shouldDeliverNonSOS else { return }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = String(localized: "notif_reminder_body")
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

    /// 予約済みのローカル通知をすべて取り消す（データ削除時・通知オフ時）。
    func removeAllScheduledNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - 家族への通知（受信側でローカル化）

    /// 「○○が△△を完了しました」を可視通知として表示する。
    func notifyCompletion(memberName: String, reminderTitle: String) {
        guard shouldDeliverNonSOS else { return }
        let content = UNMutableNotificationContent()
        content.title = String(format: String(localized: "notif_completion_title_format"), memberName, reminderTitle)
        content.body = String(localized: "notif_completion_body")
        content.sound = .default
        content.threadIdentifier = "family"
        deliverNow(content)
    }

    /// 家族へのチェックイン通知（元気度付き）。
    func notifyCheckIn(memberName: String, level: GenkiLevel) {
        guard shouldDeliverNonSOS else { return }
        let content = UNMutableNotificationContent()
        content.title = String(
            format: String(localized: "notif_check_in_title_format"),
            memberName,
            level.shortLabel
        )
        content.body = level.notificationBody
        content.sound = .default
        content.threadIdentifier = "family"
        deliverNow(content)
    }

    /// リアクションが届いたことを通知する。
    func notifyReaction(authorName: String, reaction: ReactionKind) {
        guard shouldDeliverNonSOS else { return }
        let content = UNMutableNotificationContent()
        content.title = String(format: String(localized: "notif_reaction_title_format"), authorName)
        content.body = reaction.accessibilityLabel
        content.sound = .default
        content.threadIdentifier = "family"
        deliverNow(content)
    }

    // MARK: - SOS

    /// SOS 通知を送る。アプリ内スイッチがオフでも常に配信する。
    /// まずは Time Sensitive（申請不要でフォーカスをある程度貫通）。
    /// Critical Alerts のエンタイトルメント承認後は `.critical` に引き上げる。
    func sendSOS(fromMemberName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(format: String(localized: "notif_sos_title_format"), fromMemberName)
        content.body = String(localized: "notif_sos_body")
        content.sound = .default
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
