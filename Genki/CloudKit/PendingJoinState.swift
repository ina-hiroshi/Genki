import Foundation
import Observation

/// 共有リンク受諾後の保留参加状態。RootView が即座に JoinOnboardingView へ遷移するために使う。
@MainActor
@Observable
final class PendingJoinState {
    static let shared = PendingJoinState()

    private var refreshToken = 0

    var hasPendingJoin: Bool {
        _ = refreshToken
        return ShareAcceptanceStore.hasPendingJoin
    }

    func refreshFromStore() {
        refreshToken += 1
    }
}
