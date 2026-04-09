import ActivityKit

// MARK: - Expiry Rescue Activity Attributes
// Shared definition for the food expiry rescue Live Activity.
// This struct must match the definition in the FreshliWidgets extension.

struct FreshliWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Hours remaining until expiry.
        var hoursRemaining: Int
        /// Current status: "expiring", "rescued", "shared"
        var status: String
    }

    /// Item name
    var itemName: String
    /// Food category for emoji
    var category: String
    /// Quantity description
    var quantity: String
}
