import Foundation
import SwiftData

/// 完了 / チェックインへのリアクション（スタンプ）。つながりの心臓部。
@Model
final class Reaction {
    var id: UUID = UUID()
    /// ReactionKind の rawValue。
    var kindRaw: String = ReactionKind.heart.rawValue
    var date: Date = Date.now
    /// 反応した人の名前（スナップショット）。
    var authorName: String = ""

    var completion: CompletionLog?
    var checkIn: CheckIn?

    init(id: UUID = UUID(),
         kind: ReactionKind,
         date: Date = .now,
         authorName: String,
         completion: CompletionLog? = nil,
         checkIn: CheckIn? = nil) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.date = date
        self.authorName = authorName
        self.completion = completion
        self.checkIn = checkIn
    }

    var kind: ReactionKind {
        ReactionKind(rawValue: kindRaw) ?? .heart
    }
}
