import Foundation

enum GenkiCloudError: LocalizedError {
    case iCloudUnavailable
    case shareNotFound
    case schemaNotDeployed(String)

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "iCloudにサインインしてください。設定アプリ → Apple ID → iCloud で確認できます。"
        case .shareNotFound:
            return "共有リンクが見つかりませんでした。もう一度お試しください。"
        case .schemaNotDeployed(let detail):
            return "CloudKitの設定が未完了です。\(detail)"
        }
    }

    static func friendlyMessage(for error: Error) -> String {
        if let genki = error as? GenkiCloudError {
            return genki.localizedDescription
        }
        let ns = error as NSError

        // スキーマ未デプロイは文言から判定（CKError コードに依らず最優先）。
        if ns.localizedDescription.contains("Did not find record type")
            || ns.localizedDescription.contains("Cannot create new type")
            || ns.localizedDescription.contains("record type") {
            return """
            CloudKitのスキーマがProduction環境に未デプロイの可能性があります。\
            開発者が CloudKit Dashboard で FamilyGroup / CheckIn / CompletionLog をデプロイしてください。
            """
        }

        if ns.domain == CKErrorDomain {
            switch CKError.Code(rawValue: ns.code) {
            case .notAuthenticated, .accountTemporarilyUnavailable:
                return GenkiCloudError.iCloudUnavailable.localizedDescription
            case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
                return "ネットワークに接続できませんでした。電波の良い場所でもう一度お試しください。"
            case .quotaExceeded:
                return "iCloudの容量が不足しています。空き容量を確保してからお試しください。"
            case .unknownItem:
                return "CloudKit上に家族データが見つかりませんでした。もう一度「共有リンクを送る」をお試しください。"
            case .permissionFailure:
                return "iCloud共有の権限がありません。設定アプリ → Apple ID → iCloud をご確認ください。"
            default:
                // 切り分けのため CKError コードを併記する。
                return "iCloud共有でエラーが発生しました（コード \(ns.code)）。\(ns.localizedDescription)"
            }
        }
        return ns.localizedDescription
    }
}

import CloudKit
