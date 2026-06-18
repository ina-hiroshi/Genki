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
                                    Text("\(reminder.owner?.name ?? "家族")・\(reminder.timeText)\(reminder.isRepeating ? "・繰り返し" : "")")
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
            .navigationTitle("リマインダー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingEditor = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("リマインドを追加")
                }
            }
            .sheet(isPresented: $showingEditor) {
                ReminderEditView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 44))
                .foregroundStyle(GenkiPalette.primary)
            Text("リマインドを追加しよう")
                .font(GenkiFont.title())
                .foregroundStyle(GenkiPalette.text)
            Text("服薬・散歩・水分など、家族で見守りたいことを登録できます。")
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.muted)
                .multilineTextAlignment(.center)
            Button("追加する") { showingEditor = true }
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
