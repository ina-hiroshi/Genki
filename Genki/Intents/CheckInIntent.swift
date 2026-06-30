import AppIntents
import SwiftData

/// 指定した元気度でチェックインを送る App Intent。
struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_check_in_title"
    static var description = IntentDescription(LocalizedStringResource("intent_check_in_description"))

    static var openAppWhenRun: Bool = false

    @Parameter(title: "genki_level_picker_title", default: .okay)
    var level: GenkiLevelAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = GenkiModelContainer.makeShared()
        let context = container.mainContext

        guard let me = FamilyActions.currentMember(in: context) else {
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "intent_no_family")))
        }

        if me.hasCheckedIn() {
            return .result(dialog: IntentDialog(stringLiteral: String(localized: "intent_already_sent")))
        }

        let genkiLevel = level.genkiLevel
        FamilyActions.checkIn(member: me, level: genkiLevel, in: context, fromAlarm: true)
        let message = String(
            format: String(localized: "intent_success_format"),
            genkiLevel.shortLabel
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
