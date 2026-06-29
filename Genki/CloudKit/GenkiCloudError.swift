import Foundation

enum GenkiCloudError: LocalizedError {
    case iCloudUnavailable
    case shareNotFound

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloudにサインインしてください。設定アプリ → Apple ID → iCloud で確認できます。"
        case .shareNotFound:
            return "共有リンクが見つかりませんでした。もう一度お試しください。"
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
                lines.append("ヒント: 新規 CKShare は .allKeys で root と同時保存が必要です。共有シート内で再試行してください。")
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
