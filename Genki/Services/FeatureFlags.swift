import Foundation

/// 機能フラグ。CloudKit は entitlements が正しく埋め込まれた署名ビルドでのみ有効化する。
enum FeatureFlags {
    /// App Group の entitlement が埋め込まれているか（署名ビルドの目安）。
    private static var hasAppGroupEntitlement: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: GenkiConstants.appGroupID) != nil
    }

    static var cloudKitEnabled: Bool {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["GENKI_ENABLE_CLOUDKIT"] == "1"
            && hasAppGroupEntitlement
        #else
        return hasAppGroupEntitlement
        #endif
    }
}
