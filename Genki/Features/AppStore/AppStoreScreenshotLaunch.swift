import SwiftUI

/// 起動引数 `-AppStoreScreenshot <id>` / 環境変数 `APPSTORE_SCREENSHOT` で表示する画面。
enum AppStoreScreenshot: String, CaseIterable {
    case home = "home"
    case reminders = "reminders"
    case checkIn = "check_in"
    case family = "family"
    case paywall = "paywall"

    var outputFilename: String {
        switch self {
        case .home: return "01_home.png"
        case .checkIn: return "02_check_in.png"
        case .reminders: return "03_reminders.png"
        case .family: return "04_family.png"
        case .paywall: return "05_paywall.png"
        }
    }
}

enum AppStoreScreenshotLaunch {
    static var current: AppStoreScreenshot? {
        if let stored = UserDefaults.standard.string(forKey: "APPSTORE_SCREENSHOT"),
           let screen = AppStoreScreenshot(rawValue: stored) {
            return screen
        }

        if let env = ProcessInfo.processInfo.environment["APPSTORE_SCREENSHOT"],
           let screen = AppStoreScreenshot(rawValue: env) {
            return screen
        }

        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-AppStoreScreenshot"),
              index + 1 < args.count else { return nil }
        return AppStoreScreenshot(rawValue: args[index + 1])
    }

    static var isCaptureMode: Bool { current != nil }
}

/// スクリーンショット撮影時のルートビュー。
struct AppStoreScreenshotHostView: View {
    let screen: AppStoreScreenshot

    var body: some View {
        Group {
            switch screen {
            case .paywall:
                PaywallView()
            default:
                AppStoreTabScreenshotView(initialTab: screen)
            }
        }
        .fontDesign(.rounded)
        .tint(GenkiPalette.primary)
        .preferredColorScheme(.light)
    }
}

/// 指定タブを選択した MainTabView 相当（トライアルバナー非表示）。
private struct AppStoreTabScreenshotView: View {
    let initialTab: AppStoreScreenshot

    @State private var selectedTab: AppStoreScreenshot

    init(initialTab: AppStoreScreenshot) {
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(String(localized: "tab_home"), systemImage: "house") }
                .tag(AppStoreScreenshot.home)

            RemindersView()
                .tabItem { Label(String(localized: "tab_reminders"), systemImage: "checklist") }
                .tag(AppStoreScreenshot.reminders)

            CheckInView()
                .tabItem { Label(String(localized: "tab_check_in"), systemImage: "sun.max") }
                .tag(AppStoreScreenshot.checkIn)

            FamilyView()
                .tabItem { Label(String(localized: "tab_family"), systemImage: "person.2") }
                .tag(AppStoreScreenshot.family)
        }
        .onAppear { selectedTab = initialTab }
    }
}
