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
