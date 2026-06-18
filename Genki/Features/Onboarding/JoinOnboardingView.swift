import SwiftUI
import SwiftData

/// 共有リンクから参加した人向けのオンボーディング（名前・色のみ）。
struct JoinOnboardingView: View {
    @Environment(\.modelContext) private var context

    @State private var myName = ""
    @State private var colorIndex = 0
    @State private var joinError: String?

    private var familyName: String {
        ShareAcceptanceStore.pendingFamilyName ?? "家族"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(GenkiPalette.primary)
                        Text("「\(familyName)」に参加")
                            .font(GenkiFont.title())
                            .foregroundStyle(GenkiPalette.text)
                            .multilineTextAlignment(.center)
                        Text("あなたの名前と色を設定してください。")
                            .font(GenkiFont.callout())
                            .foregroundStyle(GenkiPalette.muted)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        field(title: "あなたの名前") {
                            TextField("例: お父さん / たろう", text: $myName)
                                .textFieldStyle(.genki)
                        }
                        field(title: "あなたの色") {
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

                    Button("参加する", action: joinFamily)
                        .buttonStyle(.genkiPrimary)
                        .disabled(myName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle("Genki")
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
            joinError = "共有情報が見つかりません。招待リンクをもう一度開いてください。"
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
