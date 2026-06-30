import SwiftUI

/// 毎日の体調チェックイン用の3段階元気度。
public enum GenkiLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case rough = 1
    case okay = 2
    case great = 3

    public var id: Int { rawValue }

    public static var `default`: GenkiLevel { .okay }

    public init?(rawValue: Int) {
        switch rawValue {
        case 1: self = .rough
        case 2: self = .okay
        case 3: self = .great
        default: return nil
        }
    }

    public var symbolName: String {
        switch self {
        case .great: "sun.max.fill"
        case .okay: "sun.max"
        case .rough: "cloud.sun.fill"
        }
    }

    public var label: String {
        switch self {
        case .great: String(localized: "genki_level_great")
        case .okay: String(localized: "genki_level_okay")
        case .rough: String(localized: "genki_level_rough")
        }
    }

    public var detail: String {
        switch self {
        case .great: String(localized: "genki_level_great_detail")
        case .okay: String(localized: "genki_level_okay_detail")
        case .rough: String(localized: "genki_level_rough_detail")
        }
    }

    public var shortLabel: String {
        switch self {
        case .great: String(localized: "genki_level_great_short")
        case .okay: String(localized: "genki_level_okay_short")
        case .rough: String(localized: "genki_level_rough_short")
        }
    }

    public var tint: Color {
        switch self {
        case .great: GenkiPalette.done
        case .okay: GenkiPalette.primary
        case .rough: GenkiPalette.genkiRough
        }
    }

    /// 家族向け通知の本文。
    public var notificationBody: String {
        switch self {
        case .great: String(localized: "notif_check_in_body_great")
        case .okay: String(localized: "notif_check_in_body_okay")
        case .rough: String(localized: "notif_check_in_body_rough")
        }
    }

    /// ローカル通知アクション ID。
    public var notificationActionID: String {
        "checkin_level_\(rawValue)"
    }

    public static func fromNotificationActionID(_ id: String) -> GenkiLevel? {
        guard id.hasPrefix("checkin_level_"),
              let value = Int(id.replacingOccurrences(of: "checkin_level_", with: "")),
              let level = GenkiLevel(rawValue: value) else { return nil }
        return level
    }
}
