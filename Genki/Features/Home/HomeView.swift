import SwiftUI
import SwiftData

/// ホーム: 挨拶 → 「元気だよ」→ 家族の今日 → 今日のリマインド。
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var families: [FamilyGroup]

    private var family: FamilyGroup? { families.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greeting
                    CheckInHeroButton()
                    familyToday
                    todayReminders
                }
                .padding(20)
            }
            .genkiScreenBackground()
            .navigationTitle("Genki")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SOSView()
                    } label: {
                        Image(systemName: "sos")
                            .foregroundStyle(GenkiPalette.sos)
                    }
                    .accessibilityLabel("緊急SOS")
                }
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(GenkiFont.largeTitle())
                .foregroundStyle(GenkiPalette.text)
            Text(family?.name ?? "")
                .font(GenkiFont.callout())
                .foregroundStyle(GenkiPalette.muted)
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let part = hour < 11 ? "おはよう" : (hour < 18 ? "こんにちは" : "こんばんは")
        let name = CurrentUser.myName
        return name.isEmpty ? "\(part)！" : "\(part)、\(name)"
    }

    @ViewBuilder
    private var familyToday: some View {
        if let family, !family.sortedMembers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("家族の今日").font(GenkiFont.headline()).foregroundStyle(GenkiPalette.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(family.sortedMembers) { member in
                            VStack(spacing: 6) {
                                MemberAvatar(name: member.name,
                                             colorIndex: member.colorIndex,
                                             checkedIn: member.hasCheckedIn())
                                Text(member.name)
                                    .font(GenkiFont.caption())
                                    .foregroundStyle(GenkiPalette.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var todayReminders: some View {
        let reminders = (family?.sortedReminders ?? []).filter { $0.isScheduled() }
        VStack(alignment: .leading, spacing: 12) {
            Text("今日のリマインド").font(GenkiFont.headline()).foregroundStyle(GenkiPalette.text)
            if reminders.isEmpty {
                Text("まだリマインドがありません。「リマインダー」タブから追加できます。")
                    .font(GenkiFont.callout())
                    .foregroundStyle(GenkiPalette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .genkiCard()
            } else {
                ForEach(reminders) { reminder in
                    ReminderRowView(reminder: reminder)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(GenkiModelContainer.makePreview())
}
