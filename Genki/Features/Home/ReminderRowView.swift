import SwiftUI
import SwiftData

/// 1件のリマインド行。完了ボタン、完了済み表示、リアクション。
struct ReminderRowView: View {
    @Environment(\.modelContext) private var context
    @Bindable var reminder: Reminder

    @State private var showReactionPicker = false

    private var me: Member? { FamilyActions.currentMember(in: context) }
    private var ownerColorIndex: Int { reminder.owner?.colorIndex ?? 0 }

    private var todaysCompletion: CompletionLog? {
        (reminder.completions ?? []).first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(GenkiFont.headline())
                        .foregroundStyle(GenkiPalette.text)
                    Text(ownerLine).font(GenkiFont.caption()).foregroundStyle(GenkiPalette.muted)
                }
                Spacer()
                trailing
            }

            if let completion = todaysCompletion {
                HStack(spacing: 10) {
                    ReactionRow(reactions: completion.reactions ?? [])
                    Spacer()
                    Button {
                        showReactionPicker.toggle()
                    } label: {
                        Image(systemName: "face.smiling")
                            .foregroundStyle(GenkiPalette.primary)
                    }
                    .accessibilityLabel("リアクションを送る")
                }
                if showReactionPicker {
                    ReactionPicker { kind in
                        if let me {
                            FamilyActions.react(kind, toCompletion: completion, author: me, in: context)
                            NotificationManager.shared.notifyReaction(authorName: me.name, reaction: kind)
                        }
                        showReactionPicker = false
                    }
                }
            }
        }
        .genkiCard()
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(GenkiPalette.memberColor(for: ownerColorIndex))
                .frame(width: 4)
                .padding(.vertical, 14)
        }
    }

    private var icon: some View {
        Image(systemName: reminder.symbolName)
            .font(.system(size: 18))
            .foregroundStyle(GenkiPalette.memberColor(for: ownerColorIndex))
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(GenkiPalette.memberColor(for: ownerColorIndex).opacity(0.15))
            )
    }

    private var ownerLine: String {
        let owner = reminder.owner?.name ?? "家族"
        return "\(owner)・\(reminder.timeText)"
    }

    @ViewBuilder
    private var trailing: some View {
        if todaysCompletion != nil {
            Label("完了", systemImage: "checkmark.circle.fill")
                .font(GenkiFont.callout().weight(.semibold))
                .foregroundStyle(GenkiPalette.done)
        } else {
            Button("完了") {
                complete()
            }
            .buttonStyle(.genkiQuiet)
            .accessibilityHint("\(reminder.title)を完了にして家族に知らせます")
        }
    }

    private func complete() {
        guard let me else { return }
        FamilyActions.complete(reminder: reminder, by: me, in: context)
    }
}
