import Foundation

/// 初回14日間フル体験の開始日・残日数を App Group で管理する。
enum TrialManager {
    static let trialLengthDays = 14

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: GenkiConstants.appGroupID) ?? .standard
    }

    /// 家族作成時など、未開始ならトライアル開始日を記録する。
    static func startTrialIfNeeded() {
        guard defaults.string(forKey: GenkiConstants.trialStartDateKey) == nil else { return }
        defaults.set(isoString(from: .now), forKey: GenkiConstants.trialStartDateKey)
    }

    static var trialStartDate: Date? {
        guard let raw = defaults.string(forKey: GenkiConstants.trialStartDateKey) else { return nil }
        return isoFormatter.date(from: raw)
    }

    static var isInTrialPeriod: Bool {
        guard let start = trialStartDate else { return false }
        guard let end = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) else { return false }
        return Date.now < end
    }

    /// トライアル残日数（1〜14）。トライアル外なら nil。
    static var daysRemaining: Int? {
        guard isInTrialPeriod, let start = trialStartDate else { return nil }
        let elapsed = Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0
        let remaining = trialLengthDays - elapsed
        return max(1, remaining)
    }

    /// 期限3日以内ならソフトリマインド対象。
    static var shouldShowTrialEndingReminder: Bool {
        guard let remaining = daysRemaining else { return false }
        return remaining <= 3
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func isoString(from date: Date) -> String {
        isoFormatter.string(from: date)
    }
}
