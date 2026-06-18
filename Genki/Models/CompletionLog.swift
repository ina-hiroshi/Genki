import Foundation
import SwiftData

/// 「誰が・いつ」リマインドを完了したかの記録。履歴は永久に保持する（課金の壁で隠さない）。
@Model
final class CompletionLog {
    var id: UUID = UUID()
    var date: Date = Date.now

    var reminder: Reminder?
    var member: Member?

    @Relationship(deleteRule: .cascade, inverse: \Reaction.completion)
    var reactions: [Reaction]? = []

    init(id: UUID = UUID(), date: Date = .now, reminder: Reminder? = nil, member: Member? = nil) {
        self.id = id
        self.date = date
        self.reminder = reminder
        self.member = member
    }
}
