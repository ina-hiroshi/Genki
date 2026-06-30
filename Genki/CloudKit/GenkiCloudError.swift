import Foundation

enum GenkiCloudError: LocalizedError {
    case iCloudUnavailable
    case shareNotFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return String(localized: "error_icloud_unavailable")
        case .shareNotFound:
            return String(localized: "error_share_not_found")
        }
    }

    /// ユーザー向けメッセージ。CloudKit の生エラーをそのまま見せて誤判定を防ぐ。
    static func friendlyMessage(for error: Error) -> String {
        if let genki = error as? GenkiCloudError {
            return genki.localizedDescription
        }
        return technicalDetail(for: error)
    }

    /// ログ・UI 向けの詳細メッセージ。
    static func technicalDetail(for error: Error) -> String {
        if let ckError = error as? CKError {
            var lines = ["CK \(ckError.code.rawValue): \(ckError.localizedDescription)"]
            if ckError.code == .invalidArguments,
               ckError.localizedDescription.contains("cloudkit.share") {
                lines.append("ヒント: cloudkit.share 型が Production に未デプロイです。Mac で ./scripts/bootstrap-share-via-simulator.sh を実行し、CloudKit Dashboard から Deploy Schema Changes… を実行してください（iPhone の USB 接続は不要）。")
            }
            if ckError.code == .partialFailure || ckError.localizedDescription.contains("Atomic failure") {
                lines.append("ヒント: 共有レコードの保存に失敗しています。上記の cloudkit.share デプロイ手順を先に実行してください。")
            }
            if let partial = ckError.partialErrorsByItemID {
                for (itemID, itemError) in partial {
                    let ns = itemError as NSError
                    let name: String
                    if let recordID = itemID as? CKRecord.ID {
                        name = recordID.recordName
                    } else {
                        name = String(describing: itemID)
                    }
                    lines.append("  · \(name): \(ns.localizedDescription)")
                }
            }
            if let retry = ckError.retryAfterSeconds {
                lines.append("(再試行まで \(Int(retry)) 秒)")
            }
            return lines.joined(separator: "\n")
        }

        let ns = error as NSError
        if ns.domain == CKErrorDomain {
            return "CK \(ns.code): \(ns.localizedDescription)"
        }
        return ns.localizedDescription
    }
}

import CloudKit
