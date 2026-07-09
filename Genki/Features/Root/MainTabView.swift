import SwiftUI
import SwiftData

/// メインのタブ。ホーム / リマインダー / チェックイン / 家族。
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var entitlements = EntitlementStore.shared
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            TrialBannerView(entitlements: entitlements) {
                showPaywall = true
            }

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
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            await CloudKitBootstrap.activateIfNeeded()
            await entitlements.refresh(in: context)
            await refreshSharedFamilyData()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await refreshSharedFamilyData() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .genkiPurchaseDidChange)) { _ in
            Task { await entitlements.refresh(in: context) }
        }
    }

    @MainActor
    private func refreshSharedFamilyData() async {
        guard let family = FamilyActions.currentFamily(in: context),
              family.shareRecordName != nil else { return }
        await FamilyDataSync.pullFamilyData(for: family, in: context)
    }
}

#Preview {
    MainTabView()
        .modelContainer(GenkiModelContainer.makePreview())
}
