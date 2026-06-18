import SwiftUI
import SwiftData

/// ホーム上部の主役: 毎日の「元気だよ」チェックイン。
struct CheckInHeroButton: View {
    @Environment(\.modelContext) private var context
    @State private var justChecked = false

    private var me: Member? { FamilyActions.currentMember(in: context) }

    var body: some View {
        let done = me?.hasCheckedIn() ?? false

        Button {
            sendCheckIn()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "sun.max.fill")
                    .font(.system(size: 24))
                Text(done ? "今日も元気だよ" : "元気だよ")
                    .font(GenkiFont.title())
            }
        }
        .buttonStyle(GenkiPrimaryButtonStyle(tint: done ? GenkiPalette.done : GenkiPalette.primary))
        .disabled(done)
        .scaleEffect(justChecked ? 1.03 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: justChecked)
        .accessibilityHint(done ? "今日はチェックイン済みです" : "タップして家族に元気だよを送ります")
    }

    private func sendCheckIn() {
        guard let me, !me.hasCheckedIn() else { return }
        FamilyActions.checkIn(member: me, in: context)
        NotificationManager.shared.notifyCheckIn(memberName: me.name)
        justChecked = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { justChecked = false }
    }
}
