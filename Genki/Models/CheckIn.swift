import Foundation
import SwiftData

/// 毎日の「元気だよ」チェックイン。誰が・いつ送ったか。
@Model
final class CheckIn {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// 任意のひとこと。
    var note: String?
    /// 目覚まし（ショートカット）経由かどうか。
    var fromAlarm: Bool = false

    var member: Member?

    @Relationship(deleteRule: .cascade, inverse: \Reaction.checkIn)
    var reactions: [Reaction]? = []

    init(id: UUID = UUID(),
         date: Date = .now,
         note: String? = nil,
         fromAlarm: Bool = false,
         member: Member? = nil) {
        self.id = id
        self.date = date
        self.note = note
        self.fromAlarm = fromAlarm
        self.member = member
    }
}
