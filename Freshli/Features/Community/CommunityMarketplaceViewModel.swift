import Foundation
import MapKit
import Observation
import os

// MARK: - Map Annotation Item
struct MapAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let listing: SupabaseListing
}

// MARK: - View Mode Enum
enum CommunityMarketplaceViewMode {
    case list
    case map
}

// MARK: - Community Marketplace ViewModel
@Observable @MainActor
final class CommunityMarketplaceViewModel {
    private let listingService = ListingSupabaseService()
    private let logger = Logger(subsystem: "com.freshli.app", category: "CommunityMarketplaceViewModel")

    // MARK: - Published State
    var listings: [SupabaseListing] = []
    var viewMode: CommunityMarketplaceViewMode = .list
    var selectedCategory: FoodCategory?
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Location State
    var userLatitude: Double?
    var userLongitude: Double?

    // MARK: - User Interaction State
    var blockedUsers: Set<UUID> = []
    var claimedListingIds: Set<UUID> = []

    // MARK: - Initialization
    init() {
        debugLog("CommunityMarketplaceViewModel initialized")
    }

    // MARK: - Computed Properties

    /// Filtered listings excluding blocked users and applying category/search filters
    var filteredListings: [SupabaseListing] {
        var result = listings.filter { !blockedUsers.contains($0.userId) }

        if let category = selectedCategory {
            result = result.filter { $0.foodCategory == category.rawValue }
        }

        if !searchText.isEmpty {
            result = result.filter { listing in
                listing.itemName.localizedCaseInsensitiveContains(searchText) ||
                (listing.itemDescription ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { ($0.datePosted ?? Date()) > ($1.datePosted ?? Date()) }
    }

    /// Recent listings near the user (first 10)
    var recentNearYou: [SupabaseListing] {
        guard let userLat = userLatitude, let userLng = userLongitude else {
            return Array(filteredListings.prefix(10))
        }

        let nearby = filteredListings.filter { listing in
            guard let lat = listing.latitude, let lng = listing.longitude else { return false }
            let distance = calculateDistance(lat1: userLat, lon1: userLng, lat2: lat, lon2: lng)
            return distance <= 5.0 // 5 km radius
        }

        return Array(nearby.prefix(10))
    }

    /// Map annotations from listings with valid coordinates
    var annotations: [MapAnnotationItem] {
        filteredListings.compactMap { listing in
            guard let lat = listing.latitude, let lng = listing.longitude else { return nil }

            // Blur location: offset by random ±0.002 for privacy
            let blurredLat = lat + Double.random(in: -0.002...0.002)
            let blurredLng = lng + Double.random(in: -0.002...0.002)
            let coordinate = CLLocationCoordinate2D(latitude: blurredLat, longitude: blurredLng)

            return MapAnnotationItem(id: listing.id, coordinate: coordinate, listing: listing)
        }
    }

    // MARK: - Data Loading

    /// Load listings, preferring nearby results based on the user's current
    /// location. Falls back to the global active feed in three honest cases:
    ///
    ///   1. The user denied Location permission — Community works fine
    ///      without a location, just without the "nearby" sort.
    ///   2. We can't get a location fix in a reasonable time (e.g. indoors,
    ///      no GPS) — show all listings rather than block the screen.
    ///   3. The nearby query returns zero results — show the global feed
    ///      so the user can still discover listings outside their radius.
    ///
    /// Replaces the prior unconditional `fetchActiveListings` path so users
    /// who DID grant Location permission actually get the nearby experience
    /// they were promised in the onboarding rationale.
    func loadListings() async {
        isLoading = true
        errorMessage = nil

        // Try to get a fresh user location. We bound the wait so a slow GPS
        // fix doesn't block the screen — anything ≤ 1.5s feels instant.
        let userLocation = await tryLocateUser()

        do {
            if let coord = userLocation {
                userLatitude = coord.latitude
                userLongitude = coord.longitude
                let nearby = try await listingService.fetchNearbyListings(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    radiusKm: 15.0
                )
                if !nearby.isEmpty {
                    listings = nearby
                    debugLog("Loaded \(nearby.count) nearby listings within 15 km")
                    isLoading = false
                    return
                }
                // Empty nearby radius — fall through to the global feed
                // so the user sees something instead of an empty-state.
                debugLog("Nearby query returned 0 results, falling back to global feed")
            }

            // No location, or empty nearby radius — show the global feed.
            listings = try await listingService.fetchActiveListings()
            debugLog("Loaded \(self.listings.count) active listings (global feed)")
        } catch {
            errorMessage = "Failed to load listings: \(error.localizedDescription)"
            logger.error("Error loading listings: \(error)")
        }

        isLoading = false
    }

    /// Explicit entry point for callers that already have a known coordinate
    /// (e.g. tapping a map pin to refresh that area). Most callers should
    /// use `loadListings()` instead, which auto-resolves the user location.
    func loadNearbyListings(latitude: Double, longitude: Double) async {
        userLatitude = latitude
        userLongitude = longitude
        isLoading = true
        errorMessage = nil

        do {
            let nearby = try await listingService.fetchNearbyListings(
                latitude: latitude,
                longitude: longitude,
                radiusKm: 15.0
            )
            listings = nearby
            debugLog("Loaded \(nearby.count) nearby listings")
        } catch {
            errorMessage = "Failed to load nearby listings: \(error.localizedDescription)"
            logger.error("Error loading nearby listings: \(error)")
        }

        isLoading = false
    }

    /// Returns the freshest available user coordinate, or `nil` if the user
    /// hasn't granted Location permission, the device can't get a fix, or
    /// the request times out. Never throws — Community must work without
    /// Location too.
    @MainActor
    private func tryLocateUser() async -> CLLocationCoordinate2D? {
        // Fast path: a recent in-memory fix from LocationService.
        if let coord = LocationService.shared.bestAvailableCoordinate() {
            return coord
        }
        // Bounded async fix request (1.5s).
        do {
            let task = Task { try await LocationService.shared.requestLocation() }
            let timeout = Task {
                try await Task.sleep(for: .milliseconds(1500))
                task.cancel()
            }
            let location = try await task.value
            timeout.cancel()
            return location.coordinate
        } catch {
            return nil
        }
    }

    // MARK: - Claim Flow

    /// Claim a listing
    func claimListing(_ listing: SupabaseListing, claimerId: UUID) async throws {
        do {
            _ = try await listingService.claimListing(listingId: listing.id, claimerId: claimerId)
            claimedListingIds.insert(listing.id)

            // Update local listing status
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                listings[index].status = "claimed"
                listings[index].claimedBy = claimerId
            }

            debugLog("Successfully claimed listing \(listing.id)")
        } catch {
            logger.error("Error claiming listing: \(error)")
            throw error
        }
    }

    // MARK: - Report & Block Flow

    /// Report a listing as inappropriate
    func reportListing(_ listing: SupabaseListing) async throws {
        do {
            try await listingService.flagListing(id: listing.id)

            // Update local state
            if let index = listings.firstIndex(where: { $0.id == listing.id }) {
                listings[index].reportCount = (listings[index].reportCount ?? 0) + 1
            }

            debugLog("Successfully reported listing \(listing.id)")
        } catch {
            logger.error("Error reporting listing: \(error)")
            throw error
        }
    }

    /// Block a user from their listings
    func blockUser(_ userId: UUID) {
        blockedUsers.insert(userId)
        debugLog("Blocked user \(userId)")
    }

    /// Unblock a user
    func unblockUser(_ userId: UUID) {
        blockedUsers.remove(userId)
        debugLog("Unblocked user \(userId)")
    }

    // MARK: - Helper Methods

    /// Calculate distance between two coordinates using Haversine formula
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371.0 // Earth's radius in kilometers
        let lat1Rad = lat1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0
        let deltaLat = (lat2 - lat1) * .pi / 180.0
        let deltaLon = (lon2 - lon1) * .pi / 180.0

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return R * c
    }

    private func debugLog(_ message: String) {
        logger.debug("\(message)")
    }
}
