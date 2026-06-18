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
        if ns.domain == CKErrorDomain {
            switch CKError.Code(rawValue: ns.code) {
            case .notAuthenticated, .accountTemporarilyUnavailable:
                return GenkiCloudError.iCloudUnavailable.localizedDescription
            case .unknownItem:
                return "CloudKit上に家族データが見つかりませんでした。もう一度「共有リンクを送る」をお試しください。"
            default:
                break
            }
        }
        if ns.localizedDescription.contains("Did not find record type")
            || ns.localizedDescription.contains("Cannot create new type") {
            return """
            CloudKitのスキーマがProduction環境に未デプロイです。\
            開発者が CloudKit Dashboard または scripts/deploy-cloudkit-schema.sh で \
            FamilyGroup / CheckIn / CompletionLog をデプロイしてください。
            """
        }
        return ns.localizedDescription
    }
}

import CloudKit
