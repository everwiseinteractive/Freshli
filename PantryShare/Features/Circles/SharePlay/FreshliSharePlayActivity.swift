import Foundation
import GroupActivities

// MARK: - Freshli SharePlay Activity
// GroupActivities integration for family members to live-sync a grocery list
// or pantry view in real-time during a FaceTime call.

struct FreshliCircleActivity: GroupActivity {
    let circleId: UUID
    let circleName: String

    var metadata: GroupActivityMetadata {
        var meta = GroupActivityMetadata()
        meta.title = "Freshli — \(circleName)"
        meta.subtitle = "Share your pantry live"
        meta.type = .generic
        return meta
    }
}

// MARK: - Shared Pantry Item (SharePlay message payload)

struct SharedFreshliItem: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var name: String
    var quantity: String
    var addedBy: String
    var isCheckedOff: Bool

    init(id: UUID = UUID(), name: String, quantity: String, addedBy: String, isCheckedOff: Bool = false) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.addedBy = addedBy
        self.isCheckedOff = isCheckedOff
    }
}

// MARK: - SharePlay Message Types

struct GroceryListMessage: Codable, Sendable {
    let items: [SharedFreshliItem]
    let senderId: String
    let timestamp: Date
}

struct ItemClaimMessage: Codable, Sendable {
    let itemId: UUID
    let claimedBy: String
    let timestamp: Date
}
