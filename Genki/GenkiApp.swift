import SwiftUI
import SwiftData
import CloudKit
import UserNotifications

@main
struct GenkiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let container = GenkiModelContainer.makeShared()

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.rounded)
                .tint(GenkiPalette.primary)
                .task { await bootstrap() }
        }
        .modelContainer(container)
    }

    /// 起動時のセットアップ: 通知許可・リモート通知登録・CloudKit購読。
    @MainActor
    private func bootstrap() async {
        #if DEBUG
        seedIfRequested()
        #endif
        PhoneSessionManager.shared.configure(container: container)
        await NotificationManager.shared.requestAuthorization()
        // CloudKit 購読は家族グループ作成後に登録（起動直後の CKContainer 初期化クラッシュを避ける）
        FamilyActions.rebuildSnapshot(in: container.mainContext)
    }

    #if DEBUG
    /// 開発時に GENKI_SEED=1 で起動するとサンプル家族を投入する（スクリーンショット/検証用）。
    @MainActor
    private func seedIfRequested() {
        guard ProcessInfo.processInfo.environment["GENKI_SEED"] == "1" else { return }
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<FamilyGroup>())) ?? 0
        guard count == 0 else { return }
        SampleData.seed(into: context)
        if let me = FamilyActions.currentMember(in: context) {
            CurrentUser.myMemberID = me.id
            CurrentUser.myName = me.name
        }
        CurrentUser.isOnboarded = true
    }
    #endif
}

/// プッシュ通知と CloudKit 共有受諾を扱う AppDelegate。
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - リモート通知

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // CKDatabaseSubscription からのサイレントプッシュ。
        // 実機では差分フェッチ→ローカルへ反映→必要なら可視通知に変換する。
        completionHandler(.newData)
    }

    // MARK: - CloudKit 共有の受諾（招待リンクを開いたとき）

    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task {
            try? await ShareController().accept(cloudKitShareMetadata)
        }
    }

    // MARK: - フォアグラウンド表示

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
