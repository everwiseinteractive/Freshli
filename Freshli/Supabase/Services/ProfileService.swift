import Foundation
import Supabase
import os

// MARK: - Profile Service
// Handles all profile-related Supabase operations including CRUD and impact stats.

@Observable
final class ProfileService: Sendable {
    private let client = AppSupabase.client
    private let logger = Logger(subsystem: "com.freshli.app", category: "ProfileService")

    // MARK: - Fetch Operations

    /// Fetches the current user's profile from Supabase
    /// - Returns: SupabaseProfile for the authenticated user
    /// - Throws: DatabaseError if the fetch fails
    func fetchProfile(userId: UUID) async throws -> SupabaseProfile {
        debugLog("ProfileService: Fetching profile for user \(userId)")

        let profile: SupabaseProfile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value

        debugLog("ProfileService: Successfully fetched profile for \(userId)")
        return profile
    }

    // MARK: - Update Operations

    /// Updates a user's profile in Supabase
    /// - Parameter profile: The SupabaseProfile to update
    /// - Throws: DatabaseError if the update fails
    func updateProfile(_ profile: SupabaseProfile) async throws {
        debugLog("ProfileService: Updating profile for user \(profile.id)")

        try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id)
            .execute()

        debugLog("ProfileService: Successfully updated profile for \(profile.id)")
    }

    /// Updates display name only (lightweight operation)
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - displayName: New display name
    /// - Throws: DatabaseError if the update fails
    func updateDisplayName(_ displayName: String, for userId: UUID) async throws {
        debugLog("ProfileService: Updating display name for user \(userId)")

        try await client
            .from("profiles")
            .update(["display_name": displayName])
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully updated display name for \(userId)")
    }

    /// Updates avatar URL
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - avatarUrl: New avatar URL
    /// - Throws: DatabaseError if the update fails
    func updateAvatarUrl(_ avatarUrl: String, for userId: UUID) async throws {
        debugLog("ProfileService: Updating avatar URL for user \(userId)")

        try await client
            .from("profiles")
            .update(["avatar_url": avatarUrl])
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully updated avatar URL for \(userId)")
    }

    /// Updates notification preferences
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - enabled: Whether notifications are enabled
    ///   - expiryReminderDays: Days before expiry to send reminder
    /// - Throws: DatabaseError if the update fails
    func updateNotificationPreferences(
        for userId: UUID,
        enabled: Bool,
        expiryReminderDays: Int?
    ) async throws {
        debugLog("ProfileService: Updating notification preferences for user \(userId)")

        var updates: [String: AnyJSON] = [
            "notifications_enabled": .bool(enabled)
        ]

        if let days = expiryReminderDays {
            updates["expiry_reminder_days"] = .double(Double(days))
        }

        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully updated notification preferences for \(userId)")
    }

    /// Updates household size
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - householdSize: Number of people in household
    /// - Throws: DatabaseError if the update fails
    func updateHouseholdSize(_ householdSize: Int, for userId: UUID) async throws {
        debugLog("ProfileService: Updating household size for user \(userId)")

        try await client
            .from("profiles")
            .update(["household_size": householdSize])
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully updated household size for \(userId)")
    }

    // MARK: - Impact Stats Updates

    /// Updates the user's impact statistics (money saved, CO2 avoided, meals shared)
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - moneySaved: Total money saved (adds to existing)
    ///   - co2Avoided: Total CO2 avoided in kg (adds to existing)
    ///   - mealsShared: Number of meals shared (adds to existing)
    /// - Throws: DatabaseError if the update fails
    func updateImpactStats(
        for userId: UUID,
        moneySaved: Double? = nil,
        co2Avoided: Double? = nil,
        mealsShared: Int? = nil
    ) async throws {
        debugLog("ProfileService: Updating impact stats for user \(userId)")

        // Fetch current profile to get existing values
        let currentProfile = try await fetchProfile(userId: userId)

        // Calculate new values
        let newMoneySaved = (currentProfile.totalMoneySaved ?? 0) + (moneySaved ?? 0)
        let newCo2Avoided = (currentProfile.totalCo2Avoided ?? 0) + (co2Avoided ?? 0)
        let newMealsShared = (currentProfile.mealsShared ?? 0) + (mealsShared ?? 0)

        var updates: [String: AnyJSON] = [:]

        if let moneySaved {
            updates["total_money_saved"] = .double(newMoneySaved)
        }

        if let co2Avoided {
            updates["total_co2_avoided"] = .double(newCo2Avoided)
        }

        if let mealsShared {
            updates["meals_shared"] = .double(Double(newMealsShared))
        }

        guard !updates.isEmpty else { return }

        try await client
            .from("profiles")
            .update(updates)
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully updated impact stats for \(userId)")
    }

    /// Increments the streak count for a user
    /// - Parameters:
    ///   - userId: User ID to update
    ///   - increment: Amount to increment by (default 1)
    /// - Throws: DatabaseError if the update fails
    func incrementStreakCount(for userId: UUID, by increment: Int = 1) async throws {
        debugLog("ProfileService: Incrementing streak count for user \(userId)")

        let currentProfile = try await fetchProfile(userId: userId)
        let newStreakCount = (currentProfile.streakCount ?? 0) + increment

        try await client
            .from("profiles")
            .update(["streak_count": newStreakCount])
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully incremented streak count for \(userId)")
    }

    /// Updates the last active date to now
    /// - Parameter userId: User ID to update
    /// - Throws: DatabaseError if the update fails
    func updateLastActiveDate(for userId: UUID) async throws {
        debugLog("ProfileService: Updating last active date for user \(userId)")

        let now = Date()
        try await client
            .from("profiles")
            .update(["last_active_date": ISO8601DateFormatter().string(from: now)])
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully updated last active date for \(userId)")
    }

    /// Marks onboarding as completed
    /// - Parameter userId: User ID to update
    /// - Throws: DatabaseError if the update fails
    func completeOnboarding(for userId: UUID) async throws {
        debugLog("ProfileService: Marking onboarding complete for user \(userId)")

        try await client
            .from("profiles")
            .update(["onboarding_completed": true])
            .eq("id", value: userId)
            .execute()

        debugLog("ProfileService: Successfully marked onboarding complete for \(userId)")
    }

    // MARK: - Helper Enums

    enum DatabaseError: LocalizedError {
        case fetchFailed(String)
        case updateFailed(String)
        case profileNotFound
        case invalidData

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch profile: \(message)"
            case .updateFailed(let message):
                return "Failed to update profile: \(message)"
            case .profileNotFound:
                return "Profile not found"
            case .invalidData:
                return "Invalid profile data"
            }
        }
    }
}
