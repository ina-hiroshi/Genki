import AppIntents

/// Genki が提供する App Shortcut。
struct GenkiShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PromptCheckInIntent(),
            phrases: [
                "\(.applicationName)で元気度を選んでチェックイン",
                "\(.applicationName)のチェックイン",
                "チェックインを\(.applicationName)で送る"
            ],
            shortTitle: LocalizedStringResource("shortcut_prompt_check_in_title"),
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: CheckInIntent(),
            phrases: [
                "\(.applicationName)で元気だよを送る",
                "\(.applicationName)に元気だよ"
            ],
            shortTitle: LocalizedStringResource("shortcut_check_in_title"),
            systemImageName: "sun.max"
        )
    }
}
