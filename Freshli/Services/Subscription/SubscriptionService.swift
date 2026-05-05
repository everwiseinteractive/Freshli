import Foundation
import Observation
import StoreKit
import SwiftUI

// MARK: - Product Extension

extension Product {
    var localizedPeriod: String {
        guard let subscription = subscription else { return "" }

        switch subscription.subscriptionPeriod.unit {
        case .day:
            return subscription.subscriptionPeriod.value == 1 ? "per day" : "\(subscription.subscriptionPeriod.value) days"
        case .week:
            return subscription.subscriptionPeriod.value == 1 ? "per week" : "\(subscription.subscriptionPeriod.value) weeks"
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "/month" : "\(subscription.subscriptionPeriod.value) months"
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "/year" : "\(subscription.subscriptionPeriod.value) years"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Product IDs

enum SubscriptionProductID: String, CaseIterable, Sendable {
    case proMonthly = "com.freshli.pro.monthly"
    case proYearly = "com.freshli.pro.yearly"
    case familyMonthly = "com.freshli.pro.family"
}

// MARK: - SubscriptionStatus Enum

enum SubscriptionStatus: Equatable {
    case free
    case pro
    case family

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Freshli+"
        case .family: return "Freshli+ Family"
        }
    }
}

// MARK: - SubscriptionError Enum

enum SubscriptionError: LocalizedError, Equatable {
    case purchaseCancelled
    case purchasePending
    case storeUnavailable
    case verificationFailed
    case productNotFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:
            return "Your purchase was cancelled. Please try again."
        case .purchasePending:
            return "Your purchase is pending approval from the App Store."
        case .storeUnavailable:
            return "The App Store is temporarily unavailable. Please try again later."
        case .verificationFailed:
            return "We couldn't verify your purchase. Please contact support."
        case .productNotFound:
            return "The requested product is no longer available."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - SubscriptionTier Enum

enum SubscriptionTier: String, Codable {
    case free
    case pro
    case familyPro

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Freshli+"
        case .familyPro: return "Freshli+ Family"
        }
    }
}

// MARK: - SubscriptionFeature Enum

enum SubscriptionFeature: String, Codable, Hashable {
    case familySharing = "family_sharing"
    case unlimitedRescue = "unlimited_rescue"
    case advancedAnalytics = "advanced_analytics"
    case donationExport = "donation_export"
    case prioritySupport = "priority_support"

    var displayName: String {
        switch self {
        case .familySharing: return "Family Sharing"
        case .unlimitedRescue: return "Unlimited Rescue Listings"
        case .advancedAnalytics: return "Advanced Analytics"
        case .donationExport: return "Tax Report Export"
        case .prioritySupport: return "Priority Support"
        }
    }

    var description: String {
        switch self {
        case .familySharing: return "Share your pantry with family members and sync across devices"
        case .unlimitedRescue: return "Post unlimited rescue listings to share surplus food"
        case .advancedAnalytics: return "Track detailed consumption patterns and food waste"
        case .donationExport: return "Generate tax reports for food donations"
        case .prioritySupport: return "Get faster response times for support questions"
        }
    }
}

// MARK: - SubscriptionService

@Observable
@MainActor
final class SubscriptionService {
    private let userDefaultsKey = "freshli_subscription_tier"
    private let trialStartDateKey = "freshli_trial_start_date"
    private let expirationDateKey = "freshli_subscription_expiration"
    private let familyMemberCountKey = "freshli_family_member_count"
    private let purchasedProductIDsKey = "freshli_purchased_product_ids"

    private let logger = PSLogger(category: .general)

    var currentTier: SubscriptionTier = .free {
        didSet {
            saveSubscriptionState()
        }
    }

    var expirationDate: Date? {
        didSet {
            saveSubscriptionState()
        }
    }

    var familyMemberCount: Int = 0 {
        didSet {
            saveSubscriptionState()
        }
    }

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = [] {
        didSet {
            updateSubscriptionStatus()
            saveSubscriptionState()
        }
    }

    var isLoading: Bool = false
    var error: SubscriptionError?
    var subscriptionStatus: SubscriptionStatus = .free

    // @ObservationIgnored prevents @Observable from wrapping this in @MainActor-isolated
    // accessors. Without it, deinit (nonisolated) calling transactionUpdateTask?.cancel()
    // would go through the @MainActor synthesized getter → EXC_BREAKPOINT trap.
    @ObservationIgnored
    private var transactionUpdateTask: Task<Void, Never>?

    init() {
        loadSubscriptionState()
        Task {
            await setupTransactionListener()
        }
    }

    deinit {
        transactionUpdateTask?.cancel()
    }

    // MARK: - Computed Properties

    var isProUser: Bool {
        currentTier == .pro || currentTier == .familyPro
    }

    var isFamilyPro: Bool {
        currentTier == .familyPro
    }

    var isProSubscriber: Bool {
        subscriptionStatus == .pro || subscriptionStatus == .family
    }

    var trialDaysRemaining: Int {
        guard let expirationDate else { return 0 }
        let remainingSeconds = expirationDate.timeIntervalSince(Date())
        return max(0, Int(ceil(remainingSeconds / 86400)))
    }

    var isTrialExpired: Bool {
        guard let expirationDate else { return false }
        return Date() > expirationDate
    }

    var isInTrial: Bool {
        !isProUser && expirationDate != nil && !isTrialExpired
    }

    // MARK: - Feature Access

    func checkFeatureAccess(feature: SubscriptionFeature) -> Bool {
        if currentTier == .free {
            // Free tier has no pro features
            return false
        }
        return true
    }

    func requiresPro(_ feature: SubscriptionFeature) -> Bool {
        switch feature {
        case .familySharing:
            return true
        case .unlimitedRescue:
            return true
        case .advancedAnalytics:
            return true
        case .donationExport:
            return true
        case .prioritySupport:
            return true
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            let products = try await Product.products(for: SubscriptionProductID.allCases.map { $0.rawValue })
            self.products = products.sorted { productSortOrder($0) < productSortOrder($1) }
            logger.info("Loaded \(products.count) products from App Store")
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
            self.error = .storeUnavailable
        }

        isLoading = false
    }

    private func productSortOrder(_ product: Product) -> Int {
        switch product.id {
        case SubscriptionProductID.proMonthly.rawValue: return 0
        case SubscriptionProductID.proYearly.rawValue: return 1
        case SubscriptionProductID.familyMonthly.rawValue: return 2
        default: return 3
        }
    }

    // MARK: - Subscription Actions

    func purchase(_ product: Product) async {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updateEntitlements()
                await transaction.finish()
                logger.info("Purchase successful for product: \(product.id)")

            case .userCancelled:
                error = .purchaseCancelled
                logger.info("User cancelled purchase for product: \(product.id)")

            case .pending:
                error = .purchasePending
                logger.info("Purchase pending for product: \(product.id)")

            @unknown default:
                error = .storeUnavailable
                logger.error("Unknown purchase result for product: \(product.id)")
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
        }

        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()
            await updateEntitlements()
            logger.info("Purchases restored successfully")
        } catch {
            logger.error("Failed to restore purchases: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
        }

        isLoading = false
    }

    func checkEntitlements() async {
        await updateEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            logger.warning("Unverified transaction: \(error)")
            throw SubscriptionError.verificationFailed
        case .verified(let verified):
            return verified
        }
    }

    private func updateEntitlements() async {
        var productIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.revocationDate == nil {
                    productIDs.insert(transaction.productID)
                }
            } catch {
                logger.error("Failed to verify entitlement: \(error)")
            }
        }

        self.purchasedProductIDs = productIDs
    }

    private func updateSubscriptionStatus() {
        if purchasedProductIDs.contains(SubscriptionProductID.familyMonthly.rawValue) {
            subscriptionStatus = .family
            currentTier = .familyPro
        } else if purchasedProductIDs.contains(SubscriptionProductID.proMonthly.rawValue) ||
                  purchasedProductIDs.contains(SubscriptionProductID.proYearly.rawValue) {
            subscriptionStatus = .pro
            currentTier = .pro
        } else {
            subscriptionStatus = .free
            currentTier = .free
        }
    }

    // MARK: - Transaction Listening

    private func setupTransactionListener() async {
        transactionUpdateTask = Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await updateEntitlements()
                    await transaction.finish()
                    logger.info("Transaction update processed for product: \(transaction.productID)")
                } catch {
                    logger.error("Failed to process transaction update: \(error)")
                }
            }
        }

        // Initial entitlement check
        await updateEntitlements()
    }

    func cancelSubscription() {
        currentTier = .free
        expirationDate = nil
        familyMemberCount = 0
        purchasedProductIDs.removeAll()
        subscriptionStatus = .free
        // Note: Actual subscription cancellation must be done through App Store Connect or Settings.app
    }

    // MARK: - Persistence

    private func saveSubscriptionState() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: userDefaultsKey)
        UserDefaults.standard.set(expirationDate, forKey: expirationDateKey)
        UserDefaults.standard.set(familyMemberCount, forKey: familyMemberCountKey)

        let productIDArray = Array(purchasedProductIDs)
        UserDefaults.standard.set(productIDArray, forKey: purchasedProductIDsKey)
    }

    private func loadSubscriptionState() {
        if let tierRaw = UserDefaults.standard.string(forKey: userDefaultsKey),
           let tier = SubscriptionTier(rawValue: tierRaw) {
            currentTier = tier
        } else {
            currentTier = .free
        }

        expirationDate = UserDefaults.standard.object(forKey: expirationDateKey) as? Date
        familyMemberCount = UserDefaults.standard.integer(forKey: familyMemberCountKey)

        if let productIDArray = UserDefaults.standard.array(forKey: purchasedProductIDsKey) as? [String] {
            purchasedProductIDs = Set(productIDArray)
        }
    }
}

// MARK: - Pro Feature Gate View Modifier

struct ProFeatureGateModifier: ViewModifier {
    @Environment(SubscriptionService.self) var subscriptionService
    @State private var showUpgradeSheet = false

    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .disabled(!isEnabled && !subscriptionService.isProSubscriber)
            .opacity(!isEnabled && !subscriptionService.isProSubscriber ? 0.5 : 1.0)
            .overlay {
                if !isEnabled && !subscriptionService.isProSubscriber {
                    Button {
                        showUpgradeSheet = true
                    } label: {
                        VStack(spacing: FLSpacing.md) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(FLColors.primaryGreen)

                            Text("Freshli+ Feature")
                                .font(FLTypography.headline)
                                .foregroundStyle(FLColors.textPrimary)

                            Text("Upgrade to unlock this feature")
                                .font(FLTypography.caption1)
                                .foregroundStyle(FLColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(FLSpacing.lg)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.4))
                    }
                }
            }
            .sheet(isPresented: $showUpgradeSheet) {
                FreshliProView()
            }
    }
}

extension View {
    func proFeatureGate(isEnabled: Bool = true) -> some View {
        modifier(ProFeatureGateModifier(isEnabled: isEnabled))
    }
}
