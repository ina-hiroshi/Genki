import UIKit

/// CloudKit / プッシュの初期化。家族グループ作成後など、起動直後ではなく必要なタイミングで呼ぶ。
enum CloudKitBootstrap {
    @MainActor
    static func activateIfNeeded() async {
        guard FeatureFlags.cloudKitEnabled else { return }
        UIApplication.shared.registerForRemoteNotifications()
        await SubscriptionManager.shared.registerSubscriptions()
    }
}
