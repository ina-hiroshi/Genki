import Foundation

#if DEBUG
import SwiftData
/// UI テスト / シミュレーター向けの共有フロー支援（DEBUG のみ）。
enum ShareTestSupport {
    private static let shareURLKey = "genki.test.lastShareURL"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: GenkiConstants.appGroupID) ?? .standard
    }

    static let defaultInjectRootRecordName = "00000000-0000-0000-0000-000000000001"
    static let defaultInjectFamilyName = "テスト家族"
    static let defaultInjectZoneOwnerName = "genki-test-zone-owner"

    static func storeLastShareURL(_ url: URL?) {
        if let url {
            defaults.set(url.absoluteString, forKey: shareURLKey)
        } else {
            defaults.removeObject(forKey: shareURLKey)
        }
    }

    static var lastShareURLString: String? {
        defaults.string(forKey: shareURLKey)
    }

    private static var isInjectRequested: Bool {
        ProcessInfo.processInfo.environment["GENKI_INJECT_PENDING_JOIN"] == "1"
            || ProcessInfo.processInfo.arguments.contains("-GENKI_INJECT_PENDING_JOIN")
    }

    /// 注入テスト用にローカルデータを消してから pending join を書き込む。
    @MainActor
    static func prepareInjectedJoinTest(in context: ModelContext) {
        guard isInjectRequested else { return }
        let keepExisting = ProcessInfo.processInfo.environment["GENKI_INJECT_KEEP_EXISTING"] == "1"
        if !keepExisting {
            AccountActions.deleteAllUserData(in: context)
        }
        injectPendingJoinIfRequested()
        PendingJoinState.shared.refreshFromStore()
    }

    /// `GENKI_INJECT_PENDING_JOIN=1` で共有リンク受諾後の参加画面を再現する。
    static func injectPendingJoinIfRequested() {
        guard isInjectRequested else { return }

        let env = ProcessInfo.processInfo.environment
        let rootRecordName = env["GENKI_INJECT_ROOT_RECORD_NAME"] ?? defaultInjectRootRecordName
        let familyName = env["GENKI_INJECT_FAMILY_NAME"] ?? defaultInjectFamilyName
        let zoneOwnerName = env["GENKI_INJECT_ZONE_OWNER_NAME"] ?? defaultInjectZoneOwnerName

        ShareAcceptanceStore.storePendingJoin(
            rootRecordName: rootRecordName,
            familyName: familyName,
            zoneOwnerName: zoneOwnerName
        )
    }
}
#endif
