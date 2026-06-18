import SwiftUI
import SwiftData

/// 緊急SOS。家族の連絡チェーンに順に通知を送る。
struct SOSView: View {
    @Environment(\.modelContext) private var context
    @Query private var families: [FamilyGroup]
    @State private var isSending = false
    @State private var sent = false

    private var family: FamilyGroup? { families.first }
    private var me: Member? { FamilyActions.currentMember(in: context) }

    /// 連絡チェーン: 自分以外の家族を順に。
    private var chain: [String] {
        (family?.sortedMembers ?? []).filter { !$0.isMe }.map { $0.name }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "sos.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(GenkiPalette.sos)

            Text("緊急SOS")
                .font(GenkiFont.largeTitle())
                .foregroundStyle(GenkiPalette.text)

            Text("家族に順番に知らせます。\n応答があるまで連絡を続けます。")
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)

            if sent {
                Label("家族に知らせました", systemImage: "checkmark.circle.fill")
                    .font(GenkiFont.headline())
                    .foregroundStyle(GenkiPalette.done)
                Button("SOSを止める") {
                    EscalationManager.shared.cancel()
                    sent = false
                }
                .buttonStyle(.genkiQuiet)
            } else {
                Button {
                    sendSOS()
                } label: {
                    Text("SOSを送る")
                }
                .buttonStyle(GenkiPrimaryButtonStyle(tint: GenkiPalette.sos))
                .padding(.horizontal, 24)
            }
            Spacer()

            Text("おやすみモードを突破する強い通知（Critical Alerts）は、Appleの承認後に有効になります。")
                .font(GenkiFont.caption())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(20)
        .genkiScreenBackground()
        .navigationTitle("SOS")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sendSOS() {
        let name = me?.name ?? "家族"
        EscalationManager.shared.start(fromMemberName: name, chain: chain.isEmpty ? [name] : chain)
        sent = true
    }
}

#Preview {
    NavigationStack { SOSView() }
        .modelContainer(GenkiModelContainer.makePreview())
}
