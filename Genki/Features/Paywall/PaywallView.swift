import SwiftUI
import SwiftData
import StoreKit

/// フル版の購入・復元画面。
struct PaywallView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var purchaseManager = PurchaseManager.shared
    @State private var entitlements = EntitlementStore.shared
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showTransferHelp = false
    @State private var statusMessage: String?

    @Query private var families: [FamilyGroup]

    private var family: FamilyGroup? { families.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    purchaseSection
                    footerLinks
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle(String(localized: "paywall_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
            .sheet(isPresented: $showTransferHelp) {
                LicenseTransferHelpView()
            }
            .task {
                await purchaseManager.loadProduct()
                await entitlements.refresh(in: context)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 52))
                .foregroundStyle(GenkiPalette.primary)
            Text(String(localized: "paywall_headline"))
                .font(GenkiFont.title())
                .foregroundStyle(GenkiPalette.text)
                .multilineTextAlignment(.center)
            Text(participantOrOwnerSubtitle)
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var participantOrOwnerSubtitle: String {
        if entitlements.isFamilyOwner {
            if let days = entitlements.trialDaysRemaining {
                return String(format: String(localized: "paywall_trial_remaining_format"), days)
            }
            return String(localized: "paywall_owner_subtitle")
        }
        return String(format: String(localized: "paywall_participant_subtitle_format"),
                      entitlements.premiumOwnerName ?? String(localized: "family"))
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            paywallRow("person.2.fill", String(localized: "paywall_feature_family"))
            paywallRow("bell.fill", String(localized: "paywall_feature_notify"))
            paywallRow("applewatch", String(localized: "paywall_feature_watch"))
            paywallRow("square.grid.2x2.fill", String(localized: "paywall_feature_widget"))
            paywallRow("checklist", String(localized: "paywall_feature_reminders"))
        }
        .genkiCard()
    }

    private func paywallRow(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(GenkiFont.body())
            .foregroundStyle(GenkiPalette.text)
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if entitlements.hasFullAccess {
            Label(String(localized: "paywall_already_unlocked"), systemImage: "checkmark.seal.fill")
                .font(GenkiFont.headline())
                .foregroundStyle(GenkiPalette.done)
        } else if entitlements.isFamilyOwner {
            VStack(spacing: 12) {
                if let product = purchaseManager.product {
                    Button {
                        Task { await buy() }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(String(format: String(localized: "paywall_buy_format"), product.displayPrice))
                        }
                    }
                    .buttonStyle(.genkiPrimary)
                    .disabled(isPurchasing || isRestoring)
                } else {
                    ProgressView()
                    Text(String(localized: "paywall_loading_price"))
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                }

                Button(String(localized: "paywall_restore")) {
                    Task { await restore() }
                }
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.primary)
                .disabled(isPurchasing || isRestoring)
            }
        }

        if let statusMessage {
            Text(statusMessage)
                .font(GenkiFont.caption())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
        }

        if let error = purchaseManager.lastErrorMessage {
            Text(error)
                .font(GenkiFont.caption())
                .foregroundStyle(GenkiPalette.sos)
                .multilineTextAlignment(.center)
        }
    }

    private var footerLinks: some View {
        VStack(spacing: 8) {
            Button(String(localized: "paywall_transfer_help")) {
                showTransferHelp = true
            }
            .font(GenkiFont.caption())
            .foregroundStyle(GenkiPalette.muted)
            Text(String(localized: "paywall_one_purchase_note"))
                .font(GenkiFont.caption())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
        }
    }

    private func buy() async {
        isPurchasing = true
        defer { isPurchasing = false }
        let success = await purchaseManager.purchase()
        if success {
            do {
                try await entitlements.applyPurchase(to: family, in: context)
                statusMessage = String(localized: "paywall_purchase_success")
                dismiss()
            } catch {
                statusMessage = GenkiCloudError.friendlyMessage(for: error)
            }
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        let success = await purchaseManager.restorePurchases()
        if success {
            do {
                try await entitlements.applyPurchase(to: family, in: context)
                statusMessage = String(localized: "paywall_restore_success")
                dismiss()
            } catch {
                statusMessage = GenkiCloudError.friendlyMessage(for: error)
            }
        }
    }
}

#Preview {
    PaywallView()
        .modelContainer(GenkiModelContainer.makePreview())
}
