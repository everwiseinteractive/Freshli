import Foundation
import Supabase

// MARK: - Freshli Circle Models
// Strictly isolated, Sendable data units for private food-sharing circles.
// Maps to Supabase tables: circles, circle_members, circle_listings.

// MARK: - Circle

struct SupabaseCircle: Codable, Identifiable, Sendable {
    let id: UUID
    let createdBy: UUID
    var name: String
    var description: String?
    var emoji: String?
    var inviteCode: String?
    var isPrivate: Bool
    var maxMembers: Double?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case name
        case description
        case emoji
        case inviteCode = "invite_code"
        case isPrivate = "is_private"
        case maxMembers = "max_members"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Circle Member

struct SupabaseCircleMember: Codable, Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    var role: String
    var displayName: String?
    var avatarUrl: String?
    var joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case userId = "user_id"
        case role
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case joinedAt = "joined_at"
    }
}

// MARK: - Circle Member Role

enum CircleMemberRole: String, Codable, Sendable {
    case owner
    case admin
    case member
}

// MARK: - Circle Listing (privacy-first: private by default)

struct SupabaseCircleListing: Codable, Identifiable, Sendable {
    let id: UUID
    let circleId: UUID
    let userId: UUID
    var itemName: String
    var itemDescription: String?
    var quantity: String?
    var expiryDate: Date?
    var status: String
    var isGloballyShared: Bool
    var claimedBy: UUID?
    var claimedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case circleId = "circle_id"
        case userId = "user_id"
        case itemName = "item_name"
        case itemDescription = "item_description"
        case quantity
        case expiryDate = "expiry_date"
        case status
        case isGloballyShared = "is_globally_shared"
        case claimedBy = "claimed_by"
        case claimedAt = "claimed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Circle Listing Status

enum CircleListingStatus: String, Codable, Sendable {
    case available
    case claimed
    case completed
    case expired
}

// MARK: - Typed Update Structs (for Supabase .update() calls)

struct CircleUpdate: Encodable {
    var name: String?
    var description: String?
    var emoji: String?
    var isPrivate: Bool?
    var maxMembers: Double?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case name, description, emoji
        case isPrivate = "is_private"
        case maxMembers = "max_members"
        case updatedAt = "updated_at"
    }
}

struct CircleListingStatusUpdate: Encodable {
    var status: String
    var claimedBy: String?
    var claimedAt: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case status
        case claimedBy = "claimed_by"
        case claimedAt = "claimed_at"
        case updatedAt = "updated_at"
    }
}

struct CircleListingGlobalShareUpdate: Encodable {
    var isGloballyShared: Bool
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isGloballyShared = "is_globally_shared"
        case updatedAt = "updated_at"
    }
}

struct CircleMemberRoleUpdate: Encodable {
    var role: String
}
