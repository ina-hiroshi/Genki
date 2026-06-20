import Foundation
import SwiftData

/// 家族グループ。CKShare で共有する単位。
/// CloudKit ミラーリング互換のため、全プロパティに既定値・リレーションは任意。
@Model
final class FamilyGroup {
    var id: UUID = UUID()
    var name: String = "わたしの家族"
    var createdAt: Date = Date.now

    /// CloudKit 共有ゾーンのルートレコード名。
    var shareRecordName: String?
    /// 共有ゾーンのオーナー（参加者端末で sharedDB 読み書きに必要）。
    var cloudKitRootZoneOwnerName: String?
    /// 共有データの CloudKit ゾーン名（GenkiSharedZone または _defaultZone）。
    var cloudKitZoneName: String?

    @Relationship(deleteRule: .cascade, inverse: \Member.family)
    var members: [Member]? = []

    @Relationship(deleteRule: .cascade, inverse: \Reminder.family)
    var reminders: [Reminder]? = []

    init(id: UUID = UUID(), name: String = "わたしの家族", createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    var sortedMembers: [Member] {
        (members ?? []).sorted { $0.joinedAt < $1.joinedAt }
    }

    var sortedReminders: [Reminder] {
        (reminders ?? []).sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }
}
