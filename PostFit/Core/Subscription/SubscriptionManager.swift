//
//  SubscriptionManager.swift
//  PostFit (MomCare)
//
//  Manages in-app subscriptions using StoreKit 2
//  Handles 7-day free trial, purchase flow, and subscription verification
//

import Foundation
import StoreKit

// MARK: - Subscription Product IDs
enum SubscriptionProduct: String, CaseIterable {
    case monthlyPremium = "com.daipayan.postfit.premium.monthly"
    case yearlyPremium = "com.daipayan.postfit.premium.yearly"

    var displayName: String {
        switch self {
        case .monthlyPremium: return "Monthly Premium"
        case .yearlyPremium: return "Yearly Premium"
        }
    }

    var trialDays: Int {
        return 7 // 7-day free trial for all subscriptions
    }
}

// MARK: - Subscription Status
enum PurchaseStatus {
    case unknown
    case notSubscribed
    case subscribed(expirationDate: Date, isTrialPeriod: Bool)
    case expired(expirationDate: Date)
    case revoked

    var isActive: Bool {
        switch self {
        case .subscribed: return true
        default: return false
        }
    }

    var isTrialActive: Bool {
        switch self {
        case .subscribed(_, let isTrial): return isTrial
        default: return false
        }
    }
}

// MARK: - Subscription Manager
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var products: [Product] = []
    @Published var purchaseStatus: PurchaseStatus = .unknown
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var updateListenerTask: Task<Void, Error>?
    private let productIds = SubscriptionProduct.allCases.map { $0.rawValue }

    // MARK: - Initialization

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactionUpdates()

        // Load products and check status on init
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    /// Fetch available subscription products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            let storeProducts = try await Product.products(for: productIds)
            products = storeProducts.sorted { $0.price < $1.price }

            #if DEBUG
            print("💳 [Subscription] Loaded \(products.count) products:")
            for product in products {
                print("   - \(product.displayName): \(product.displayPrice)")
                if let offer = product.subscription?.introductoryOffer {
                    print("     Trial: \(offer.period.value) \(offer.period.unit)")
                }
            }
            #endif
        } catch {
            errorMessage = "Failed to load subscription options: \(error.localizedDescription)"
            #if DEBUG
            print("❌ [Subscription] Failed to load products: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Purchase

    /// Purchase a subscription product
    /// - Parameter product: The StoreKit product to purchase
    /// - Returns: True if purchase was successful
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                let transaction = try checkVerified(verification)

                // Update subscription status
                await updateSubscriptionStatus(from: transaction)

                // Finish the transaction
                await transaction.finish()

                #if DEBUG
                print("✅ [Subscription] Purchase successful!")
                #endif

                isLoading = false
                return true

            case .userCancelled:
                #if DEBUG
                print("ℹ️ [Subscription] User cancelled purchase")
                #endif
                isLoading = false
                return false

            case .pending:
                #if DEBUG
                print("⏳ [Subscription] Purchase pending (ask to buy, etc.)")
                #endif
                errorMessage = "Purchase is pending approval"
                isLoading = false
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            #if DEBUG
            print("❌ [Subscription] Purchase failed: \(error)")
            #endif
            isLoading = false
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()

            #if DEBUG
            print("✅ [Subscription] Purchases restored")
            #endif
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            #if DEBUG
            print("❌ [Subscription] Restore failed: \(error)")
            #endif
        }

        isLoading = false
    }

    // MARK: - Check Subscription Status

    /// Check current subscription status from App Store
    func checkSubscriptionStatus() async {
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productType == .autoRenewable {
                    await updateSubscriptionStatus(from: transaction)
                    return
                }
            } catch {
                #if DEBUG
                print("⚠️ [Subscription] Failed to verify transaction: \(error)")
                #endif
            }
        }

        // No active subscription found
        purchaseStatus = .notSubscribed
        updateUserSubscriptionStatus(.free)

        #if DEBUG
        print("ℹ️ [Subscription] No active subscription")
        #endif
    }

    // MARK: - Private Methods

    /// Listen for transaction updates (renewals, cancellations, etc.)
    private func listenForTransactionUpdates() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updateSubscriptionStatus(from: transaction)
                    await transaction.finish()
                } catch {
                    #if DEBUG
                    print("⚠️ [Subscription] Transaction update failed: \(error)")
                    #endif
                }
            }
        }
    }

    /// Verify the transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signedType):
            return signedType
        }
    }

    /// Update subscription status from a transaction
    private func updateSubscriptionStatus(from transaction: Transaction) async {
        // Check if subscription is revoked
        if transaction.revocationDate != nil {
            purchaseStatus = .revoked
            updateUserSubscriptionStatus(.free)
            return
        }

        // Check expiration
        guard let expirationDate = transaction.expirationDate else {
            purchaseStatus = .notSubscribed
            updateUserSubscriptionStatus(.free)
            return
        }

        if expirationDate > Date() {
            // Active subscription
            let isInTrial = transaction.offerType == .introductory
            purchaseStatus = .subscribed(expirationDate: expirationDate, isTrialPeriod: isInTrial)
            updateUserSubscriptionStatus(isInTrial ? .trial : .premium)

            #if DEBUG
            print("✅ [Subscription] Active until: \(expirationDate)")
            print("   Trial period: \(isInTrial)")
            #endif
        } else {
            // Expired
            purchaseStatus = .expired(expirationDate: expirationDate)
            updateUserSubscriptionStatus(.free)

            #if DEBUG
            print("⏰ [Subscription] Expired on: \(expirationDate)")
            #endif
        }
    }

    /// Update the user's subscription status in UserProfileManager
    private func updateUserSubscriptionStatus(_ status: SubscriptionStatus) {
        Task { @MainActor in
            if var user = UserProfileManager.shared.currentUser {
                user.subscriptionStatus = status
                UserProfileManager.shared.saveUser(user)

                #if DEBUG
                print("💾 [Subscription] Updated user status to: \(status.rawValue)")
                #endif
            }
        }
    }

    // MARK: - Helper Properties

    /// Get the monthly product
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.monthlyPremium.rawValue }
    }

    /// Get the yearly product
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProduct.yearlyPremium.rawValue }
    }

    /// Check if user has ever had a subscription (for trial eligibility)
    var isEligibleForTrial: Bool {
        // This would need to be tracked separately or checked via App Store
        // For now, assume eligible if not currently subscribed
        return !purchaseStatus.isActive
    }

    /// Get formatted trial info for a product
    func trialInfo(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer else { return nil }

        let periodUnit: String
        switch offer.period.unit {
        case .day: periodUnit = offer.period.value == 1 ? "day" : "days"
        case .week: periodUnit = offer.period.value == 1 ? "week" : "weeks"
        case .month: periodUnit = offer.period.value == 1 ? "month" : "months"
        case .year: periodUnit = offer.period.value == 1 ? "year" : "years"
        @unknown default: periodUnit = "period"
        }

        return "\(offer.period.value) \(periodUnit) free trial"
    }

    /// Get formatted subscription period for a product
    func subscriptionPeriod(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }

        switch period.unit {
        case .day: return period.value == 1 ? "daily" : "every \(period.value) days"
        case .week: return period.value == 1 ? "weekly" : "every \(period.value) weeks"
        case .month: return period.value == 1 ? "monthly" : "every \(period.value) months"
        case .year: return period.value == 1 ? "yearly" : "every \(period.value) years"
        @unknown default: return nil
        }
    }
}

// MARK: - Trial Eligibility Check
extension SubscriptionManager {
    /// Check if user is eligible for introductory offer
    func checkTrialEligibility() async -> Bool {
        guard let product = monthlyProduct ?? yearlyProduct else { return false }

        // StoreKit 2 way to check eligibility
        if let subscription = product.subscription {
            return await subscription.isEligibleForIntroOffer
        }

        return false
    }
}
