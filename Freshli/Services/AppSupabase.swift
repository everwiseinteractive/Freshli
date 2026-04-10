import Foundation
import Supabase

// MARK: - AppSupabase
/// Centralized Supabase client configuration

struct AppSupabase {
    
    /// Shared Supabase client instance
    /// Replace with your actual Supabase URL and anon key
    static let client = SupabaseClient(
        supabaseURL: URL(string: "https://your-project.supabase.co")!,
        supabaseKey: "your-anon-key-here"
    )
}

// MARK: - DTOs (Data Transfer Objects)

struct FreshliItemDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let category: String
    let storageLocation: String
    let quantity: Double
    let unit: String
    let expiryDate: Date
    let dateAdded: Date
    let barcode: String?
    let notes: String?
    let isShared: Bool
    let isDonated: Bool
    let isConsumed: Bool
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, quantity, unit, barcode, notes
        case userId = "user_id"
        case storageLocation = "storage_location"
        case expiryDate = "expiry_date"
        case dateAdded = "date_added"
        case isShared = "is_shared"
        case isDonated = "is_donated"
        case isConsumed = "is_consumed"
        case updatedAt = "updated_at"
    }
    
    init(from item: FreshliItem, userId: UUID) {
        self.id = item.id
        self.userId = userId
        self.name = item.name
        self.category = item.categoryRaw
        self.storageLocation = item.storageLocationRaw
        self.quantity = item.quantity
        self.unit = item.unitRaw
        self.expiryDate = item.expiryDate
        self.dateAdded = item.dateAdded
        self.barcode = item.barcode
        self.notes = item.notes
        self.isShared = item.isShared
        self.isDonated = item.isDonated
        self.isConsumed = item.isConsumed
        self.updatedAt = Date()
    }
}

struct SharedListingDTO: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let itemName: String
    let itemDescription: String
    let quantity: String
    let listingType: String
    let status: String
    let pickupAddress: String
    let pickupNotes: String?
    let createdAt: Date
    let expiryDate: Date
    
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
        case createdAt = "created_at"
        case expiryDate = "expiry_date"
    }
    
    init(from listing: SharedListing, userId: UUID) {
        self.id = listing.id
        self.userId = userId
        self.itemName = listing.itemName
        self.itemDescription = listing.itemDescription
        self.quantity = listing.quantity
        self.listingType = listing.listingTypeRaw
        self.status = listing.statusRaw
        self.pickupAddress = listing.pickupAddress
        self.pickupNotes = listing.pickupNotes
        self.createdAt = listing.datePosted
        self.expiryDate = listing.expiryDate
    }
}

struct ProfileDTO: Codable {
    let id: UUID
    let displayName: String
    let notificationsEnabled: Bool
    let expiryReminderDays: Int
    let preferredLanguage: String
    let itemsSaved: Int
    let itemsShared: Int
    let itemsDonated: Int
    let mealsCreated: Int
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case notificationsEnabled = "notifications_enabled"
        case expiryReminderDays = "expiry_reminder_days"
        case preferredLanguage = "preferred_language"
        case itemsSaved = "items_saved"
        case itemsShared = "items_shared"
        case itemsDonated = "items_donated"
        case mealsCreated = "meals_created"
        case updatedAt = "updated_at"
    }
}

struct ImpactEventDTO: Codable {
    let userId: UUID
    let eventType: String
    let itemName: String?
    let quantity: Double?
    let estimatedMoneySaved: Double?
    let estimatedCo2Avoided: Double?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventType = "event_type"
        case itemName = "item_name"
        case quantity
        case estimatedMoneySaved = "estimated_money_saved"
        case estimatedCo2Avoided = "estimated_co2_avoided"
        case createdAt = "created_at"
    }
    
    init(userId: UUID, eventType: String, itemName: String?, quantity: Double?, estimatedMoneySaved: Double?, estimatedCo2Avoided: Double?) {
        self.userId = userId
        self.eventType = eventType
        self.itemName = itemName
        self.quantity = quantity
        self.estimatedMoneySaved = estimatedMoneySaved
        self.estimatedCo2Avoided = estimatedCo2Avoided
        self.createdAt = Date()
    }
}

struct AchievementDTO: Codable {
    let userId: UUID
    let achievementKey: String
    let title: String
    let description: String?
    let unlockedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case achievementKey = "achievement_key"
        case title
        case description
        case unlockedAt = "unlocked_at"
    }
    
    init(userId: UUID, achievementKey: String, title: String, description: String?) {
        self.userId = userId
        self.achievementKey = achievementKey
        self.title = title
        self.description = description
        self.unlockedAt = Date()
    }
}

struct StreakDTO: Codable {
    let userId: UUID
    let streakType: String
    let currentCount: Int
    let longestCount: Int
    let lastActivityDate: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case streakType = "streak_type"
        case currentCount = "current_count"
        case longestCount = "longest_count"
        case lastActivityDate = "last_activity_date"
    }
}

struct SavedRecipeDTO: Codable {
    let userId: UUID
    let recipeId: String
    let savedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
        case savedAt = "saved_at"
    }
    
    init(userId: UUID, recipeId: String) {
        self.userId = userId
        self.recipeId = recipeId
        self.savedAt = Date()
    }
}
