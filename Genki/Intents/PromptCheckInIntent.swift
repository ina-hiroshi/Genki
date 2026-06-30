import AppIntents
import SwiftData

/// 目覚まし連携用: 元気度を選ぶローカル通知を表示する App Intent。
///
/// iOS の「オートメーション → アラームを停止したとき」に紐づけると、
/// 起床後に通知の3ボタンから元気度を選んでチェックインできる。
struct PromptCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_prompt_check_in_title"
    static var description = IntentDescription(LocalizedStringResource("intent_prompt_check_in_description"))

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = GenkiModelContainer.makeShared()
        let context = container.mainContext

        guard FamilyActions.currentMember(in: context) != nil else {
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "intent_no_family")))
        }

        if let me = FamilyActions.currentMember(in: context), me.hasCheckedIn() {
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "intent_already_sent")))
        }

        NotificationManager.shared.scheduleCheckInPrompt()
        return .result(dialog: IntentDialog(stringLiteral: String(localized: "intent_prompt_success")))
    }
}
