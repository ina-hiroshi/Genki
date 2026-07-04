import Foundation
import Observation

/// シミュレーターでの cloudkit.share 初回生成（UI テスト / スクリプト用）。
@MainActor
@Observable
final class ShareBootstrapState {
    static let shared = ShareBootstrapState()

    var accessibilityID = "genki-bootstrap-pending"
    var lastError: String?
    var lastShareURL: String?

    func markPending() {
        accessibilityID = "genki-bootstrap-pending"
        lastError = nil
        lastShareURL = nil
    }

    func markSuccess(shareURL: String? = nil) {
        accessibilityID = "genki-bootstrap-ok"
        lastError = nil
        lastShareURL = shareURL
        #if DEBUG
        if let shareURL, let url = URL(string: shareURL) {
            ShareTestSupport.storeLastShareURL(url)
        }
        #endif
    }

    func markFailure(_ message: String) {
        accessibilityID = "genki-bootstrap-fail"
        lastError = message
    }
}
