import Foundation

/// この端末の本人（Member）やオンボーディング状態を保持する軽量ストア。
/// App Group に保存し、App Intent からも参照できるようにする。
enum CurrentUser {
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: GenkiConstants.appGroupID) ?? .standard
    }

    private static let myMemberIDKey = "genki.myMemberID"
    private static let onboardedKey = "genki.onboarded"
    private static let myNameKey = "genki.myName"

    static var myMemberID: UUID? {
        get {
            guard let s = defaults.string(forKey: myMemberIDKey) else { return nil }
            return UUID(uuidString: s)
        }
        set { defaults.set(newValue?.uuidString, forKey: myMemberIDKey) }
    }

    static var myName: String {
        get { defaults.string(forKey: myNameKey) ?? "" }
        set { defaults.set(newValue, forKey: myNameKey) }
    }

    static var isOnboarded: Bool {
        get { defaults.bool(forKey: onboardedKey) }
        set { defaults.set(newValue, forKey: onboardedKey) }
    }

    /// データ削除後に呼び、オンボーディング画面へ戻す。
    static func reset() {
        myMemberID = nil
        myName = ""
        isOnboarded = false
    }
}
