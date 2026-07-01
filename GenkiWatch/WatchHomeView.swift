import SwiftUI

/// Watch のホーム: 手元から体調チェックイン・リマインド完了、家族の状態を確認。
struct WatchHomeView: View {
    @EnvironmentObject private var session: WatchSessionManager
    @State private var sentCheckIn = false
    @State private var completedReminderIDs: Set<String> = []

    var body: some View {
        ScrollView {
            if session.snapshot.hasFullAccess {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .navigationTitle(String(localized: "app_display_name"))
        .onAppear { session.refreshFromSharedStore() }
    }

    private var unlockedContent: some View {
        VStack(spacing: 10) {
            checkInSection
            myRemindersSection
            familySection
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var checkInSection: some View {
        if sentCheckIn {
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
                    session.sendCheckIn(level: level)
                    sentCheckIn = true
                } label: {
                    Label(level.shortLabel, systemImage: level.symbolName)
                        .frame(maxWidth: .infinity)
                }
                .tint(level.tint)
            }
        }
    }

    @ViewBuilder
    private var myRemindersSection: some View {
        let pending = session.snapshot.myReminders.filter { !completedReminderIDs.contains($0.id) }
        if !pending.isEmpty {
            Text(String(localized: "watch_my_reminders"))
                .font(.system(.caption, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(GenkiPalette.muted)
                .padding(.top, 4)

            ForEach(pending) { reminder in
                Button {
                    session.completeReminder(id: reminder.id)
                    completedReminderIDs.insert(reminder.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title)
                                .font(.system(.body, design: .rounded))
                                .lineLimit(1)
                            Text(reminder.time)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(GenkiPalette.muted)
                        }
                        Spacer()
                        Text(String(localized: "watch_complete_button"))
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                }
                .tint(GenkiPalette.primary)
            }
        }
    }

    private var familySection: some View {
        VStack(spacing: 8) {
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
    }

    private var lockedContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(GenkiPalette.primary)
            Text(String(localized: "watch_locked_title"))
                .font(.system(.caption, design: .rounded).weight(.semibold))
            Text(String(localized: "watch_locked_detail"))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
    }
}
