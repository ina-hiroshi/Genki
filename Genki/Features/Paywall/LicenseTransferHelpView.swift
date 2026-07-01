import SwiftUI

/// 購入の引き継ぎと家族データの違いを説明するヘルプ。
struct LicenseTransferHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(String(localized: "license_help_intro"))
                        .font(GenkiFont.callout())
                        .foregroundStyle(GenkiPalette.muted)

                    helpBlock(
                        title: String(localized: "license_help_same_apple_title"),
                        body: String(localized: "license_help_same_apple_body")
                    )
                    helpBlock(
                        title: String(localized: "license_help_participant_title"),
                        body: String(localized: "license_help_participant_body")
                    )
                    helpBlock(
                        title: String(localized: "license_help_new_apple_title"),
                        body: String(localized: "license_help_new_apple_body")
                    )
                    helpBlock(
                        title: String(localized: "license_help_reinstall_title"),
                        body: String(localized: "license_help_reinstall_body")
                    )
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle(String(localized: "paywall_transfer_help"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
            }
        }
    }

    private func helpBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(GenkiFont.headline())
                .foregroundStyle(GenkiPalette.text)
            Text(body)
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .genkiCard()
    }
}

#Preview {
    LicenseTransferHelpView()
}
