import SwiftUI

/// Watch のホーム: 手元から「元気だよ」、家族の状態をちらっと確認。
struct WatchHomeView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @State private var sent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button {
                    session.sendCheckIn()
                    sent = true
                } label: {
                    Label(sent ? "送りました" : "元気だよ",
                          systemImage: sent ? "checkmark.circle.fill" : "sun.max.fill")
                        .frame(maxWidth: .infinity)
                }
                .tint(sent ? GenkiPalette.done : GenkiPalette.primary)

                Text("家族の今日")
                    .font(.system(.caption, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(GenkiPalette.muted)

                ForEach(session.snapshot.members) { member in
                    HStack {
                        Circle()
                            .fill(GenkiPalette.memberColor(for: member.colorIndex))
                            .frame(width: 10, height: 10)
                        Text(member.name)
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        Image(systemName: member.checkedInToday ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(member.checkedInToday ? GenkiPalette.done : GenkiPalette.muted)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Genki")
    }
}
