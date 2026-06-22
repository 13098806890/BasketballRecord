import StoreKit
import SwiftUI
import OSLog

private let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BasketballRecord", category: "Purchase")

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    @Published private(set) var isPro = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    private var cachedTransactionIds: [UInt64] = []
    private let cachedTxKey = "cached_transaction_id"

    var latestTransactionId: UInt64? {
        if let first = cachedTransactionIds.sorted().last { return first }
        return UserDefaults.standard.string(forKey: cachedTxKey).flatMap { UInt64($0) }
    }

    let monthlyProductID = "com.doxie.basketball.pro.monthly"
    let yearlyProductID = "com.doxie.basketball.pro.yearly"

    private var updates: Task<Void, Never>?

    private var allProductIDs: [String] { [monthlyProductID, yearlyProductID] }

    init() {
        isPro = UserDefaults.standard.bool(forKey: "is_pro")
        updates = observeTransactionUpdates()
        Task { await loadProducts(); await checkSubscriptionStatus() }
    }

    deinit { updates?.cancel() }

    func loadProducts() async {
        os_log(.debug, log: log, "Loading products")
        let products = try? await Product.products(for: allProductIDs)
        monthlyProduct = products?.first { $0.id == monthlyProductID }
        yearlyProduct = products?.first { $0.id == yearlyProductID }
    }

    func purchase(_ product: Product) async throws {
        os_log(.info, log: log, "Purchase started: %{public}@", product.id)
        let result = try await product.purchase()

        switch result {
        case let .success(.verified(transaction)):
            os_log(.info, log: log, "Transaction verified: id=%llu", transaction.id)
            await transaction.finish()
            await checkSubscriptionStatus()
        case let .success(.unverified(_, error)):
            throw PurchaseError.unverified(error)
        case .pending:
            os_log(.debug, log: log, "Purchase pending")
        case .userCancelled:
            throw PurchaseError.userCancelled
        @unknown default:
            break
        }
    }

    func restore() async {
        os_log(.info, log: log, "Restore purchases")
        try? await StoreKit.AppStore.sync()
        await checkSubscriptionStatus()
    }

    func checkSubscriptionStatus() async {
        os_log(.debug, log: log, "Checking subscription status")
        var isPro = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(t) = result,
                  allProductIDs.contains(t.productID),
                  t.revocationDate == nil,
                  t.expirationDate.map({ $0 > Date() }) ?? true else { continue }
            UserDefaults.standard.set("\(t.id)", forKey: cachedTxKey)
            isPro = true
        }

        if !isPro, let _ = UserDefaults.standard.string(forKey: cachedTxKey), !cachedTransactionIds.isEmpty {
            isPro = true
        }

        let old = self.isPro
        self.isPro = isPro
        UserDefaults.standard.set(isPro, forKey: "is_pro")
        if old != isPro { os_log(.info, log: log, "Pro status: %d -> %d", old, isPro) }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in Transaction.updates {
                if case let .verified(t) = update {
                    self?.cachedTransactionIds.append(t.id)
                    UserDefaults.standard.set("\(t.id)", forKey: self?.cachedTxKey ?? "cached_transaction_id")
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.checkSubscriptionStatus()
                await self?.loadProducts()
            }
        }
    }
}

enum PurchaseError: LocalizedError {
    case productNotFound, unverified(Error), userCancelled

    var errorDescription: String? {
        switch self {
        case .productNotFound: return NSLocalizedString("purchase_error_product_not_found", comment: "")
        case let .unverified(error): return String(format: NSLocalizedString("purchase_error_unverified_format", comment: ""), error.localizedDescription)
        case .userCancelled: return NSLocalizedString("purchase_error_cancelled", comment: "")
        }
    }
}
