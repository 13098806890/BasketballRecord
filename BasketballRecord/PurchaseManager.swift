import StoreKit
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Personal build override — set false on main branch
    private static let forcePro = true

    @Published private(set) var isPro = PurchaseManager.forcePro || UserDefaults.standard.bool(forKey: "is_pro")
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?

    let monthlyProductID = "com.doxie.basketball.pro.monthly"
    let yearlyProductID = "com.doxie.basketball.pro.yearly"

    private var updates: Task<Void, Never>?

    private var allProductIDs: [String] {
        [monthlyProductID, yearlyProductID]
    }

    init() {
        updates = observeTransactionUpdates()
        Task { await loadProducts(); await checkSubscriptionStatus() }
    }

    deinit {
        updates?.cancel()
    }

    func loadProducts() async {
        let products = try? await Product.products(for: allProductIDs)
        monthlyProduct = products?.first { $0.id == monthlyProductID }
        yearlyProduct = products?.first { $0.id == yearlyProductID }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case let .success(.verified(transaction)):
            await transaction.finish()
            await checkSubscriptionStatus()
        case let .success(.unverified(_, error)):
            throw PurchaseError.unverified(error)
        case .pending:
            break
        case .userCancelled:
            throw PurchaseError.userCancelled
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await StoreKit.AppStore.sync()
        await checkSubscriptionStatus()
    }

    func checkSubscriptionStatus() async {
        guard !Self.forcePro else {
            isPro = true
            UserDefaults.standard.set(true, forKey: "is_pro")
            return
        }

        var isPro = false

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard allProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true else {
                continue
            }
            isPro = true
        }

        self.isPro = isPro
        UserDefaults.standard.set(isPro, forKey: "is_pro")
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.checkSubscriptionStatus()
            }
        }
    }
}

enum PurchaseError: LocalizedError {
    case productNotFound
    case unverified(Error)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return NSLocalizedString("purchase_error_product_not_found", comment: "Product not found")
        case let .unverified(error):
            return String(format: NSLocalizedString("purchase_error_unverified_format", comment: "Unverified"), error.localizedDescription)
        case .userCancelled:
            return NSLocalizedString("purchase_error_cancelled", comment: "Cancelled")
        }
    }
}
