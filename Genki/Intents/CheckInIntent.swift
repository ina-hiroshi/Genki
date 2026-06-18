import AppIntents
import SwiftData

/// 「元気だよ」を送る App Intent。
///
/// 目覚まし連携の中核: iOS の「オートメーション → アラームを停止したとき」に
/// このインテントを紐づけると、起床と同時に家族へ「元気だよ」が自動送信される。
struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "元気だよを送る"
    static var description = IntentDescription("家族に「元気だよ」を送ります。目覚ましのオートメーションに設定すると、起きたら自動で届きます。")

    /// バックグラウンドで完結させたいのでアプリは開かない。
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = GenkiModelContainer.makeShared()
        let context = container.mainContext

        guard let me = FamilyActions.currentMember(in: context) else {
            return .result(dialog: "先にGenkiで家族グループを作成してください。")
        }

        if me.hasCheckedIn() {
            return .result(dialog: "今日はもう元気だよを送っています。")
        }

        FamilyActions.checkIn(member: me, in: context, fromAlarm: true)
        NotificationManager.shared.notifyCheckIn(memberName: me.name)
        return .result(dialog: "おはようございます。家族に「元気だよ」を送りました。")
    }
}
