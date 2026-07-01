import Foundation

/// トライアル / フル版に応じた機能ゲート。SOS は常時利用可（ここでは扱わない）。
enum FeatureGate {
    static let freeReminderLimit = 3
    static let freeMemberLimit = 2

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: GenkiConstants.appGroupID)
    }

    /// トライアル・ローカル購入・家族 premium を統合判定（非 MainActor）。
    static func hasFullAccess(family: FamilyGroup?) -> Bool {
        if TrialManager.isInTrialPeriod { return true }
        if isLocalPurchaseCached { return true }
        if family?.premiumUnlockedAt != nil { return true }
        return false
    }

    static func canSyncToFamily(family: FamilyGroup?) -> Bool {
        hasFullAccess(family: family)
    }

    static func canInvite(family: FamilyGroup?) -> Bool {
        hasFullAccess(family: family)
    }

    static func canUseWidgetAndWatch() -> Bool {
        cachedHasFullAccess()
    }

    static func canAddReminder(currentCount: Int, family: FamilyGroup?) -> Bool {
        if hasFullAccess(family: family) { return true }
        return currentCount < freeReminderLimit
    }

    static func canAddMember(currentCount: Int, family: FamilyGroup?) -> Bool {
        if hasFullAccess(family: family) { return true }
        return currentCount < freeMemberLimit
    }

    static func reminderLimit(for family: FamilyGroup?) -> Int? {
        hasFullAccess(family: family) ? nil : freeReminderLimit
    }

    static func memberLimit(for family: FamilyGroup?) -> Int? {
        hasFullAccess(family: family) ? nil : freeMemberLimit
    }

    static var isLocalPurchaseCached: Bool {
        defaults?.bool(forKey: GenkiConstants.localPurchaseCacheKey) ?? false
    }

    static func cacheLocalPurchase(_ purchased: Bool) {
        defaults?.set(purchased, forKey: GenkiConstants.localPurchaseCacheKey)
    }

    static func cacheFullAccess(_ access: Bool) {
        defaults?.set(access, forKey: GenkiConstants.entitlementCacheKey)
    }

    /// App Group キャッシュ（ウィジェット / Watch 用）。
    static func cachedHasFullAccess() -> Bool {
        defaults?.bool(forKey: GenkiConstants.entitlementCacheKey) ?? false
    }
}
