import SwiftUI

/// トライアル / 期限切れ / 参加者向けの上部バナー。
struct TrialBannerView: View {
    let entitlements: EntitlementStore
    let onShowPaywall: () -> Void

    var body: some View {
        Group {
            if entitlements.shouldShowTrialBanner, let days = entitlements.trialDaysRemaining {
                trialBanner(days: days)
            } else if entitlements.shouldShowUpgradePrompt && entitlements.isFamilyOwner {
                expiredOwnerBanner
            } else if entitlements.shouldShowUpgradePrompt && !entitlements.isFamilyOwner {
                participantBanner
            }
        }
    }

    private func trialBanner(days: Int) -> some View {
        Button(action: onShowPaywall) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text(String(format: String(localized: "trial_banner_format"), days))
                    .font(GenkiFont.caption())
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .foregroundStyle(GenkiPalette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GenkiPalette.primary.opacity(0.15))
        }
        .buttonStyle(.plain)
    }

    private var expiredOwnerBanner: some View {
        Button(action: onShowPaywall) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    bannerText(String(localized: "trial_expired_banner"))
                    Spacer(minLength: 8)
                    Text(String(localized: "paywall_unlock_button"))
                        .font(GenkiFont.caption().weight(.semibold))
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        bannerText(String(localized: "trial_expired_banner"))
                    } icon: {
                        Image(systemName: "lock.fill")
                    }
                    Text(String(localized: "paywall_unlock_button"))
                        .font(GenkiFont.caption().weight(.semibold))
                }
            }
            .foregroundStyle(GenkiPalette.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GenkiPalette.chipBackground)
        }
        .buttonStyle(.plain)
    }

    private var participantBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.2.fill")
            Text(String(format: String(localized: "paywall_participant_banner_format"),
                        entitlements.premiumOwnerName ?? String(localized: "family")))
                .font(GenkiFont.caption())
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(GenkiPalette.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GenkiPalette.chipBackground)
    }

    private func bannerText(_ text: String) -> some View {
        Text(text)
            .font(GenkiFont.caption())
            .lineLimit(2)
            .minimumScaleFactor(0.9)
            .multilineTextAlignment(.leading)
    }
}
