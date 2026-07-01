import SwiftUI
import SwiftData

/// メインのタブ。ホーム / リマインダー / チェックイン / 家族。
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @State private var entitlements = EntitlementStore.shared
    @State private var showPaywall = false

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
        .safeAreaInset(edge: .top, spacing: 0) {
            trialBanner
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            await CloudKitBootstrap.activateIfNeeded()
            await entitlements.refresh(in: context)
        }
        .onReceive(NotificationCenter.default.publisher(for: .genkiPurchaseDidChange)) { _ in
            Task { await entitlements.refresh(in: context) }
        }
    }

    @ViewBuilder
    private var trialBanner: some View {
        if entitlements.shouldShowTrialBanner, let days = entitlements.trialDaysRemaining {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text(String(format: String(localized: "trial_banner_format"), days))
                        .font(GenkiFont.caption())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(GenkiPalette.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GenkiPalette.primary.opacity(0.15))
            }
            .buttonStyle(.plain)
        } else if entitlements.shouldShowUpgradePrompt && entitlements.isFamilyOwner {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text(String(localized: "trial_expired_banner"))
                        .font(GenkiFont.caption())
                    Spacer()
                    Text(String(localized: "paywall_unlock_button"))
                        .font(GenkiFont.caption().weight(.semibold))
                }
                .foregroundStyle(GenkiPalette.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GenkiPalette.chipBackground)
            }
            .buttonStyle(.plain)
        } else if entitlements.shouldShowUpgradePrompt && !entitlements.isFamilyOwner {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                Text(String(format: String(localized: "paywall_participant_banner_format"),
                            entitlements.premiumOwnerName ?? String(localized: "family")))
                    .font(GenkiFont.caption())
            }
            .foregroundStyle(GenkiPalette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(GenkiPalette.chipBackground)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(GenkiModelContainer.makePreview())
}
