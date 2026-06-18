import Foundation
import SwiftData

/// 家族メンバー。役割を持たない対称設計（誰でもリマインド・完了・チェックイン・反応ができる）。
@Model
final class Member {
    var id: UUID = UUID()
    var name: String = ""
    /// メンバーカラーのインデックス（GenkiPalette.memberColors に対応）。
    var colorIndex: Int = 0
    /// この端末の本人かどうか。
    var isMe: Bool = false
    var joinedAt: Date = Date.now

    var family: FamilyGroup?

    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.member)
    var completions: [CompletionLog]? = []

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.member)
    var checkIns: [CheckIn]? = []

    @Relationship(deleteRule: .nullify, inverse: \Reminder.owner)
    var ownedReminders: [Reminder]? = []

    init(id: UUID = UUID(),
         name: String,
         colorIndex: Int = 0,
         isMe: Bool = false,
         joinedAt: Date = .now) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.isMe = isMe
        self.joinedAt = joinedAt
    }

    /// 今日チェックイン済みか。
    func hasCheckedIn(on day: Date = .now, calendar: Calendar = .current) -> Bool {
        (checkIns ?? []).contains { calendar.isDate($0.date, inSameDayAs: day) }
    }
}
