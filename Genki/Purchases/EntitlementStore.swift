import Foundation
import SwiftData

/// トライアル・ローカル購入・CloudKit 家族 premium を統合したアクセス判定。
@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    private(set) var hasFullAccess = false
    private(set) var isFamilyOwner = true
    private(set) var premiumOwnerName: String?

    private var defaults: UserDefaults {
        UserDefaults(suiteName: GenkiConstants.appGroupID) ?? .standard
    }

    private init() {}

    func refresh(in context: ModelContext) async {
        let family = FamilyActions.currentFamily(in: context)
        isFamilyOwner = FamilyRole.isOwner(of: family)
        premiumOwnerName = ownerDisplayName(for: family, in: context)

        await PurchaseManager.shared.refreshEntitlements()
        await PremiumSync.refreshPremium(from: family, in: context)

        hasFullAccess = computeFullAccess(family: family)
        cacheEntitlement()
    }

    func hasFullAccess(for family: FamilyGroup?) -> Bool {
        FeatureGate.hasFullAccess(family: family)
    }

    func handleLocalPurchaseConfirmed() async {
        hasFullAccess = true
        cacheEntitlement()
    }

    func applyPurchase(to family: FamilyGroup?, in context: ModelContext) async throws {
        family?.premiumUnlockedAt = .now
        try? context.save()
        if let family {
            try await PremiumSync.writePremiumUnlocked(family: family, in: context)
        }
        hasFullAccess = true
        cacheEntitlement()
        FamilyActions.rebuildSnapshot(in: context)
    }

    var trialDaysRemaining: Int? {
        TrialManager.daysRemaining
    }

    var shouldShowTrialBanner: Bool {
        TrialManager.isInTrialPeriod && !PurchaseManager.shared.hasLocalPurchase
    }

    var shouldShowUpgradePrompt: Bool {
        !hasFullAccess && !TrialManager.isInTrialPeriod
    }

    private func computeFullAccess(family: FamilyGroup?) -> Bool {
        FeatureGate.hasFullAccess(family: family)
    }

    private func cacheEntitlement() {
        FeatureGate.cacheFullAccess(hasFullAccess)
        FeatureGate.cacheLocalPurchase(PurchaseManager.shared.hasLocalPurchase)
    }

    private func ownerDisplayName(for family: FamilyGroup?, in context: ModelContext) -> String? {
        guard let family, !FamilyRole.isOwner(of: family) else { return nil }
        return family.sortedMembers.first(where: { !$0.isMe })?.name
            ?? String(localized: "family")
    }
}

/// 家族 CloudKit ゾーンのオーナー（購入者）かどうか。
enum FamilyRole {
    static func isOwner(of family: FamilyGroup?) -> Bool {
        guard let family else { return true }
        guard let storedOwner = family.cloudKitRootZoneOwnerName else {
            return family.shareRecordName == nil
        }
        return storedOwner == CloudKitManager.shared.zoneID.ownerName
    }
}
