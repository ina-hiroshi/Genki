import Foundation

/// アプリ全体で共有する定数。App / Widget / Watch から参照される。
public enum GenkiConstants {
    /// App Group。ウィジェットやWatchとデータを共有するために使用。
    public static let appGroupID = "group.com.itoguchi.genki"

    /// CloudKit コンテナID。
    public static let iCloudContainerID = "iCloud.com.itoguchi.genki"

    /// 共有スナップショットの保存キー。
    public static let snapshotDefaultsKey = "genki.family.snapshot.v1"

    /// ディープリンクのスキーム。
    public static let urlScheme = "genki"
}

/// 完了・チェックインに送れるリアクション（ステッカー）。
/// 絵文字直貼りを避け、SF Symbol ベースのブランド調アイコンで表現する。
public enum ReactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case heart
    case thumbsUp
    case smile
    case clap
    case star

    public var id: String { rawValue }

    /// SF Symbol 名。
    public var symbolName: String {
        switch self {
        case .heart: return "heart.fill"
        case .thumbsUp: return "hand.thumbsup.fill"
        case .smile: return "face.smiling.fill"
        case .clap: return "hands.clap.fill"
        case .star: return "star.fill"
        }
    }

    /// アクセシビリティ用の読み上げラベル。
    public var accessibilityLabel: String {
        switch self {
        case .heart: return "ハート"
        case .thumbsUp: return "いいね"
        case .smile: return "笑顔"
        case .clap: return "拍手"
        case .star: return "スター"
        }
    }
}
