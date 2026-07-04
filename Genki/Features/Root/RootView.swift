import SwiftUI
import SwiftData

/// 起動時のルート。家族グループが未作成ならオンボーディング、あればメインタブ。
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query private var families: [FamilyGroup]
    @State private var pendingJoinState = PendingJoinState.shared

    var body: some View {
        Group {
            if pendingJoinState.hasPendingJoin {
                JoinOnboardingView()
            } else if families.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .tint(GenkiPalette.primary)
        .onAppear {
            pendingJoinState.refreshFromStore()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                pendingJoinState.refreshFromStore()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(GenkiModelContainer.makePreview())
}
