import Foundation

// MARK: - Supabase Data Transfer Objects
// Codable structs mirroring the Supabase PostgreSQL schema.
// snake_case column names are mapped via CodingKeys.

// MARK: - Profile

struct ProfileDTO: Codable, Sendable {
    let id: UUID
    var displayName: String?
    var avatarUrl: String?
    var householdSize: Int?
    var onboardingCompleted: Bool?
    var notificationsEnabled: Bool?
    var expiryReminderDays: Int?
    var preferredLanguage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case householdSize = "household_size"
        case onboardingCompleted = "onboarding_completed"
        case notificationsEnabled = "notifications_enabled"
        case expiryReminderDays = "expiry_reminder_days"
        case preferredLanguage = "preferred_language"
    }
}

// MARK: - Freshli Item

struct FreshliItemDTO: Codable, Sendable {
    let id: UUID
    var userId: UUID
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var storageLocation: String
    var expiryDate: Date
    var barcode: String?
    var notes: String?
    var isConsumed: Bool
    var isShared: Bool
    var isDonated: Bool
    var dateAdded: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, quantity, unit, category
        case storageLocation = "storage_location"
        case expiryDate = "expiry_date"
        case barcode, notes
        case isConsumed = "is_consumed"
        case isShared = "is_shared"
        case isDonated = "is_donated"
        case dateAdded = "date_added"
    }
}

// MARK: - Shared Listing

struct SharedListingDTO: Codable, Sendable {
    let id: UUID
    var userId: UUID
    var itemName: String
    var description: String?
    var quantity: String?
    var listingType: String
    var status: String
    var pickupAddress: String?
    var pickupNotes: String?
    var expiresAt: Date?
    var claimedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemName = "item_name"
        case description, quantity
        case listingType = "listing_type"
        case status
        case pickupAddress = "pickup_address"
        case pickupNotes = "pickup_notes"
        case expiresAt = "expires_at"
        case claimedBy = "claimed_by"
    }
}

// MARK: - Impact Event

struct ImpactEventDTO: Codable, Sendable {
    var id: UUID?
    var userId: UUID
    var eventType: String
    var itemName: String?
    var quantity: Double?
    var estimatedMoneySaved: Double?
    var estimatedCo2Avoided: Double?
    var metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case itemName = "item_name"
        case quantity
        case estimatedMoneySaved = "estimated_money_saved"
        case estimatedCo2Avoided = "estimated_co2_avoided"
        case metadata
    }
}

// MARK: - Achievement

struct AchievementDTO: Codable, Sendable {
    var id: UUID?
    var userId: UUID
    var achievementKey: String
    var title: String
    var description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case achievementKey = "achievement_key"
        case title, description
    }
}

// MARK: - Streak

struct StreakDTO: Codable, Sendable {
    var id: UUID?
    var userId: UUID
    var streakType: String
    var currentCount: Int
    var longestCount: Int
    var lastActivityDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case streakType = "streak_type"
        case currentCount = "current_count"
        case longestCount = "longest_count"
        case lastActivityDate = "last_activity_date"
    }
}

// MARK: - Saved Recipe

struct SavedRecipeDTO: Codable, Sendable {
    var id: UUID?
    var userId: UUID
    var recipeId: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recipeId = "recipe_id"
    }
}

// MARK: - Conversion Helpers

extension FreshliItemDTO {
    /// Create a DTO from a local SwiftData FreshliItem
    init(from item: FreshliItem, userId: UUID) {
        self.id = item.id
        self.userId = userId
        self.name = item.name
        self.quantity = item.quantity
        self.unit = item.unitRaw
        self.category = item.categoryRaw
        self.storageLocation = item.storageLocationRaw
        self.expiryDate = item.expiryDate
        self.barcode = item.barcode
        self.notes = item.notes
        self.isConsumed = item.isConsumed
        self.isShared = item.isShared
        self.isDonated = item.isDonated
        self.dateAdded = item.dateAdded
    }
}

extension SharedListingDTO {
    /// Create a DTO from a local SwiftData SharedListing
    init(from listing: SharedListing, userId: UUID) {
        self.id = listing.id
        self.userId = userId
        self.itemName = listing.itemName
        self.description = listing.itemDescription
        self.quantity = listing.quantity
        self.listingType = listing.listingTypeRaw
        self.status = listing.statusRaw
        self.pickupAddress = listing.pickupAddress
        self.pickupNotes = listing.pickupNotes
        self.expiresAt = listing.expiryDate
        self.claimedBy = nil
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Collective Impact (Live Wave)
// MARK: ─────────────────────────────────────────────────────────────

/// Row returned by the public.collective_rescue_feed view.
struct CollectiveRescueFeedDTO: Codable, Sendable {
    let id: UUID
    let displayName: String
    let displayCity: String
    let itemName: String
    let eventType: String
    let minutesAgo: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case displayCity = "display_city"
        case itemName = "item_name"
        case eventType = "event_type"
        case minutesAgo = "minutes_ago"
        case createdAt = "created_at"
    }
}

/// Row returned by the public.get_collective_hourly_stats() RPC.
struct CollectiveHourlyStatsDTO: Codable, Sendable {
    let rescuesThisHour: Int
    let co2AvoidedKg: Double
    let mealsFed: Int
    let distinctRescuers: Int

    enum CodingKeys: String, CodingKey {
        case rescuesThisHour = "rescues_this_hour"
        case co2AvoidedKg = "co2_avoided_kg"
        case mealsFed = "meals_fed"
        case distinctRescuers = "distinct_rescuers"
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Karma Credits
// MARK: ─────────────────────────────────────────────────────────────

struct KarmaTransactionDTO: Codable, Sendable {
    var id: UUID?
    let userId: UUID
    let type: String                // "given" / "received" / "bonus"
    let amount: Int
    let itemName: String
    var otherPartyId: UUID?
    var otherPartyName: String?
    var metadata: [String: String]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case amount
        case itemName = "item_name"
        case otherPartyId = "other_party_id"
        case otherPartyName = "other_party_name"
        case metadata
        case createdAt = "created_at"
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Bin Log (Trash Analytics)
// MARK: ─────────────────────────────────────────────────────────────

struct BinLogEntryDTO: Codable, Sendable {
    var id: UUID?
    let userId: UUID
    let itemName: String
    let category: String
    let reason: String              // "forgotten" / "disliked" / ...
    var costEstimate: Double?
    var postcodeHash: String?
    var loggedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemName = "item_name"
        case category
        case reason
        case costEstimate = "cost_estimate"
        case postcodeHash = "postcode_hash"
        case loggedAt = "logged_at"
    }
}

struct StopBuyingAlertDTO: Codable, Sendable {
    let itemName: String
    let binCount: Int
    let totalCost: Double
    let topReason: String

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case binCount = "bin_count"
        case totalCost = "total_cost"
        case topReason = "top_reason"
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Local Pods & Membership
// MARK: ─────────────────────────────────────────────────────────────

struct LocalPodDTO: Codable, Sendable {
    var id: UUID?
    let name: String
    let address: String
    let podType: String             // "apartment" / "office" / "street" / "school"
    let areaHash: String
    var latitude: Double?
    var longitude: Double?
    let joinCode: String
    var isVerified: Bool?
    var createdBy: UUID?
    var createdAt: Date?
    var memberCount: Int?           // present when reading via local_pods_with_counts
    var activeListings: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, address
        case podType = "pod_type"
        case areaHash = "area_hash"
        case latitude, longitude
        case joinCode = "join_code"
        case isVerified = "is_verified"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case memberCount = "member_count"
        case activeListings = "active_listings"
    }
}

struct PodMemberDTO: Codable, Sendable {
    var id: UUID?
    let podId: UUID
    let userId: UUID
    var role: String?               // "member" / "moderator" / "creator"
    var joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case podId = "pod_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Community Fridges
// MARK: ─────────────────────────────────────────────────────────────

struct CommunityFridgeDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let city: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let isOpen24h: Bool
    var openingHours: String?
    let currentStatus: String       // "available" / "nearly_full" / "full" / "maintenance"
    let acceptedItems: [String]
    let organisedBy: String
    var contactUrl: String?
    var lastStatusUpdate: Date?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, address, city
        case countryCode = "country_code"
        case latitude, longitude
        case isOpen24h = "is_open_24h"
        case openingHours = "opening_hours"
        case currentStatus = "current_status"
        case acceptedItems = "accepted_items"
        case organisedBy = "organised_by"
        case contactUrl = "contact_url"
        case lastStatusUpdate = "last_status_update"
        case isActive = "is_active"
    }
}

struct FridgeStatusUpdateDTO: Codable, Sendable {
    var id: UUID?
    let fridgeId: UUID
    var reportedBy: UUID?
    var oldStatus: String?
    let newStatus: String
    var note: String?
    var reportedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fridgeId = "fridge_id"
        case reportedBy = "reported_by"
        case oldStatus = "old_status"
        case newStatus = "new_status"
        case note
        case reportedAt = "reported_at"
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Retailer Integrations
// MARK: ─────────────────────────────────────────────────────────────

struct RetailerConnectionDTO: Codable, Sendable {
    var id: UUID?
    let userId: UUID
    let retailerId: String          // "tesco", "sainsburys", etc.
    let retailerName: String
    var loyaltyProgram: String?
    var isActive: Bool?
    var lastSyncedAt: Date?
    var connectedAt: Date?
    var disconnectedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case retailerId = "retailer_id"
        case retailerName = "retailer_name"
        case loyaltyProgram = "loyalty_program"
        case isActive = "is_active"
        case lastSyncedAt = "last_synced_at"
        case connectedAt = "connected_at"
        case disconnectedAt = "disconnected_at"
    }
}

struct RetailerPurchaseDTO: Codable, Sendable {
    var id: UUID?
    let userId: UUID
    let connectionId: UUID
    let retailerId: String
    let itemName: String
    var category: String?
    var quantity: Double?
    var unit: String?
    let purchasedAt: Date
    var isImported: Bool?
    var importedItemId: UUID?
    var importedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case connectionId = "connection_id"
        case retailerId = "retailer_id"
        case itemName = "item_name"
        case category, quantity, unit
        case purchasedAt = "purchased_at"
        case isImported = "is_imported"
        case importedItemId = "imported_item_id"
        case importedAt = "imported_at"
    }
}

// MARK: ─────────────────────────────────────────────────────────────
// MARK: - Ingredient Pings
// MARK: ─────────────────────────────────────────────────────────────

struct IngredientRequestDTO: Codable, Sendable {
    var id: UUID?
    let requesterId: UUID
    let podId: UUID
    let itemName: String
    var quantity: String?
    let urgency: String             // "now" / "today" / "this_week"
    var note: String?
    var karmaCost: Int?
    var status: String?             // "open" / "matched" / "fulfilled" / ...
    var fulfilledBy: UUID?
    var fulfilledAt: Date?
    let expiresAt: Date
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case requesterId = "requester_id"
        case podId = "pod_id"
        case itemName = "item_name"
        case quantity, urgency, note
        case karmaCost = "karma_cost"
        case status
        case fulfilledBy = "fulfilled_by"
        case fulfilledAt = "fulfilled_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

struct IngredientRequestResponseDTO: Codable, Sendable {
    var id: UUID?
    let requestId: UUID
    let responderId: UUID
    var message: String?
    var status: String?             // "offered" / "accepted" / "declined" / "withdrawn"
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case responderId = "responder_id"
        case message, status
        case createdAt = "created_at"
    }
}
