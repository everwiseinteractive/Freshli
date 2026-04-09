import Foundation
import Observation

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
final class SubscriptionService {
    private let userDefaultsKey = "freshli_subscription_tier"
    private let trialStartDateKey = "freshli_trial_start_date"
    private let expirationDateKey = "freshli_subscription_expiration"
    private let familyMemberCountKey = "freshli_family_member_count"

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

    init() {
        loadSubscriptionState()
    }

    // MARK: - Computed Properties

    var isProUser: Bool {
        currentTier == .pro || currentTier == .familyPro
    }

    var isFamilyPro: Bool {
        currentTier == .familyPro
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

    // MARK: - Subscription Actions

    func startProTrial(duration: Int = 7) {
        // Calculate trial expiration date
        let trialExpirationDate = Calendar.current.date(byAdding: .day, value: duration, to: Date())
        expirationDate = trialExpirationDate

        // Keep tier as free during trial so user sees "Start Trial" option
        currentTier = .free

        // TODO: StoreKit2 Integration
        // In production, this would call SKPaymentQueue to start the trial:
        // let product = try await Product.products(for: ["com.freshli.pro.trial"])
        // try await product.first?.purchase()
    }

    func upgradeToPro(tier: SubscriptionTier = .pro, duration: Int? = nil) {
        currentTier = tier

        // If duration is provided, set expiration (for trial or subscription)
        if let duration {
            expirationDate = Calendar.current.date(byAdding: .month, value: duration, to: Date())
        }

        // TODO: StoreKit2 Integration
        // let productId = tier == .familyPro ? "com.freshli.pro.family" : "com.freshli.pro"
        // try await Product.products(for: [productId]).first?.purchase()
    }

    func restorePurchases() {
        // TODO: StoreKit2 Integration
        // In production, this would restore previous purchases:
        // for await result in Transaction.currentEntitlements {
        //     handleTransaction(result)
        // }
        // For now, this is a stub that would be called to restore from receipt
    }

    func cancelSubscription() {
        currentTier = .free
        expirationDate = nil
        familyMemberCount = 0
        // TODO: StoreKit2 - Manage subscription cancellation with App Store
    }

    // MARK: - Persistence

    private func saveSubscriptionState() {
        UserDefaults.standard.set(currentTier.rawValue, forKey: userDefaultsKey)
        UserDefaults.standard.set(expirationDate, forKey: expirationDateKey)
        UserDefaults.standard.set(familyMemberCount, forKey: familyMemberCountKey)
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
    }
}
