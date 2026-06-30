import SwiftUI
import SwiftData

/// リマインド作成フォーム。
struct ReminderEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var families: [FamilyGroup]
    @Query private var members: [Member]

    @State private var title = ""
    @State private var symbolName = "pills"
    @State private var time = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    @State private var selectedWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    @State private var ownerID: UUID?

    private let symbols = ["pills", "figure.walk", "drop", "fork.knife", "bed.double", "heart", "bell", "cup.and.saucer"]

    private var weekdaySymbols: [String] {
        Calendar.current.shortWeekdaySymbols
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "reminder_section_content")) {
                    TextField(String(localized: "reminder_title_placeholder"), text: $title)
                    symbolPicker
                }

                Section(String(localized: "reminder_section_owner")) {
                    Picker(String(localized: "reminder_owner_picker"), selection: $ownerID) {
                        Text(String(localized: "reminder_owner_unset")).tag(UUID?.none)
                        ForEach(members) { member in
                            Text(member.name).tag(UUID?.some(member.id))
                        }
                    }
                }

                Section(String(localized: "reminder_section_time")) {
                    DatePicker(String(localized: "reminder_time_picker"), selection: $time, displayedComponents: .hourAndMinute)
                    weekdayPicker
                }
            }
            .genkiListStyle()
            .navigationTitle(String(localized: "reminder_edit_title"))
            .onAppear {
                if ownerID == nil {
                    ownerID = FamilyActions.currentMember(in: context)?.id
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "save")) { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var symbolPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(symbols, id: \.self) { name in
                    Image(systemName: name)
                        .font(.system(size: 18))
                        .foregroundStyle(symbolName == name ? .white : GenkiPalette.primary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(symbolName == name ? GenkiPalette.primary : GenkiPalette.primary.opacity(0.12))
                        )
                        .onTapGesture { symbolName = name }
                        .accessibilityLabel(name)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
                let selected = selectedWeekdays.contains(weekday)
                let symbol = weekdaySymbols[weekday - 1]
                Text(symbol)
                    .font(GenkiFont.callout())
                    .foregroundStyle(selected ? .white : GenkiPalette.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(selected ? GenkiPalette.primary : GenkiPalette.chipBackground))
                    .onTapGesture {
                        if selected { selectedWeekdays.remove(weekday) } else { selectedWeekdays.insert(weekday) }
                    }
                    .accessibilityLabel(String(format: String(localized: "reminder_weekday_a11y_format"), symbol))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func save() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let owner = members.first { $0.id == ownerID }
        FamilyActions.addReminder(
            title: title.trimmingCharacters(in: .whitespaces),
            symbolName: symbolName,
            hour: comps.hour ?? 8,
            minute: comps.minute ?? 0,
            weekdays: selectedWeekdays.sorted(),
            owner: owner,
            family: families.first,
            in: context
        )
        dismiss()
    }
}

#Preview {
    ReminderEditView()
        .modelContainer(GenkiModelContainer.makePreview())
}
