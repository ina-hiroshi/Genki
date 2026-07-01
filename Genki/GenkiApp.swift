import SwiftUI
import SwiftData
import CloudKit
import UserNotifications

@main
struct GenkiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var bootstrapState = ShareBootstrapState.shared

    let container = GenkiModelContainer.makeShared()

    init() {
        appDelegate.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .fontDesign(.rounded)
                .tint(GenkiPalette.primary)
                .accessibilityIdentifier(bootstrapState.accessibilityID)
                .task { await bootstrap() }
        }
        .modelContainer(container)
    }

    /// 起動時のセットアップ: 通知許可・リモート通知登録・CloudKit購読。
    @MainActor
    private func bootstrap() async {
        #if DEBUG
        seedIfRequested()
        await bootstrapShareIfRequested()
        #endif
        PhoneSessionManager.shared.configure(container: container)
        await PurchaseManager.shared.start()
        await NotificationManager.shared.requestAuthorization()
        await EntitlementStore.shared.refresh(in: container.mainContext)
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

    /// GENKI_BOOTSTRAP_SHARE=1 で Development に cloudkit.share 型を生成（UI 操作不要）。
    @MainActor
    private func bootstrapShareIfRequested() async {
        guard ProcessInfo.processInfo.environment["GENKI_BOOTSTRAP_SHARE"] == "1" else { return }
        guard FeatureFlags.cloudKitEnabled else {
            ShareBootstrapState.shared.markFailure("CloudKit が無効です")
            return
        }

        ShareBootstrapState.shared.markPending()
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<FamilyGroup>())) ?? 0
        if count == 0 {
            SampleData.seed(into: context)
            if let me = FamilyActions.currentMember(in: context) {
                CurrentUser.myMemberID = me.id
                CurrentUser.myName = me.name
            }
            CurrentUser.isOnboarded = true
        }

        guard let family = try? context.fetch(FetchDescriptor<FamilyGroup>()).first else {
            ShareBootstrapState.shared.markFailure("家族グループがありません")
            return
        }

        do {
            _ = try await ShareController().prepareShare(for: family)
            try? context.save()
            ShareBootstrapState.shared.markSuccess()
        } catch {
            ShareBootstrapState.shared.markFailure(GenkiCloudError.technicalDetail(for: error))
        }
    }
    #endif
}

/// プッシュ通知と CloudKit 共有受諾を扱う AppDelegate。
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var modelContainer: ModelContainer?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - リモート通知

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Task { @MainActor in
            if let context = modelContainer?.mainContext {
                await CloudKitEventWriter.handleRemoteChange(in: context)
                await EntitlementStore.shared.refresh(in: context)
            }
            completionHandler(.newData)
        }
    }

    // MARK: - CloudKit 共有の受諾（招待リンクを開いたとき）

    func application(_ application: UIApplication,
                     userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            do {
                try await ShareController().accept(cloudKitShareMetadata)
            } catch {
                // 受諾失敗は次回起動時に再試行できるよう、ログのみ
                NSLog("Genki share accept error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - フォアグラウンド表示

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let level = GenkiLevel.fromNotificationActionID(response.actionIdentifier) else { return }
        await MainActor.run {
            CheckInNotificationHandler.perform(level: level, fromAlarm: true)
        }
    }
}
