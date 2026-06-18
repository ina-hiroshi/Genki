import Foundation
import SwiftData

/// プレビュー / 初回体験用のサンプルデータ。
enum SampleData {
    @MainActor
    static func seed(into context: ModelContext) {
        let family = FamilyGroup(name: "わたしの家族")
        context.insert(family)

        let mom = Member(name: "お母さん", colorIndex: 0, isMe: true)
        let dad = Member(name: "お父さん", colorIndex: 1)
        let sakura = Member(name: "さくら", colorIndex: 2)
        for m in [mom, dad, sakura] {
            m.family = family
            context.insert(m)
        }

        let medicine = Reminder(title: "おくすり", symbolName: "pills", hour: 8, minute: 0, weekdays: [1, 2, 3, 4, 5, 6, 7])
        medicine.owner = mom
        medicine.family = family
        let walk = Reminder(title: "散歩", symbolName: "figure.walk", hour: 9, minute: 0, weekdays: [1, 2, 3, 4, 5, 6, 7])
        walk.owner = dad
        walk.family = family
        let water = Reminder(title: "水分をとる", symbolName: "drop", hour: 11, minute: 0, weekdays: [1, 2, 3, 4, 5, 6, 7])
        water.owner = sakura
        water.family = family
        for r in [medicine, walk, water] { context.insert(r) }

        // 今日の完了ログとチェックインを少しだけ。
        let doneMedicine = CompletionLog(reminder: medicine, member: mom)
        context.insert(doneMedicine)
        let reaction = Reaction(kind: .thumbsUp, authorName: "さくら", completion: doneMedicine)
        context.insert(reaction)

        let momCheckIn = CheckIn(member: mom)
        let sakuraCheckIn = CheckIn(member: sakura)
        context.insert(momCheckIn)
        context.insert(sakuraCheckIn)

        try? context.save()
    }
}
