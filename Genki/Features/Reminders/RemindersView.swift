import SwiftUI
import SwiftData

/// すべてのリマインドの一覧と追加。
struct RemindersView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Reminder.hour) private var reminders: [Reminder]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if reminders.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(reminders) { reminder in
                            HStack(spacing: 12) {
                                Image(systemName: reminder.symbolName)
                                    .foregroundStyle(GenkiPalette.memberColor(for: reminder.owner?.colorIndex ?? 0))
                                    .frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text(reminder.title)
                                        .font(GenkiFont.body())
                                        .foregroundStyle(GenkiPalette.text)
                                    Text(reminderSubtitle(for: reminder))
                                        .font(GenkiFont.caption())
                                        .foregroundStyle(GenkiPalette.muted)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .genkiListStyle()
                }
            }
            .genkiScreenBackground()
            .navigationTitle(String(localized: "tab_reminders"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "reminders_add_a11y"))
                }
            }
            .sheet(isPresented: $showingEditor) {
                ReminderEditView()
            }
        }
    }

    private func reminderSubtitle(for reminder: Reminder) -> String {
        let owner = reminder.owner?.name ?? String(localized: "family")
        var line = String(format: String(localized: "reminder_row_format"), owner, reminder.timeText)
        if reminder.isRepeating {
            line += String(localized: "reminder_repeating_suffix")
        }
        return line
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
                .foregroundStyle(GenkiPalette.primary)
            Text(String(localized: "reminders_empty_title"))
                .font(GenkiFont.title())
                .foregroundStyle(GenkiPalette.text)
            Text(String(localized: "reminders_empty_detail"))
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
            Button(String(localized: "reminders_add_button")) { showingEditor = true }
                .buttonStyle(.genkiPrimary)
                .frame(maxWidth: 220)
        }
        .padding(32)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            FamilyActions.delete(reminder: reminders[index], in: context)
        }
    }
}

#Preview {
    RemindersView()
        .modelContainer(GenkiModelContainer.makePreview())
}
