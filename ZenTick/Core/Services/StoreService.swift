import StoreKit

@Observable
final class StoreService {
    private(set) var isPro: Bool = false
    private(set) var proProduct: Product?
    private var updates: Task<Void, Never>?

    static let proProductID = "zentick_pro"

    init() {
        updates = observeTransactionUpdates()
        Task {
            await loadProducts()
            await checkEntitlements()
        }
    }

    deinit {
        updates?.cancel()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    @discardableResult
    func purchase() async throws -> Bool {
        guard let product = proProduct else { return false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID
            {
                isPro = true
                return
            }
        }
        isPro = false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.checkEntitlements()
                }
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
