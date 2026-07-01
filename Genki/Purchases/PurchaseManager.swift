import Foundation
import StoreKit
import os

/// StoreKit 2 による買い切り IAP（`com.itoguchi.Genki.unlock`）の読み込み・購入・復元。
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private(set) var product: Product?
    private(set) var hasLocalPurchase = false
    private(set) var isLoading = false
    private(set) var lastErrorMessage: String?

    private let logger = Logger(subsystem: "com.itoguchi.Genki", category: "Purchase")
    private var updatesTask: Task<Void, Never>?

    private init() {}

    func start() async {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                await self.handle(transactionResult: result)
            }
        }
        await loadProduct()
        await refreshEntitlements()
    }

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [GenkiConstants.fullUnlockProductID])
            product = products.first
            if product == nil {
                logger.error("product not found: \(GenkiConstants.fullUnlockProductID, privacy: .public)")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("loadProduct error: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshEntitlements() async {
        var purchased = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verify(result),
                  transaction.productID == GenkiConstants.fullUnlockProductID else { continue }
            purchased = true
        }
        hasLocalPurchase = purchased
        FeatureGate.cacheLocalPurchase(purchased)
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            lastErrorMessage = String(localized: "purchase_error_product_unavailable")
            return false
        }
        lastErrorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verify(verification)
                await transaction.finish()
                hasLocalPurchase = true
                return true
            case .userCancelled:
                return false
            case .pending:
                lastErrorMessage = String(localized: "purchase_error_pending")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("purchase error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func restorePurchases() async -> Bool {
        lastErrorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if hasLocalPurchase { return true }
            lastErrorMessage = String(localized: "purchase_restore_not_found")
            return false
        } catch {
            lastErrorMessage = error.localizedDescription
            logger.error("restore error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = try? verify(transactionResult),
              transaction.productID == GenkiConstants.fullUnlockProductID else { return }
        hasLocalPurchase = true
        await transaction.finish()
        NotificationCenter.default.post(name: .genkiPurchaseDidChange, object: nil)
        await EntitlementStore.shared.handleLocalPurchaseConfirmed()
    }

    private func verify<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }
}
