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
@Observable
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

    /// Load all active listings
    func loadListings() async {
        isLoading = true
        errorMessage = nil

        do {
            listings = try await listingService.fetchActiveListings()
            debugLog("Loaded \(self.listings.count) active listings")
        } catch {
            errorMessage = "Failed to load listings: \(error.localizedDescription)"
            logger.error("Error loading listings: \(error)")
        }

        isLoading = false
    }

    /// Load nearby listings based on user location
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
