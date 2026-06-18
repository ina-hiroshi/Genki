import WidgetKit
import SwiftUI

/// 家族の今日の状態を「開かずにちらっと見る」ためのウィジェット。
struct FamilyStatusWidget: Widget {
    let kind = "FamilyStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FamilyStatusEntryView(entry: entry)
                .containerBackground(GenkiPalette.background, for: .widget)
        }
        .configurationDisplayName("家族の今日")
        .description("家族のチェックインとリマインドの状態をひと目で。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: FamilySnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: .now, snapshot: load())
        // 1時間ごと、または共有ストア更新時（reloadAllTimelines）に更新。
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> FamilySnapshot {
        GenkiSharedStore().load() ?? .placeholder
    }
}

struct FamilyStatusEntryView: View {
    var entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "sun.max.fill").foregroundStyle(GenkiPalette.primary)
                Text(entry.snapshot.familyName)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(GenkiPalette.text)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                ForEach(entry.snapshot.members.prefix(family == .systemSmall ? 3 : 6)) { member in
                    WidgetAvatar(member: member)
                }
            }

            if family == .systemMedium, let next = entry.snapshot.upcoming.first {
                HStack(spacing: 6) {
                    Image(systemName: next.done ? "checkmark.circle.fill" : "clock")
                        .foregroundStyle(next.done ? GenkiPalette.done : GenkiPalette.muted)
                    Text("\(next.title)・\(next.ownerName)")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(GenkiPalette.muted)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct WidgetAvatar: View {
    var member: MemberStatus

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(GenkiPalette.memberColor(for: member.colorIndex).opacity(0.2))
                .overlay(Circle().stroke(GenkiPalette.memberColor(for: member.colorIndex), lineWidth: 1.5))
                .frame(width: 30, height: 30)
                .overlay(
                    Text(String(member.name.prefix(1)))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GenkiPalette.text)
                )
            if member.checkedInToday {
                Circle().fill(GenkiPalette.done).frame(width: 9, height: 9)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
        }
    }
}
