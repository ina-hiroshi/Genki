import SwiftUI

/// Watch のホーム: 手元から体調チェックイン、家族の状態をちらっと確認。
struct WatchHomeView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @State private var selectedLevel: GenkiLevel = .okay
    @State private var sent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if sent {
                    Label(String(localized: "watch_sent"), systemImage: "checkmark.circle.fill")
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .tint(GenkiPalette.done)
                } else {
                    Text(String(localized: "watch_check_in_prompt"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(GenkiPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(GenkiLevel.allCases.reversed()) { level in
                        Button {
                            selectedLevel = level
                            session.sendCheckIn(level: level)
                            sent = true
                        } label: {
                            Label(level.shortLabel, systemImage: level.symbolName)
                                .frame(maxWidth: .infinity)
                        }
                        .tint(level.tint)
                    }
                }

                Text(String(localized: "watch_family_today"))
                    .font(.system(.caption, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(GenkiPalette.muted)
                    .padding(.top, 4)

                ForEach(session.snapshot.members) { member in
                    HStack {
                        Circle()
                            .fill(GenkiPalette.memberColor(for: member.colorIndex))
                            .frame(width: 10, height: 10)
                        Text(member.name)
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        if let level = member.level {
                            Image(systemName: level.symbolName)
                                .foregroundStyle(level.tint)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(GenkiPalette.muted)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Genki")
    }
}
