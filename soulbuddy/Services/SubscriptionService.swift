import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionStatus: RenewalInfo?
    @Published var isLoading = false
    
    private let productIds = ["soul_pal_premium_monthly"] // Replace with your actual product ID
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    private init() {
        // Start a transaction listener as close to app launch as possible.
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver products to the user.
                    await self.updateCustomerProductStatus()
                    
                    // Always finish a transaction.
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content to the user.
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    @MainActor
    func requestProducts() async {
        do {
            isLoading = true
            // Request products from the App Store using the identifiers that the Products.plist file defines.
            let storeProducts = try await Product.products(for: productIds)
            
            var newProducts: [Product] = []
            
            // Filter the products into categories based on their type.
            for product in storeProducts {
                switch product.type {
                case .autoRenewable:
                    newProducts.append(product)
                default:
                    // Ignore this product.
                    print("Unknown product")
                }
            }
            
            // Sort each product category by price.
            products = sortByPrice(newProducts)
            isLoading = false
        } catch {
            print("Failed product request from the App Store server: \(error)")
            isLoading = false
        }
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        // Begin purchasing the `Product` the user selects.
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check whether the transaction is verified. If it isn't,
            // this function rethrows the verification error.
            let transaction = try checkVerified(verification)
            
            // The transaction is verified. Deliver content to the user.
            await updateCustomerProductStatus()
            
            // Always finish a transaction.
            await transaction.finish()
            
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification.
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification.
            throw StoreKitError(.failedVerification)
        case .verified(let safe):
            // The result is verified. Return the unwrapped value.
            return safe
        }
    }
    
    @MainActor
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []
        
        // Iterate through all of the user's purchased products.
        for await result in Transaction.currentEntitlements {
            do {
                // Check whether the transaction is verified. If it isn't, catch `failedVerification` error.
                let transaction = try checkVerified(result)
                
                // Check the `productType` of the transaction and get the corresponding product from the store.
                switch transaction.productType {
                case .autoRenewable:
                    if let subscription = products.first(where: { $0.id == transaction.productID }) {
                        purchasedSubscriptions.append(subscription)
                    }
                default:
                    break
                }
            } catch {
                print("Failed to verify transaction")
            }
        }
        
        self.purchasedSubscriptions = purchasedSubscriptions
        
        // Update subscription status
        subscriptionStatus = nil
        
        // Check the `subscriptionGroupStatus` to learn the auto-renewable subscription state to determine whether the customer
        // is new (never subscribed), active, or inactive (expired subscription). This app has only one subscription
        // group, so products in the subscriptions array all belong to the same group. The statuses that
        // `product.subscription.status` returns apply to the entire subscription group.
        if let product = products.first {
            subscriptionStatus = try? await product.subscription?.status.first?.renewalInfo
        }
        
        // Update SupabaseService with subscription status
        let isSubscribed = !purchasedSubscriptions.isEmpty
        if SupabaseService.shared.isSubscriber != isSubscribed {
            // TODO: Update backend subscription status
            // This should call your backend to verify the receipt and update the user's subscription status
        }
    }
    
    func sortByPrice(_ products: [Product]) -> [Product] {
        products.sorted(by: { return $0.price < $1.price })
    }
    
    // MARK: - Subscription Status Helpers
    
    var isSubscriptionActive: Bool {
        !purchasedSubscriptions.isEmpty
    }
    
    var subscriptionExpirationDate: Date? {
        subscriptionStatus?.expirationDate
    }
    
    var willAutoRenew: Bool {
        subscriptionStatus?.willAutoRenew ?? false
    }
}

struct PurchaseView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .accessibilityLabel(Text("Premium upgrade"))
                    
                    Text("Unlock Premium Features")
                        .font(.title)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Get personalized mood sessions and scheduled notifications")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Features list
                VStack(spacing: 16) {
                    FeatureRow(icon: "brain.head.profile", title: "Weekly Mood Sessions", description: "Personalized affirmations based on your selected category")
                    FeatureRow(icon: "bell.fill", title: "Smart Notifications", description: "1-4 daily reminders respecting your timezone and quiet hours")
                    FeatureRow(icon: "heart.text.square", title: "Category Selection", description: "Choose from confidence, motivation, self-love, and more")
                    FeatureRow(icon: "calendar.badge.clock", title: "Intelligent Scheduling", description: "No repeated affirmations within 30 days")
                }
                .padding(.vertical)
                
                Spacer()
                
                // Products
                if subscriptionService.isLoading {
                    ProgressView("Loading subscription options...")
                        .accessibilityLabel(Text("Loading subscription options"))
                } else if subscriptionService.products.isEmpty {
                    Text("Unable to load subscription options")
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 12) {
                        ForEach(subscriptionService.products, id: \.id) { product in
                            PurchaseButton(product: product) {
                                await purchaseProduct(product)
                            }
                        }
                    }
                }
                
                // Restore purchases
                Button("Restore Purchases") {
                    Task {
                        try? await AppStore.sync()
                        await subscriptionService.updateCustomerProductStatus()
                    }
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .accessibilityLabel(Text("Restore previous purchases"))
                
                // Legal links
                HStack(spacing: 16) {
                    Link("Terms", destination: URL(string: "https://soulpal.com/terms")!)
                    Text("•")
                    Link("Privacy", destination: URL(string: "https://soulpal.com/privacy")!)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred during purchase")
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) async {
        do {
            if try await subscriptionService.purchase(product) != nil {
                // Purchase successful - UI will update automatically via published properties
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct PurchaseButton: View {
    let product: Product
    let onPurchase: () async -> Void
    
    @State private var isPurchasing = false
    
    var body: some View {
        Button {
            Task {
                isPurchasing = true
                await onPurchase()
                isPurchasing = false
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let subscription = product.subscription {
                        Text(subscription.subscriptionPeriod.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isPurchasing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(product.displayPrice)
                        .font(.headline)
                        .fontWeight(.bold)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.yellow.opacity(0.2))
                    .stroke(.yellow, lineWidth: 2)
            )
            .foregroundColor(.primary)
        }
        .disabled(isPurchasing)
        .accessibilityLabel(Text("Purchase \(product.displayName) for \(product.displayPrice)"))
    }
}

extension Product.SubscriptionPeriod {
    var localizedDescription: String {
        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) years"
        @unknown default:
            return "Unknown period"
        }
    }
}

#Preview {
    PurchaseView()
} 