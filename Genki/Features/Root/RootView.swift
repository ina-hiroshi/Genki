import SwiftUI
import SwiftData

/// 起動時のルート。家族グループが未作成ならオンボーディング、あればメインタブ。
struct RootView: View {
    @Query private var families: [FamilyGroup]

    var body: some View {
        Group {
            if ShareAcceptanceStore.hasPendingJoin {
                JoinOnboardingView()
            } else if families.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .tint(GenkiPalette.primary)
    }
}

#Preview {
    RootView()
        .modelContainer(GenkiModelContainer.makePreview())
}
