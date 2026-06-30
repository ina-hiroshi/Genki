import Foundation
import Observation

/// シミュレーターでの cloudkit.share 初回生成（UI テスト / スクリプト用）。
@MainActor
@Observable
final class ShareBootstrapState {
    static let shared = ShareBootstrapState()

    var accessibilityID = "genki-bootstrap-pending"
    var lastError: String?

    func markPending() {
        accessibilityID = "genki-bootstrap-pending"
        lastError = nil
    }

    func markSuccess() {
        accessibilityID = "genki-bootstrap-ok"
        lastError = nil
    }

    func markFailure(_ message: String) {
        accessibilityID = "genki-bootstrap-fail"
        lastError = message
    }
}
