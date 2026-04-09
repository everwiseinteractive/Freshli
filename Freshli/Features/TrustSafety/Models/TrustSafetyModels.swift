import Foundation
import CoreLocation

// MARK: - Identity Verification

enum VerificationStatus: String, Codable, Sendable {
    case unverified
    case verified
    case expired

    var displayName: String {
        switch self {
        case .unverified: String(localized: "Unverified")
        case .verified: String(localized: "Verified")
        case .expired: String(localized: "Expired")
        }
    }

    var icon: String {
        switch self {
        case .unverified: "person.crop.circle.badge.questionmark"
        case .verified: "person.crop.circle.badge.checkmark"
        case .expired: "person.crop.circle.badge.exclamationmark"
        }
    }
}

struct IdentityVerification: Codable, Sendable {
    let userId: UUID
    let verifiedAt: Date
    let method: String // "faceID" or "touchID"
    let expiresAt: Date

    var isValid: Bool {
        Date() < expiresAt
    }

    var status: VerificationStatus {
        isValid ? .verified : .expired
    }
}

// MARK: - Reports

enum ReportReason: String, Codable, CaseIterable, Sendable, Identifiable {
    case spam = "spam"
    case inappropriateContent = "inappropriate_content"
    case unsafeBehavior = "unsafe_behavior"
    case noShow = "no_show"
    case falseListing = "false_listing"
    case harassment = "harassment"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spam: String(localized: "Spam or Scam")
        case .inappropriateContent: String(localized: "Inappropriate Content")
        case .unsafeBehavior: String(localized: "Unsafe Behavior")
        case .noShow: String(localized: "No-Show at Pickup")
        case .falseListing: String(localized: "False or Misleading Listing")
        case .harassment: String(localized: "Harassment")
        case .other: String(localized: "Other")
        }
    }

    var icon: String {
        switch self {
        case .spam: "exclamationmark.triangle"
        case .inappropriateContent: "eye.slash"
        case .unsafeBehavior: "shield.slash"
        case .noShow: "figure.walk.departure"
        case .falseListing: "doc.questionmark"
        case .harassment: "hand.raised.slash"
        case .other: "ellipsis.circle"
        }
    }
}

/// Structured report payload for Supabase storage
struct UserReportPayload: Codable, Sendable {
    let id: UUID
    let reporterId: UUID
    let reportedUserId: UUID
    let listingId: UUID?
    let reason: String
    let details: String?
    let contextMetadata: ReportContextMetadata
    let createdAt: Date
    let status: String // "pending", "reviewed", "resolved", "dismissed"
}

struct ReportContextMetadata: Codable, Sendable {
    let reporterVerified: Bool
    let listingTitle: String?
    let listingStatus: String?
    let interactionType: String? // "claim", "pickup", "message"
    let appVersion: String
    let locale: String
}

// MARK: - Reviews / Freshness Stars

struct FreshnessReview: Codable, Identifiable, Sendable {
    let id: UUID
    let reviewerId: UUID
    let revieweeId: UUID
    let listingId: UUID
    let freshnessRating: Int // 1-5 stars
    let comment: String?
    let createdAt: Date

    var clampedRating: Int {
        min(max(freshnessRating, 1), 5)
    }
}

struct CreateReviewInput: Codable, Sendable {
    let reviewerId: UUID
    let revieweeId: UUID
    let listingId: UUID
    let freshnessRating: Int
    let comment: String?
}

struct ReviewSummary: Sendable {
    let averageRating: Double
    let totalReviews: Int
    let ratingDistribution: [Int: Int] // star -> count
}

// MARK: - Hero Badges

enum HeroBadge: String, Codable, CaseIterable, Sendable, Identifiable {
    case firstShare = "first_share"
    case tenMealDonor = "ten_meal_donor"
    case fiftyMealDonor = "fifty_meal_donor"
    case hundredMealDonor = "hundred_meal_donor"
    case communityChampion = "community_champion"
    case zeroWasteHero = "zero_waste_hero"
    case neighborhoodStar = "neighborhood_star"
    case trustedMember = "trusted_member"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstShare: String(localized: "First Share")
        case .tenMealDonor: String(localized: "10-Meal Donor")
        case .fiftyMealDonor: String(localized: "50-Meal Donor")
        case .hundredMealDonor: String(localized: "100-Meal Donor")
        case .communityChampion: String(localized: "Community Champion")
        case .zeroWasteHero: String(localized: "Zero Waste Hero")
        case .neighborhoodStar: String(localized: "Neighborhood Star")
        case .trustedMember: String(localized: "Trusted Member")
        }
    }

    var subtitle: String {
        switch self {
        case .firstShare: String(localized: "Shared your first item")
        case .tenMealDonor: String(localized: "Donated 10 meals to neighbors")
        case .fiftyMealDonor: String(localized: "Donated 50 meals to neighbors")
        case .hundredMealDonor: String(localized: "Donated 100 meals to neighbors")
        case .communityChampion: String(localized: "Top contributor this month")
        case .zeroWasteHero: String(localized: "Rescued 25+ items from waste")
        case .neighborhoodStar: String(localized: "Highest rated in your area")
        case .trustedMember: String(localized: "Identity verified, 4.5+ rating")
        }
    }

    var sfSymbol: String {
        switch self {
        case .firstShare: "heart.circle.fill"
        case .tenMealDonor: "fork.knife.circle.fill"
        case .fiftyMealDonor: "star.circle.fill"
        case .hundredMealDonor: "crown.fill"
        case .communityChampion: "trophy.circle.fill"
        case .zeroWasteHero: "leaf.circle.fill"
        case .neighborhoodStar: "sparkles"
        case .trustedMember: "checkmark.shield.fill"
        }
    }

    var color: (primary: String, secondary: String) {
        switch self {
        case .firstShare: ("22C55E", "4ADE80")
        case .tenMealDonor: ("3B82F6", "60A5FA")
        case .fiftyMealDonor: ("8B5CF6", "A78BFA")
        case .hundredMealDonor: ("F59E0B", "FCD34D")
        case .communityChampion: ("EF4444", "F87171")
        case .zeroWasteHero: ("10B981", "34D399")
        case .neighborhoodStar: ("EC4899", "F472B6")
        case .trustedMember: ("22C55E", "4ADE80")
        }
    }

    /// Minimum donation/share count to earn this badge
    var threshold: Int {
        switch self {
        case .firstShare: 1
        case .tenMealDonor: 10
        case .fiftyMealDonor: 50
        case .hundredMealDonor: 100
        case .communityChampion: 20
        case .zeroWasteHero: 25
        case .neighborhoodStar: 15
        case .trustedMember: 5
        }
    }

    /// Variable fill value (0.0 - 1.0) based on reputation score
    func variableFill(for reputationScore: Double) -> Double {
        min(max(reputationScore / 100.0, 0.0), 1.0)
    }
}

struct EarnedBadge: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let badge: String // HeroBadge.rawValue
    let earnedAt: Date

    var heroBadge: HeroBadge? {
        HeroBadge(rawValue: badge)
    }
}

// MARK: - Fuzzy Location

struct FuzzyLocation: Sendable {
    let center: CLLocationCoordinate2D
    let radiusMeters: Double // Always 100m for public display

    static let defaultRadius: Double = 100

    /// Offset the true location randomly within the radius for privacy
    static func fuzzy(from coordinate: CLLocationCoordinate2D) -> FuzzyLocation {
        let angle = Double.random(in: 0...(2 * .pi))
        let distance = Double.random(in: 20...80) // 20-80m offset
        let latOffset = (distance / 111_320) * cos(angle)
        let lonOffset = (distance / (111_320 * cos(coordinate.latitude * .pi / 180))) * sin(angle)

        return FuzzyLocation(
            center: CLLocationCoordinate2D(
                latitude: coordinate.latitude + latOffset,
                longitude: coordinate.longitude + lonOffset
            ),
            radiusMeters: defaultRadius
        )
    }
}

struct SafeHandoffPoint: Codable, Sendable {
    let coordinate: CodableCoordinate
    let name: String?
    let notes: String?
}

struct CodableCoordinate: Codable, Sendable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Reputation

struct UserReputation: Sendable {
    let userId: UUID
    let totalShares: Int
    let totalDonations: Int
    let averageRating: Double
    let totalReviews: Int
    let isVerified: Bool
    let earnedBadges: [HeroBadge]

    var reputationScore: Double {
        let shareScore = Double(totalShares) * 2.0
        let donationScore = Double(totalDonations) * 3.0
        let ratingScore = averageRating * 10.0
        let verificationBonus = isVerified ? 15.0 : 0.0
        let badgeBonus = Double(earnedBadges.count) * 5.0
        return min(shareScore + donationScore + ratingScore + verificationBonus + badgeBonus, 100.0)
    }

    var tier: ReputationTier {
        switch reputationScore {
        case 0..<20: .newcomer
        case 20..<40: .contributor
        case 40..<60: .trusted
        case 60..<80: .champion
        default: .legend
        }
    }
}

enum ReputationTier: String, Sendable {
    case newcomer, contributor, trusted, champion, legend

    var displayName: String {
        switch self {
        case .newcomer: String(localized: "Newcomer")
        case .contributor: String(localized: "Contributor")
        case .trusted: String(localized: "Trusted")
        case .champion: String(localized: "Champion")
        case .legend: String(localized: "Legend")
        }
    }

    var color: String {
        switch self {
        case .newcomer: "9CA3AF"
        case .contributor: "3B82F6"
        case .trusted: "22C55E"
        case .champion: "8B5CF6"
        case .legend: "F59E0B"
        }
    }
}
