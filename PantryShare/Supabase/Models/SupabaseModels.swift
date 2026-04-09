import Foundation
import Supabase

// MARK: - Core Models
// Codable structs mapping directly to Supabase database tables.
// All use CodingKeys for snake_case column name mapping.

// MARK: - Profile Model

struct SupabaseProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String?
    var avatarUrl: String?
    var householdSize: Int?
    var onboardingCompleted: Bool?
    var notificationsEnabled: Bool?
    var expiryReminderDays: Int?
    var preferredLanguage: String?
    var createdAt: Date?
    var updatedAt: Date?
    var username: String?
    var fullName: String?
    var totalMoneySaved: Double?
    var totalCo2Avoided: Double?
    var mealsShared: Int?
    var streakCount: Int?
    var lastActiveDate: Date?
    var preferences: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case householdSize = "household_size"
        case onboardingCompleted = "onboarding_completed"
        case notificationsEnabled = "notifications_enabled"
        case expiryReminderDays = "expiry_reminder_days"
        case preferredLanguage = "preferred_language"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case username
        case fullName = "full_name"
        case totalMoneySaved = "total_money_saved"
        case totalCo2Avoided = "total_co2_avoided"
        case mealsShared = "meals_shared"
        case streakCount = "streak_count"
        case lastActiveDate = "last_active_date"
        case preferences
    }
}

// MARK: - Pantry Item Model

struct SupabasePantryItem: Codable, Identifiable, Sendable {
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
    var updatedAt: Date?
    var isOpened: Bool?
    var imagePath: String?
    var status: String?
    var purchaseDate: Date?

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
        case updatedAt = "updated_at"
        case isOpened = "is_opened"
        case imagePath = "image_path"
        case status
        case purchaseDate = "purchase_date"
    }
}

// MARK: - Shared Listing Model

struct SupabaseListing: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var itemName: String
    var itemDescription: String?
    var quantity: String?
    var listingType: String
    var status: String
    var pickupAddress: String?
    var pickupNotes: String?
    var claimedBy: UUID?
    var datePosted: Date?
    var expiryDate: Date?
    var completedAt: Date?
    var updatedAt: Date?
    var imageUrls: [String]?
    var areaName: String?
    var latitude: Double?
    var longitude: Double?
    var foodCategory: String?
    var reportCount: Int?
    var isFlagged: Bool?

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
        case updatedAt = "updated_at"
        case imageUrls = "image_urls"
        case areaName = "area_name"
        case latitude, longitude
        case foodCategory = "food_category"
        case reportCount = "report_count"
        case isFlagged = "is_flagged"
    }
}

// MARK: - Claim Model

struct SupabaseClaim: Codable, Identifiable, Sendable {
    let id: UUID
    var listingId: UUID
    var claimerId: UUID
    var status: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case claimerId = "claimer_id"
        case status
        case updatedAt = "updated_at"
    }
}

// MARK: - Impact Event Model

struct SupabaseImpactEvent: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var eventType: String
    var itemName: String?
    var quantity: Double?
    var estimatedMoneySaved: Double?
    var estimatedCo2Avoided: Double?
    var metadata: [String: AnyCodable]?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case itemName = "item_name"
        case quantity
        case estimatedMoneySaved = "estimated_money_saved"
        case estimatedCo2Avoided = "estimated_co2_avoided"
        case metadata
        case createdAt = "created_at"
    }
}

// MARK: - Achievement Model

struct SupabaseAchievement: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var achievementKey: String
    var title: String
    var description: String?
    var unlockedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case achievementKey = "achievement_key"
        case title, description
        case unlockedAt = "unlocked_at"
    }
}

// MARK: - Streak Model

struct SupabaseStreak: Codable, Identifiable, Sendable {
    let id: UUID
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

// MARK: - Saved Recipe Model

struct SupabaseSavedRecipe: Codable, Identifiable, Sendable {
    let id: UUID
    var userId: UUID
    var recipeId: String
    var savedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recipeId = "recipe_id"
        case savedAt = "saved_at"
    }
}

// MARK: - AnyCodable Helper
// Used for flexible JSON fields like preferences and metadata

enum AnyCodable: Codable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodable])
    case object([String: AnyCodable])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodable].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodable].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode AnyCodable")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let bool):
            try container.encode(bool)
        case .int(let int):
            try container.encode(int)
        case .double(let double):
            try container.encode(double)
        case .string(let string):
            try container.encode(string)
        case .array(let array):
            try container.encode(array)
        case .object(let object):
            try container.encode(object)
        }
    }
}
