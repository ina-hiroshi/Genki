import Foundation

/// ウィジェット / Watch に渡す軽量スナップショット。
/// アプリ本体が SwiftData から生成して App Group に書き出す。
public struct FamilySnapshot: Codable, Equatable, Sendable {
    public var familyName: String
    public var generatedAt: Date
    public var members: [MemberStatus]
    public var upcoming: [ReminderStatus]
    /// フル版（トライアル中・購入済・家族 premium）なら true。ウィジェット表示用。
    public var hasFullAccess: Bool

    public init(familyName: String,
                generatedAt: Date = .now,
                members: [MemberStatus],
                upcoming: [ReminderStatus],
                hasFullAccess: Bool = true) {
        self.familyName = familyName
        self.generatedAt = generatedAt
        self.members = members
        self.upcoming = upcoming
        self.hasFullAccess = hasFullAccess
    }

    public static var placeholder: FamilySnapshot {
        FamilySnapshot(
            familyName: String(localized: "default_family_name"),
            members: [
                MemberStatus(id: "1", name: String(localized: "sample_member_mom"), colorIndex: 0, checkedInToday: true, genkiLevel: .great),
                MemberStatus(id: "2", name: String(localized: "sample_member_dad"), colorIndex: 1, checkedInToday: false, genkiLevel: nil),
                MemberStatus(id: "3", name: String(localized: "sample_member_sakura"), colorIndex: 2, checkedInToday: true, genkiLevel: .okay)
            ],
            upcoming: [
                ReminderStatus(
                    id: "r1",
                    title: String(localized: "sample_reminder_medicine"),
                    ownerName: String(localized: "sample_member_mom"),
                    time: "8:00",
                    done: true,
                    colorIndex: 0
                ),
                ReminderStatus(
                    id: "r2",
                    title: String(localized: "sample_reminder_walk"),
                    ownerName: String(localized: "sample_member_dad"),
                    time: "9:00",
                    done: false,
                    colorIndex: 1
                )
            ]
        )
    }

    public static let empty = FamilySnapshot(familyName: "Genki", members: [], upcoming: [], hasFullAccess: false)
}

public struct MemberStatus: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var colorIndex: Int
    public var checkedInToday: Bool
    /// 今日の元気度。未チェックインなら nil。
    public var genkiLevel: Int?

    public init(id: String, name: String, colorIndex: Int, checkedInToday: Bool, genkiLevel: GenkiLevel? = nil) {
        self.id = id
        self.name = name
        self.colorIndex = colorIndex
        self.checkedInToday = checkedInToday
        self.genkiLevel = genkiLevel?.rawValue
    }

    public var level: GenkiLevel? {
        guard let genkiLevel else { return nil }
        return GenkiLevel(rawValue: genkiLevel)
    }
}

public struct ReminderStatus: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var ownerName: String
    public var time: String
    public var done: Bool
    public var colorIndex: Int

    public init(id: String, title: String, ownerName: String, time: String, done: Bool, colorIndex: Int) {
        self.id = id
        self.title = title
        self.ownerName = ownerName
        self.time = time
        self.done = done
        self.colorIndex = colorIndex
    }
}
