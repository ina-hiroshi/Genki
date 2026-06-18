import Foundation
import SwiftData

/// アカウント相当（家族プロフィール・ローカルデータ）の削除。
///
/// Genki はメール/パスワードのアカウント登録はありませんが、
/// 家族グループ・メンバー情報・履歴を端末/iCloud に保存するため、
/// App Store ガイドライン 5.1.1(v) に従いアプリ内から削除できるようにする。
@MainActor
enum AccountActions {

    /// この端末のすべての Genki データを削除し、初回起動状態に戻す。
    static func deleteAllUserData(in context: ModelContext) {
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        for reminder in reminders {
            NotificationManager.shared.cancelReminder(id: reminder.id)
        }

        let families = (try? context.fetch(FetchDescriptor<FamilyGroup>())) ?? []
        for family in families {
            context.delete(family)
        }
        try? context.save()

        EscalationManager.shared.cancel()
        NotificationManager.shared.removeAllScheduledNotifications()
        GenkiSharedStore().save(.empty)
        clearAppGroupPreferences()
        ShareAcceptanceStore.clear()
        CurrentUser.reset()
    }

    private static func clearAppGroupPreferences() {
        guard let defaults = UserDefaults(suiteName: GenkiConstants.appGroupID) else { return }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("genki.") {
            defaults.removeObject(forKey: key)
        }
    }
}
