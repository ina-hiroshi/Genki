import Foundation
import SwiftData

/// プレビュー / 初回体験用のサンプルデータ。
enum SampleData {
    @MainActor
    static func seed(into context: ModelContext) {
        let family = FamilyGroup(name: String(localized: "default_family_name"))
        context.insert(family)

        let mom = Member(name: String(localized: "sample_member_mom"), colorIndex: 0, isMe: true)
        let dad = Member(name: String(localized: "sample_member_dad"), colorIndex: 1)
        let sakura = Member(name: String(localized: "sample_member_sakura"), colorIndex: 2)
        for m in [mom, dad, sakura] {
            m.family = family
            context.insert(m)
        }

        let medicine = Reminder(
            title: String(localized: "sample_reminder_medicine"),
            symbolName: "pills",
            hour: 8,
            minute: 0,
            weekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        medicine.owner = mom
        medicine.family = family
        let walk = Reminder(
            title: String(localized: "sample_reminder_walk"),
            symbolName: "figure.walk",
            hour: 9,
            minute: 0,
            weekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        walk.owner = dad
        walk.family = family
        let water = Reminder(
            title: String(localized: "sample_reminder_water"),
            symbolName: "drop",
            hour: 11,
            minute: 0,
            weekdays: [1, 2, 3, 4, 5, 6, 7]
        )
        water.owner = sakura
        water.family = family
        for r in [medicine, walk, water] { context.insert(r) }

        // 今日の完了ログとチェックインを少しだけ。
        let doneMedicine = CompletionLog(reminder: medicine, member: mom)
        context.insert(doneMedicine)
        let reaction = Reaction(
            kind: .thumbsUp,
            authorName: String(localized: "sample_member_sakura"),
            completion: doneMedicine
        )
        context.insert(reaction)

        let momCheckIn = CheckIn(level: GenkiLevel.great.rawValue, member: mom)
        let sakuraCheckIn = CheckIn(level: GenkiLevel.okay.rawValue, member: sakura)
        context.insert(momCheckIn)
        context.insert(sakuraCheckIn)

        try? context.save()
    }
}
