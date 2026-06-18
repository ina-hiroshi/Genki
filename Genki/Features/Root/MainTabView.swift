import SwiftUI

/// メインのタブ。ホーム / リマインダー / チェックイン / 家族。
struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }

            RemindersView()
                .tabItem { Label("リマインダー", systemImage: "checklist") }

            CheckInView()
                .tabItem { Label("チェックイン", systemImage: "sun.max") }

            FamilyView()
                .tabItem { Label("家族", systemImage: "person.2") }
        }
        .task { await CloudKitBootstrap.activateIfNeeded() }
    }
}

#Preview {
    MainTabView()
        .modelContainer(GenkiModelContainer.makePreview())
}
