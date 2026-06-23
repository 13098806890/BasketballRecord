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
    private var isLoadingProducts = false

    let appAccountToken: UUID = {
        let ud = UserDefaults.standard
        let kvs = try? NSUbiquitousKeyValueStore.default
        let key = "app_account_token"
        // Try iCloud first (cross-device), then UserDefaults
        let saved = kvs?.string(forKey: key) ?? ud.string(forKey: key)
        if let s = saved, let uuid = UUID(uuidString: s) {
            if ud.string(forKey: key) == nil { ud.set(uuid.uuidString, forKey: key) }
            return uuid
        }
        let uuid = UUID()
        ud.set(uuid.uuidString, forKey: key)
        kvs?.set(uuid.uuidString, forKey: key)
        kvs?.synchronize()
        return uuid
    }()



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
        if monthlyProduct != nil || yearlyProduct != nil || isLoadingProducts { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        os_log(.info, log: log, "Loading products")
        let loaded = await withTaskGroup(of: [Product]?.self) { group in
            group.addTask { try? await Product.products(for: self.allProductIDs) }
            group.addTask {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                return nil
            }
            for await result in group {
                if let products = result { return products }
            }
            return []
        }
        monthlyProduct = loaded.first { $0.id == monthlyProductID }
        yearlyProduct = loaded.first { $0.id == yearlyProductID }
        os_log(.info, log: log, "Products: monthly=%@, yearly=%@",
              monthlyProduct != nil ? "✅" : "nil",
              yearlyProduct != nil ? "✅" : "nil")
    }

    func purchase(_ product: Product) async throws {
        os_log(.info, log: log, "Purchase started: %{public}@", product.id)
        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])

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
            isPro = true
        }

        self.isPro = isPro
        UserDefaults.standard.set(isPro, forKey: "is_pro")
        os_log(.info, log: log, "Pro status: %d", isPro)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await _ in Transaction.updates {
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
