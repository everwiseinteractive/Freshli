import Foundation
import Supabase

// MARK: - CommunityService
// Dedicated service for all Community tab Supabase operations.
// Handles listing CRUD, claiming, status management, reporting, and feed queries.

@Observable
final class CommunityService {
    var isLoading = false
    var listings: [CommunityListingDTO] = []
    var myListings: [CommunityListingDTO] = []
    var error: String?

    private let client = AppSupabase.client

    // MARK: - Fetch Community Feed

    /// Fetch active listings for the community feed.
    func fetchFeed(searchQuery: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            // Apply filters first (on PostgrestFilterBuilder), then transforms
            var filterQuery = client
                .from("shared_listings")
                .select("*, profiles!shared_listings_user_id_fkey(display_name, avatar_url)")
                .eq("status", value: "active")
                .eq("is_flagged", value: false)

            if let search = searchQuery, !search.isEmpty {
                filterQuery = filterQuery.ilike("item_name", pattern: "%\(search)%")
            }

            let results: [CommunityListingDTO] = try await filterQuery
                .order("date_posted", ascending: false)
                .limit(50)
                .execute()
                .value
            listings = results
        } catch {
            self.error = "Could not load community feed."
            print("[CommunityService] fetchFeed failed: \(error)")
        }
    }

    // MARK: - Fetch My Listings

    func fetchMyListings(userId: UUID) async {
        do {
            let results: [CommunityListingDTO] = try await client
                .from("shared_listings")
                .select("*, profiles!shared_listings_user_id_fkey(display_name, avatar_url)")
                .eq("user_id", value: userId.uuidString)
                .order("date_posted", ascending: false)
                .limit(50)
                .execute()
                .value
            myListings = results
        } catch {
            print("[CommunityService] fetchMyListings failed: \(error)")
        }
    }

    // MARK: - Create Listing

    func createListing(_ input: CreateListingInput, userId: UUID) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        let payload: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "item_name": .string(input.itemName),
            "item_description": input.description.map { .string($0) } ?? .null,
            "quantity": .integer(input.quantity),
            "listing_type": .string(input.listingType),
            "status": .string("active"),
            "pickup_address": input.pickupAddress.map { .string($0) } ?? .null,
            "pickup_notes": input.pickupNotes.map { .string($0) } ?? .null,
            "food_category": .string(input.foodCategory),
            "area_name": input.areaName.map { .string($0) } ?? .null,
        ]

        do {
            try await client
                .from("shared_listings")
                .insert(payload)
                .execute()
            return true
        } catch {
            self.error = "Could not create listing."
            print("[CommunityService] createListing failed: \(error)")
            return false
        }
    }

    // MARK: - Claim Listing

    func claimListing(listingId: UUID, claimerId: UUID) async -> Bool {
        do {
            try await client
                .from("shared_listings")
                .update([
                    "status": "claimed",
                    "claimed_by": claimerId.uuidString
                ] as [String: String])
                .eq("id", value: listingId.uuidString)
                .eq("status", value: "active")
                .execute()
            return true
        } catch {
            self.error = "Could not claim this item."
            print("[CommunityService] claimListing failed: \(error)")
            return false
        }
    }

    // MARK: - Update Listing Status

    func updateListingStatus(listingId: UUID, newStatus: String) async -> Bool {
        do {
            var updates: [String: String] = ["status": newStatus]
            if newStatus == "completed" {
                updates["completed_at"] = ISO8601DateFormatter().string(from: Date())
            }
            try await client
                .from("shared_listings")
                .update(updates)
                .eq("id", value: listingId.uuidString)
                .execute()
            return true
        } catch {
            self.error = "Could not update listing."
            print("[CommunityService] updateStatus failed: \(error)")
            return false
        }
    }

    // MARK: - Delete Listing

    func deleteListing(listingId: UUID) async -> Bool {
        do {
            try await client
                .from("shared_listings")
                .delete()
                .eq("id", value: listingId.uuidString)
                .execute()
            return true
        } catch {
            self.error = "Could not remove listing."
            print("[CommunityService] deleteListing failed: \(error)")
            return false
        }
    }

    // MARK: - Report Listing

    func reportListing(listingId: UUID, reporterId: UUID, reason: String, details: String?) async -> Bool {
        let payload: [String: AnyJSON] = [
            "reporter_id": .string(reporterId.uuidString),
            "listing_id": .string(listingId.uuidString),
            "reason": .string(reason),
            "details": details.map { .string($0) } ?? .null
        ]

        do {
            try await client
                .from("community_reports")
                .insert(payload)
                .execute()

            // Increment report count on the listing
            try await client.rpc("increment_report_count", params: ["listing_uuid": listingId.uuidString])
                .execute()

            return true
        } catch {
            // Non-critical — report silently
            print("[CommunityService] reportListing failed: \(error)")
            return true // Don't block the user
        }
    }
}

// MARK: - Create Listing Input

struct CreateListingInput {
    var itemName: String
    var description: String?
    var quantity: Int = 1
    var listingType: String = "share" // "share" or "donate"
    var pickupAddress: String?
    var pickupNotes: String?
    var foodCategory: String = "other"
    var areaName: String?
}

// MARK: - Community Listing DTO (read model with joined profile)

struct CommunityListingDTO: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let itemName: String
    let itemDescription: String?
    let quantity: Int?
    let listingType: String
    let status: String
    let pickupAddress: String?
    let pickupNotes: String?
    let claimedBy: UUID?
    let datePosted: Date?
    let expiryDate: Date?
    let completedAt: Date?
    let foodCategory: String?
    let areaName: String?
    let imageUrls: [String]?
    let reportCount: Int?
    let isFlagged: Bool?
    let profiles: ListingProfileDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemName = "item_name"
        case itemDescription = "item_description"
        case quantity
        case listingType = "listing_type"
        case status
        case pickupAddress = "pickup_address"
        case pickupNotes = "pickup_notes"
        case claimedBy = "claimed_by"
        case datePosted = "date_posted"
        case expiryDate = "expiry_date"
        case completedAt = "completed_at"
        case foodCategory = "food_category"
        case areaName = "area_name"
        case imageUrls = "image_urls"
        case reportCount = "report_count"
        case isFlagged = "is_flagged"
        case profiles
    }

    // MARK: - Display Helpers

    var displayName: String {
        profiles?.displayName ?? "Community Member"
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var isGiveaway: Bool { listingType == "share" }

    var timeAgo: String {
        guard let posted = datePosted else { return "" }
        let interval = Date().timeIntervalSince(posted)
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(max(1, minutes))m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days < 7 { return "\(days)d ago" }
        return posted.formatted(.dateTime.month(.abbreviated).day())
    }

    var categoryEmoji: String {
        switch foodCategory {
        case "fruits": return "🍎"
        case "vegetables": return "🥬"
        case "dairy": return "🥛"
        case "meat": return "🥩"
        case "bakery": return "🍞"
        case "grains": return "🌾"
        case "frozen": return "🧊"
        case "canned": return "🥫"
        case "beverages": return "🥤"
        case "condiments": return "🧂"
        case "snacks": return "🍿"
        default: return "🍽️"
        }
    }
}

// MARK: - Listing Profile DTO (joined from profiles table)

struct ListingProfileDTO: Codable, Sendable {
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}
