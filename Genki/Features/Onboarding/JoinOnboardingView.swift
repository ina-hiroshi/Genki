import SwiftUI
import SwiftData

/// 共有リンクから参加した人向けのオンボーディング（名前・色のみ）。
struct JoinOnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var myName = ""
    @State private var colorIndex = 0
    @State private var joinError: String?

    private var familyName: String {
        ShareAcceptanceStore.pendingFamilyName ?? String(localized: "family")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(GenkiPalette.primary)
                        Text(String(format: String(localized: "join_family_format"), familyName))
                            .font(GenkiFont.title())
                            .foregroundStyle(GenkiPalette.text)
                            .multilineTextAlignment(.center)
                        Text(String(localized: "join_setup_detail"))
                            .font(GenkiFont.callout())
                            .foregroundStyle(GenkiPalette.muted)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        field(title: String(localized: "field_your_name")) {
                            TextField(String(localized: "name_placeholder_father"), text: $myName)
                                .textFieldStyle(.genki)
                                .accessibilityIdentifier("genki-join-name-field")
                        }
                        field(title: String(localized: "field_your_color")) {
                            colorPicker
                        }
                    }
                    .genkiCard()

                    if let joinError {
                        Text(joinError)
                            .font(GenkiFont.caption())
                            .foregroundStyle(GenkiPalette.sos)
                            .multilineTextAlignment(.center)
                    }

                    Button(String(localized: "join_button"), action: joinFamily)
                        .buttonStyle(.genkiPrimary)
                        .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("genki-join-submit")
                }
                .padding(20)
            }
            .accessibilityIdentifier("genki-join-onboarding")
            .genkiScreenBackground()
            .navigationTitle(String(localized: "app_display_name"))
        }
    }

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(GenkiFont.headline())
                .foregroundStyle(GenkiPalette.text)
            content()
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(GenkiPalette.memberColors.indices, id: \.self) { index in
                Circle()
                    .fill(GenkiPalette.memberColors[index])
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle().stroke(GenkiPalette.text, lineWidth: colorIndex == index ? 3 : 0)
                    )
                    .onTapGesture { colorIndex = index }
            }
        }
    }

    private func joinFamily() {
        guard let rootRecordName = ShareAcceptanceStore.pendingRootRecordName,
              let zoneOwnerName = ShareAcceptanceStore.pendingZoneOwnerName else {
            joinError = String(localized: "join_error_no_share")
            return
        }
        do {
            try ShareController().completeJoin(
                name: myName.trimmingCharacters(in: .whitespaces),
                colorIndex: colorIndex,
                rootRecordName: rootRecordName,
                familyName: familyName,
                zoneOwnerName: zoneOwnerName,
                in: context
            )
            Task { await CloudKitBootstrap.activateIfNeeded() }
        } catch {
            joinError = GenkiCloudError.friendlyMessage(for: error)
        }
    }
}

#Preview {
    JoinOnboardingView()
        .modelContainer(GenkiModelContainer.makePreview(seeded: false))
}
