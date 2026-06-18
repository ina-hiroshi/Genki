import AppIntents

/// Genki が提供する App Shortcut。
/// 「Hey Siri、元気だよ」や、ショートカット/オートメーションから呼び出せる。
struct GenkiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckInIntent(),
            phrases: [
                "\(.applicationName)で元気だよを送る",
                "\(.applicationName)に元気だよ",
                "元気だよを\(.applicationName)で送る"
            ],
            shortTitle: "元気だよ",
            systemImageName: "sun.max.fill"
        )
    }
}
