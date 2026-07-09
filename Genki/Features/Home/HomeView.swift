import SwiftUI
import SwiftData

/// ホーム: 挨拶 → 「元気だよ」→ 家族の今日 → 今日のリマインド。
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var families: [FamilyGroup]

    private var family: FamilyGroup? { FamilyActions.activeFamily(from: families) }

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
            .navigationTitle(String(localized: "app_display_name"))
            .genkiTabNavigationStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SOSView()
                    } label: {
                        Image(systemName: "sos")
                            .font(.body.weight(.semibold))
                            .imageScale(.medium)
                            .foregroundStyle(GenkiPalette.sos)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(String(localized: "home_sos_a11y"))
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
        let partKey = hour < 11 ? "greeting_morning" : (hour < 18 ? "greeting_afternoon" : "greeting_evening")
        let part = String(localized: String.LocalizationValue(partKey))
        let name = CurrentUser.myName
        if name.isEmpty {
            return String(format: String(localized: "greeting_without_name_format"), part)
        }
        return String(format: String(localized: "greeting_with_name_format"), part, name)
    }

    @ViewBuilder
    private var familyToday: some View {
        if let family, !family.sortedMembers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "home_family_today")).font(GenkiFont.headline()).foregroundStyle(GenkiPalette.text)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(family.sortedMembers) { member in
                            VStack(spacing: 6) {
                                MemberAvatar(name: member.name,
                                             colorIndex: member.colorIndex,
                                             checkedIn: member.hasCheckedIn(),
                                             genkiLevel: member.todaysGenkiLevel())
                                Text(member.name)
                                    .font(GenkiFont.caption())
                                    .foregroundStyle(GenkiPalette.muted)
                                    .lineLimit(1)
                                if let level = member.todaysGenkiLevel() {
                                    Text(level.shortLabel)
                                        .font(GenkiFont.caption())
                                        .foregroundStyle(level.tint)
                                        .lineLimit(1)
                                }
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
            Text(String(localized: "home_today_reminders")).font(GenkiFont.headline()).foregroundStyle(GenkiPalette.text)
            if reminders.isEmpty {
                Text(String(localized: "home_no_reminders"))
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
