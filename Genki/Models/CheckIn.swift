import Foundation
import SwiftData

/// 毎日の体調チェックイン。誰が・いつ・どの元気度で報告したか。
@Model
final class CheckIn {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// 元気度（1=ちょっとつらい, 2=普通, 3=とても元気）。
    var level: Int = GenkiLevel.okay.rawValue
    /// 任意のひとこと。
    var note: String?
    /// 目覚まし（ショートカット）経由かどうか。
    var fromAlarm: Bool = false

    var member: Member?

    @Relationship(deleteRule: .cascade, inverse: \Reaction.checkIn)
    var reactions: [Reaction]? = []

    var genkiLevel: GenkiLevel {
        get { GenkiLevel(rawValue: level) ?? .okay }
        set { level = newValue.rawValue }
    }

    init(id: UUID = UUID(),
         date: Date = .now,
         level: Int = GenkiLevel.okay.rawValue,
         note: String? = nil,
         fromAlarm: Bool = false,
         member: Member? = nil) {
        self.id = id
        self.date = date
        self.level = level
        self.note = note
        self.fromAlarm = fromAlarm
        self.member = member
    }
}
