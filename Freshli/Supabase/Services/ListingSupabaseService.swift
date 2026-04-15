import Foundation
import Supabase
import os

private struct ListingReportUpdate: Encodable {
    let report_count: Int
    let is_flagged: Bool
    let updated_at: String
}

// MARK: - Listing Supabase Service
// Handles community marketplace listing operations including CRUD, claims, and location-based queries.

final class ListingSupabaseService: Sendable {
    nonisolated private let client = AppSupabase.client
    nonisolated private let logger = Logger(subsystem: "com.freshli.app", category: "ListingSupabaseService")

    nonisolated init() {}

    // MARK: - Fetch Operations

    /// Fetches all active listings in the community marketplace
    /// - Returns: Array of active SupabaseListing sorted by date posted
    /// - Throws: DatabaseError if the fetch fails
    func fetchActiveListings() async throws -> [SupabaseListing] {
        debugLog("ListingSupabaseService: Fetching active listings")

        let listings: [SupabaseListing] = try await client
            .from("shared_listings")
            .select()
            .eq("status", value: "active")
            .eq("is_flagged", value: false)
            .order("date_posted", ascending: false)
            .execute()
            .value

        debugLog("ListingSupabaseService: Fetched \(listings.count) active listings")
        return listings
    }

    /// Fetches all listings created by the current user
    /// - Parameter userId: User ID to fetch listings for
    /// - Returns: Array of SupabaseListing created by the user
    /// - Throws: DatabaseError if the fetch fails
    func fetchMyListings(userId: UUID) async throws -> [SupabaseListing] {
        debugLog("ListingSupabaseService: Fetching listings for user \(userId)")

        let listings: [SupabaseListing] = try await client
            .from("shared_listings")
            .select()
            .eq("user_id", value: userId)
            .order("date_posted", ascending: false)
            .execute()
            .value

        debugLog("ListingSupabaseService: Fetched \(listings.count) listings for user \(userId)")
        return listings
    }

    /// Fetches a single listing by ID
    /// - Parameter listingId: Listing ID to fetch
    /// - Returns: SupabaseListing if found
    /// - Throws: DatabaseError if not found
    func fetchListing(id listingId: UUID) async throws -> SupabaseListing {
        debugLog("ListingSupabaseService: Fetching listing \(listingId)")

        let listing: SupabaseListing = try await client
            .from("shared_listings")
            .select()
            .eq("id", value: listingId)
            .single()
            .execute()
            .value

        return listing
    }

    /// Fetches nearby listings based on geographic coordinates and radius
    /// - Parameters:
    ///   - latitude: User's latitude
    ///   - longitude: User's longitude
    ///   - radiusKm: Search radius in kilometers
    /// - Returns: Array of nearby SupabaseListing sorted by distance
    /// - Throws: DatabaseError if the fetch fails
    /// - Note: Uses PostGIS distance calculation; requires valid coordinates
    func fetchNearbyListings(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ) async throws -> [SupabaseListing] {
        debugLog("ListingSupabaseService: Fetching listings near (\(latitude), \(longitude)), radius: \(radiusKm)km")

        let listings: [SupabaseListing] = try await client
            .from("shared_listings")
            .select()
            .eq("status", value: "active")
            .eq("is_flagged", value: false)
            .gte("latitude", value: latitude - (radiusKm / 111.0))
            .lte("latitude", value: latitude + (radiusKm / 111.0))
            .gte("longitude", value: longitude - (radiusKm / 111.0))
            .lte("longitude", value: longitude + (radiusKm / 111.0))
            .order("date_posted", ascending: false)
            .execute()
            .value

        // Filter by actual distance (simplified approximation)
        let filtered = listings.filter { listing in
            guard let lat = listing.latitude, let lng = listing.longitude else { return false }
            let distance = calculateDistance(lat1: latitude, lon1: longitude, lat2: lat, lon2: lng)
            return distance <= radiusKm
        }

        debugLog("ListingSupabaseService: Found \(filtered.count) nearby listings")
        return filtered
    }

    /// Fetches listings by food category
    /// - Parameter category: Food category to filter by
    /// - Returns: Array of SupabaseListing in the specified category
    /// - Throws: DatabaseError if the fetch fails
    func fetchListings(by category: String) async throws -> [SupabaseListing] {
        debugLog("ListingSupabaseService: Fetching listings in category '\(category)'")

        let listings: [SupabaseListing] = try await client
            .from("shared_listings")
            .select()
            .eq("status", value: "active")
            .eq("food_category", value: category)
            .eq("is_flagged", value: false)
            .order("date_posted", ascending: false)
            .execute()
            .value

        return listings
    }

    /// Fetches pending or claimed listings
    /// - Parameter userId: User ID to fetch listings for
    /// - Returns: Array of SupabaseListing with status "claimed" or "pending"
    /// - Throws: DatabaseError if the fetch fails
    func fetchPendingListings(for userId: UUID) async throws -> [SupabaseListing] {
        debugLog("ListingSupabaseService: Fetching pending listings for user \(userId)")

        let listings: [SupabaseListing] = try await client
            .from("shared_listings")
            .select()
            .eq("user_id", value: userId)
            .in("status", values: ["pending", "claimed"])
            .order("updated_at", ascending: false)
            .execute()
            .value

        return listings
    }

    // MARK: - Create Operations

    /// Creates a new listing in the marketplace
    /// - Parameter listing: SupabaseListing to create
    /// - Returns: The created SupabaseListing with server-generated fields
    /// - Throws: DatabaseError if the insert fails
    func createListing(_ listing: SupabaseListing) async throws -> SupabaseListing {
        debugLog("ListingSupabaseService: Creating listing '\(listing.itemName)' for user \(listing.userId)")

        let response: SupabaseListing = try await client
            .from("shared_listings")
            .insert(listing)
            .select()
            .single()
            .execute()
            .value

        debugLog("ListingSupabaseService: Successfully created listing \(response.id)")
        return response
    }

    // MARK: - Update Operations

    /// Updates a listing's status (e.g., active, claimed, completed, cancelled)
    /// - Parameters:
    ///   - listingId: Listing ID to update
    ///   - status: New status value
    /// - Throws: DatabaseError if the update fails
    func updateListingStatus(id listingId: UUID, status: String) async throws {
        debugLog("ListingSupabaseService: Updating listing \(listingId) status to '\(status)'")

        try await client
            .from("shared_listings")
            .update(["status": status, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: listingId)
            .execute()

        debugLog("ListingSupabaseService: Successfully updated listing status")
    }

    /// Updates listing details
    /// - Parameter listing: SupabaseListing with updated values
    /// - Throws: DatabaseError if the update fails
    func updateListing(_ listing: SupabaseListing) async throws {
        debugLog("ListingSupabaseService: Updating listing \(listing.id)")

        try await client
            .from("shared_listings")
            .update(listing)
            .eq("id", value: listing.id)
            .execute()

        debugLog("ListingSupabaseService: Successfully updated listing \(listing.id)")
    }

    /// Marks a listing as completed
    /// - Parameter listingId: Listing ID to mark as completed
    /// - Throws: DatabaseError if the update fails
    func completeListing(id listingId: UUID) async throws {
        debugLog("ListingSupabaseService: Marking listing \(listingId) as completed")

        let now = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("shared_listings")
            .update(["status": "completed", "completed_at": now, "updated_at": now])
            .eq("id", value: listingId)
            .execute()

        debugLog("ListingSupabaseService: Successfully marked listing as completed")
    }

    /// Cancels a listing
    /// - Parameter listingId: Listing ID to cancel
    /// - Throws: DatabaseError if the update fails
    func cancelListing(id listingId: UUID) async throws {
        debugLog("ListingSupabaseService: Cancelling listing \(listingId)")

        try await client
            .from("shared_listings")
            .update(["status": "cancelled", "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: listingId)
            .execute()

        debugLog("ListingSupabaseService: Successfully cancelled listing")
    }

    /// Flags a listing as inappropriate
    /// - Parameter listingId: Listing ID to flag
    /// - Throws: DatabaseError if the update fails
    func flagListing(id listingId: UUID) async throws {
        debugLog("ListingSupabaseService: Flagging listing \(listingId)")

        let currentListing = try await fetchListing(id: listingId)
        let newReportCount = (currentListing.reportCount ?? 0) + 1

        try await client
            .from("shared_listings")
            .update(ListingReportUpdate(
                report_count: newReportCount,
                is_flagged: newReportCount >= 3,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: listingId)
            .execute()

        debugLog("ListingSupabaseService: Successfully flagged listing")
    }

    // MARK: - Claim Operations

    /// Creates a claim for a listing
    /// - Parameters:
    ///   - listingId: Listing ID to claim
    ///   - claimerId: User ID making the claim
    /// - Returns: The created SupabaseClaim
    /// - Throws: DatabaseError if the insert fails
    func claimListing(listingId: UUID, claimerId: UUID) async throws -> SupabaseClaim {
        debugLog("ListingSupabaseService: Creating claim for listing \(listingId) by user \(claimerId)")

        let claim = SupabaseClaim(
            id: UUID(),
            listingId: listingId,
            claimerId: claimerId,
            status: "pending",
            updatedAt: Date()
        )

        let response: SupabaseClaim = try await client
            .from("claims")
            .insert(claim)
            .select()
            .single()
            .execute()
            .value

        debugLog("ListingSupabaseService: Successfully created claim \(response.id)")
        return response
    }

    /// Fetches all claims for a specific listing
    /// - Parameter listingId: Listing ID to fetch claims for
    /// - Returns: Array of SupabaseClaim
    /// - Throws: DatabaseError if the fetch fails
    func fetchClaimsForListing(listingId: UUID) async throws -> [SupabaseClaim] {
        debugLog("ListingSupabaseService: Fetching claims for listing \(listingId)")

        let claims: [SupabaseClaim] = try await client
            .from("claims")
            .select()
            .eq("listing_id", value: listingId)
            .order("updated_at", ascending: false)
            .execute()
            .value

        debugLog("ListingSupabaseService: Fetched \(claims.count) claims")
        return claims
    }

    /// Fetches claims made by a specific user
    /// - Parameter claimerId: User ID to fetch claims for
    /// - Returns: Array of SupabaseClaim made by the user
    /// - Throws: DatabaseError if the fetch fails
    func fetchUserClaims(claimerId: UUID) async throws -> [SupabaseClaim] {
        debugLog("ListingSupabaseService: Fetching claims for user \(claimerId)")

        let claims: [SupabaseClaim] = try await client
            .from("claims")
            .select()
            .eq("claimer_id", value: claimerId)
            .order("updated_at", ascending: false)
            .execute()
            .value

        return claims
    }

    /// Updates a claim's status
    /// - Parameters:
    ///   - claimId: Claim ID to update
    ///   - status: New status value (e.g., "accepted", "rejected", "completed")
    /// - Throws: DatabaseError if the update fails
    func updateClaimStatus(claimId: UUID, status: String) async throws {
        debugLog("ListingSupabaseService: Updating claim \(claimId) status to '\(status)'")

        try await client
            .from("claims")
            .update(["status": status, "updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: claimId)
            .execute()

        debugLog("ListingSupabaseService: Successfully updated claim status")
    }

    // MARK: - Helper Functions

    /// Calculates distance between two geographic points using Haversine formula
    /// - Parameters:
    ///   - lat1: First latitude
    ///   - lon1: First longitude
    ///   - lat2: Second latitude
    ///   - lon2: Second longitude
    /// - Returns: Distance in kilometers
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadiusKm = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }

    // MARK: - Helper Enums

    enum DatabaseError: LocalizedError {
        case fetchFailed(String)
        case insertFailed(String)
        case updateFailed(String)
        case deleteFailed(String)
        case listingNotFound
        case claimNotFound
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let message):
                return "Failed to fetch listings: \(message)"
            case .insertFailed(let message):
                return "Failed to create listing: \(message)"
            case .updateFailed(let message):
                return "Failed to update listing: \(message)"
            case .deleteFailed(let message):
                return "Failed to delete listing: \(message)"
            case .listingNotFound:
                return "Listing not found"
            case .claimNotFound:
                return "Claim not found"
            case .accessDenied:
                return "Access denied to this listing"
            }
        }
    }
}
