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
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("例: おくすり", text: $title)
                    symbolPicker
                }

                Section("担当") {
                    Picker("担当者", selection: $ownerID) {
                        Text("未設定").tag(UUID?.none)
                        ForEach(members) { member in
                            Text(member.name).tag(UUID?.some(member.id))
                        }
                    }
                }

                Section("時間") {
                    DatePicker("時刻", selection: $time, displayedComponents: .hourAndMinute)
                    weekdayPicker
                }
            }
            .genkiListStyle()
            .navigationTitle("リマインド")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
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
                Text(weekdaySymbols[weekday - 1])
                    .font(GenkiFont.callout())
                    .foregroundStyle(selected ? .white : GenkiPalette.text)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(selected ? GenkiPalette.primary : GenkiPalette.chipBackground))
                    .onTapGesture {
                        if selected { selectedWeekdays.remove(weekday) } else { selectedWeekdays.insert(weekday) }
                    }
                    .accessibilityLabel("\(weekdaySymbols[weekday - 1])曜日")
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
