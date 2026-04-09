import Foundation
import Supabase

/// Handles all Trust & Safety operations: reporting, reviews, badges, and reputation.
/// Uses structured payloads for Supabase storage.
@Observable
final class SafetyService: @unchecked Sendable {

    // MARK: - State

    var isLoading = false
    var error: String?

    private let client = AppSupabase.client

    // MARK: - Report User

    /// Submit a structured report against a user.
    func reportUser(
        reporterId: UUID,
        reportedUserId: UUID,
        listingId: UUID?,
        reason: ReportReason,
        details: String?,
        listingTitle: String?,
        listingStatus: String?,
        interactionType: String?,
        reporterVerified: Bool
    ) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let metadata = ReportContextMetadata(
            reporterVerified: reporterVerified,
            listingTitle: listingTitle,
            listingStatus: listingStatus,
            interactionType: interactionType,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            locale: Locale.current.identifier
        )

        let payload = UserReportPayload(
            id: UUID(),
            reporterId: reporterId,
            reportedUserId: reportedUserId,
            listingId: listingId,
            reason: reason.rawValue,
            details: details,
            contextMetadata: metadata,
            createdAt: Date(),
            status: "pending"
        )

        do {
            try await client
                .from("user_reports")
                .insert(payload)
                .execute()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Freshness Reviews

    /// Submit a freshness review after a successful pickup.
    func submitReview(_ input: CreateReviewInput) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let review = FreshnessReview(
            id: UUID(),
            reviewerId: input.reviewerId,
            revieweeId: input.revieweeId,
            listingId: input.listingId,
            freshnessRating: min(max(input.freshnessRating, 1), 5),
            comment: input.comment,
            createdAt: Date()
        )

        do {
            try await client
                .from("freshness_reviews")
                .insert(review)
                .execute()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Fetch reviews for a specific user.
    func fetchReviews(for userId: UUID) async -> [FreshnessReview] {
        do {
            let reviews: [FreshnessReview] = try await client
                .from("freshness_reviews")
                .select()
                .eq("reviewee_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return reviews
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    /// Compute an aggregate review summary for a user.
    func fetchReviewSummary(for userId: UUID) async -> ReviewSummary {
        let reviews = await fetchReviews(for: userId)
        guard !reviews.isEmpty else {
            return ReviewSummary(averageRating: 0, totalReviews: 0, ratingDistribution: [:])
        }

        let total = reviews.count
        let sum = reviews.reduce(0) { $0 + $1.clampedRating }
        var distribution: [Int: Int] = [:]
        for review in reviews {
            distribution[review.clampedRating, default: 0] += 1
        }

        return ReviewSummary(
            averageRating: Double(sum) / Double(total),
            totalReviews: total,
            ratingDistribution: distribution
        )
    }

    // MARK: - Hero Badges

    /// Fetch earned badges for a user.
    func fetchEarnedBadges(for userId: UUID) async -> [EarnedBadge] {
        do {
            let badges: [EarnedBadge] = try await client
                .from("earned_badges")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("earned_at", ascending: false)
                .execute()
                .value
            return badges
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    /// Award a badge to a user (idempotent — skips if already earned).
    func awardBadge(_ badge: HeroBadge, to userId: UUID) async -> Bool {
        let existing = await fetchEarnedBadges(for: userId)
        guard !existing.contains(where: { $0.badge == badge.rawValue }) else {
            return true // Already earned
        }

        let earned = EarnedBadge(
            id: UUID(),
            userId: userId,
            badge: badge.rawValue,
            earnedAt: Date()
        )

        do {
            try await client
                .from("earned_badges")
                .insert(earned)
                .execute()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    /// Check milestone badges based on share/donation counts and award any newly earned ones.
    func checkAndAwardMilestones(userId: UUID, totalShares: Int, totalDonations: Int) async {
        let total = totalShares + totalDonations

        let milestones: [(HeroBadge, Int)] = [
            (.firstShare, 1),
            (.tenMealDonor, 10),
            (.fiftyMealDonor, 50),
            (.hundredMealDonor, 100),
        ]

        for (badge, threshold) in milestones where total >= threshold {
            _ = await awardBadge(badge, to: userId)
        }
    }

    // MARK: - Reputation

    /// Build a full reputation profile for a user.
    func fetchReputation(for userId: UUID) async -> UserReputation {
        async let reviewSummary = fetchReviewSummary(for: userId)
        async let earnedBadges = fetchEarnedBadges(for: userId)

        let summary = await reviewSummary
        let badges = await earnedBadges

        // Fetch share/donation counts from listings
        var totalShares = 0
        var totalDonations = 0
        do {
            let listings: [SupabaseListing] = try await client
                .from("shared_listings")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("status", value: "completed")
                .execute()
                .value
            totalShares = listings.filter { $0.listingType == "share" }.count
            totalDonations = listings.filter { $0.listingType == "donate" }.count
        } catch {
            // Non-fatal; counts default to 0
        }

        let heroBadges = badges.compactMap { $0.heroBadge }

        return UserReputation(
            userId: userId,
            totalShares: totalShares,
            totalDonations: totalDonations,
            averageRating: summary.averageRating,
            totalReviews: summary.totalReviews,
            isVerified: false, // Caller should combine with IdentityVerificationService
            earnedBadges: heroBadges
        )
    }

    // MARK: - Safe Handoff Points

    /// Reveal the safe handoff point after a claim is approved.
    func fetchSafeHandoffPoint(for listingId: UUID) async -> SafeHandoffPoint? {
        do {
            let point: SafeHandoffPoint = try await client
                .from("safe_handoff_points")
                .select()
                .eq("listing_id", value: listingId.uuidString)
                .single()
                .execute()
                .value
            return point
        } catch {
            return nil
        }
    }

    /// Store a safe handoff point for a listing.
    func setSafeHandoffPoint(
        listingId: UUID,
        latitude: Double,
        longitude: Double,
        name: String?,
        notes: String?
    ) async -> Bool {
        struct HandoffInput: Encodable {
            let listingId: UUID
            let coordinate: CodableCoordinate
            let name: String?
            let notes: String?
        }

        let input = HandoffInput(
            listingId: listingId,
            coordinate: CodableCoordinate(latitude: latitude, longitude: longitude),
            name: name,
            notes: notes
        )

        do {
            try await client
                .from("safe_handoff_points")
                .upsert(input)
                .execute()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
