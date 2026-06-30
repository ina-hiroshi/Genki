import SwiftUI
import SwiftData

/// チェックインタブ: 自分の「元気だよ」と、今日の家族のチェックイン一覧。
struct CheckInView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]

    private var me: Member? { FamilyActions.currentMember(in: context) }

    private var todaysCheckIns: [CheckIn] {
        checkIns.filter { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CheckInHeroButton()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "check_in_today_family"))
                            .font(GenkiFont.headline())
                            .foregroundStyle(GenkiPalette.text)
                        if todaysCheckIns.isEmpty {
                            Text(String(localized: "check_in_none_yet"))
                                .font(GenkiFont.callout())
                                .foregroundStyle(GenkiPalette.muted)
                                .genkiCard()
                        } else {
                            ForEach(todaysCheckIns) { checkIn in
                                CheckInRow(checkIn: checkIn, me: me)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle(String(localized: "tab_check_in"))
        }
    }
}

private struct CheckInRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var checkIn: CheckIn
    var me: Member?
    @State private var showPicker = false

    private var memberName: String {
        checkIn.member?.name ?? String(localized: "family")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MemberAvatar(name: memberName,
                             colorIndex: checkIn.member?.colorIndex ?? 0,
                             checkedIn: true,
                             genkiLevel: checkIn.genkiLevel,
                             size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(
                        format: String(localized: "check_in_member_sent_format"),
                        memberName,
                        checkIn.genkiLevel.shortLabel
                    ))
                        .font(GenkiFont.body())
                        .foregroundStyle(GenkiPalette.text)
                    Text(checkIn.date, style: .time)
                        .font(GenkiFont.caption())
                        .foregroundStyle(GenkiPalette.muted)
                    if let note = checkIn.note, !note.isEmpty {
                        Text(note)
                            .font(GenkiFont.callout())
                            .foregroundStyle(GenkiPalette.muted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Button { showPicker.toggle() } label: {
                    Image(systemName: "face.smiling").foregroundStyle(GenkiPalette.primary)
                }
                .accessibilityLabel(String(localized: "check_in_reaction_a11y"))
            }
            ReactionRow(reactions: checkIn.reactions ?? [])
            if showPicker {
                ReactionPicker { kind in
                    if let me {
                        FamilyActions.react(kind, toCheckIn: checkIn, author: me, in: context)
                        NotificationManager.shared.notifyReaction(authorName: me.name, reaction: kind)
                    }
                    showPicker = false
                }
            }
        }
        .genkiCard()
    }
}

#Preview {
    CheckInView()
        .modelContainer(GenkiModelContainer.makePreview())
}
