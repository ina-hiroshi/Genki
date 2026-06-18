import Foundation
import SwiftData

/// リマインド。繰り返し（曜日指定）または単発。担当メンバーと通知時刻を持つ。
@Model
final class Reminder {
    var id: UUID = UUID()
    var title: String = ""
    /// SF Symbol 名（ライン調アイコン）。
    var symbolName: String = "bell"
    var hour: Int = 8
    var minute: Int = 0
    /// 繰り返す曜日（1=日曜 ... 7=土曜）。空 = 単発。
    var weekdays: [Int] = []
    /// 単発リマインドの実施日。
    var oneTimeDate: Date?
    var createdAt: Date = Date.now

    var family: FamilyGroup?
    /// 担当者。
    var owner: Member?

    @Relationship(deleteRule: .cascade, inverse: \CompletionLog.reminder)
    var completions: [CompletionLog]? = []

    init(id: UUID = UUID(),
         title: String,
         symbolName: String = "bell",
         hour: Int = 8,
         minute: Int = 0,
         weekdays: [Int] = [],
         oneTimeDate: Date? = nil) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.oneTimeDate = oneTimeDate
    }

    var isRepeating: Bool { !weekdays.isEmpty }

    var timeText: String {
        String(format: "%d:%02d", hour, minute)
    }

    /// 指定日に完了済みか。
    func isCompleted(on day: Date = .now, calendar: Calendar = .current) -> Bool {
        (completions ?? []).contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// 指定日が対象日か（繰り返し曜日 or 単発日）。
    func isScheduled(on day: Date = .now, calendar: Calendar = .current) -> Bool {
        if isRepeating {
            let weekday = calendar.component(.weekday, from: day)
            return weekdays.contains(weekday)
        }
        if let oneTimeDate {
            return calendar.isDate(oneTimeDate, inSameDayAs: day)
        }
        return false
    }
}
