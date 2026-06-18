import Foundation
import CloudKit
import os

/// 家族の変更（完了・チェックイン・リアクション）を検知して
/// サイレントプッシュを受け取るための CKSubscription を管理する。
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private let manager: CloudKitManager
    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "Subscription")

    /// 重複登録を避けるためのフラグ。
    private let privateSubscriptionID = "genki-private-changes"
    private let sharedSubscriptionID = "genki-shared-changes"

    init(manager: CloudKitManager = .shared) {
        self.manager = manager
    }

    /// private / shared 両方のデータベース変更購読を登録する。
    func registerSubscriptions() async {
        guard FeatureFlags.cloudKitEnabled else { return }
        await register(id: privateSubscriptionID, in: manager.privateDB)
        await register(id: sharedSubscriptionID, in: manager.sharedDB)
    }

    private func register(id: String, in database: CKDatabase) async {
        let subscription = CKDatabaseSubscription(subscriptionID: id)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true // サイレントプッシュ
        subscription.notificationInfo = notificationInfo

        let op = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription],
                                                subscriptionIDsToDelete: nil)
        op.qualityOfService = .utility
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            op.modifySubscriptionsResultBlock = { [weak self] result in
                if case .failure(let error) = result {
                    self?.logger.error("subscription(\(id)) error: \(error.localizedDescription)")
                }
                cont.resume()
            }
            database.add(op)
        }
    }
}
