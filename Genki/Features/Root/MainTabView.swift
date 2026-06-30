import SwiftUI

/// メインのタブ。ホーム / リマインダー / チェックイン / 家族。
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(String(localized: "tab_home"), systemImage: "house") }

            RemindersView()
                .tabItem { Label(String(localized: "tab_reminders"), systemImage: "checklist") }

            CheckInView()
                .tabItem { Label(String(localized: "tab_check_in"), systemImage: "sun.max") }

            FamilyView()
                .tabItem { Label(String(localized: "tab_family"), systemImage: "person.2") }
        }
        .task { await CloudKitBootstrap.activateIfNeeded() }
    }
}

#Preview {
    MainTabView()
        .modelContainer(GenkiModelContainer.makePreview())
}
