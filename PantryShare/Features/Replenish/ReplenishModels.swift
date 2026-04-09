import Foundation
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Replenish Item

/// An item that needs to be replenished — auto-generated when pantry items
/// are consumed, wasted, or fall below a threshold.
struct ReplenishItem: Identifiable, @preconcurrency Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var category: String
    var quantity: Double
    var unit: String
    var source: ReplenishSource
    var addedDate: Date
    var isPurchased: Bool
    var isUrgent: Bool
    var estimatedPrice: Double?
    var lastPricePaid: Double?
    var linkURL: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: String = "other",
        quantity: Double = 1.0,
        unit: String = "pieces",
        source: ReplenishSource = .manual,
        estimatedPrice: Double? = nil,
        lastPricePaid: Double? = nil,
        linkURL: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.source = source
        self.addedDate = Date()
        self.isPurchased = false
        self.isUrgent = false
        self.estimatedPrice = estimatedPrice
        self.lastPricePaid = lastPricePaid
        self.linkURL = linkURL
        self.notes = notes
    }
}

// MARK: - Replenish Source

enum ReplenishSource: String, Codable, Sendable, CaseIterable {
    case consumed
    case wasted
    case lowStock
    case recipe
    case manual

    var displayName: String {
        switch self {
        case .consumed: return "Consumed"
        case .wasted: return "Wasted"
        case .lowStock: return "Low Stock"
        case .recipe: return "Recipe"
        case .manual: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .consumed: return "checkmark.circle.fill"
        case .wasted: return "trash.fill"
        case .lowStock: return "exclamationmark.triangle.fill"
        case .recipe: return "fork.knife"
        case .manual: return "plus.circle.fill"
        }
    }

    var tintColorName: String {
        switch self {
        case .consumed: return "primaryGreen"
        case .wasted: return "expiredRed"
        case .lowStock: return "warningAmber"
        case .recipe: return "accentTeal"
        case .manual: return "infoBlue"
        }
    }
}

// MARK: - Budget Summary

struct ReplenishBudgetSummary: Sendable {
    var estimatedTotal: Double
    var lastPaidTotal: Double
    var itemCount: Int
    var purchasedCount: Int

    var savings: Double {
        lastPaidTotal - estimatedTotal
    }

    var savingsPercentage: Double {
        guard lastPaidTotal > 0 else { return 0 }
        return (savings / lastPaidTotal) * 100
    }

    static let empty = ReplenishBudgetSummary(
        estimatedTotal: 0,
        lastPaidTotal: 0,
        itemCount: 0,
        purchasedCount: 0
    )
}

// MARK: - Delivery Partner (extended for Replenish)

struct ReplenishDeliveryOption: Identifiable, Sendable {
    let id: String
    let name: String
    let icon: String
    let estimatedDelivery: String
    let deliveryFee: Double
    let affiliateURLTemplate: String

    static let allOptions: [ReplenishDeliveryOption] = [
        ReplenishDeliveryOption(
            id: "instacart",
            name: "Instacart",
            icon: "cart.fill",
            estimatedDelivery: "1 hour",
            deliveryFee: 3.99,
            affiliateURLTemplate: "https://instacart.com/store/search?q={query}&ref=freshli"
        ),
        ReplenishDeliveryOption(
            id: "ocado",
            name: "Ocado",
            icon: "shippingbox.fill",
            estimatedDelivery: "Next day",
            deliveryFee: 2.99,
            affiliateURLTemplate: "https://ocado.com/search?entry={query}&ref=freshli"
        ),
        ReplenishDeliveryOption(
            id: "amazon_fresh",
            name: "Amazon Fresh",
            icon: "bag.fill",
            estimatedDelivery: "30 mins",
            deliveryFee: 4.99,
            affiliateURLTemplate: "https://amazon.com/fresh/s?k={query}&tag=freshli-20"
        ),
        ReplenishDeliveryOption(
            id: "apple_pay",
            name: "Apple Pay Checkout",
            icon: "apple.logo",
            estimatedDelivery: "Varies",
            deliveryFee: 0.00,
            affiliateURLTemplate: "https://freshli.app/checkout?items={query}"
        ),
    ]

    func buildURL(for itemName: String) -> URL? {
        let encoded = itemName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? itemName
        let urlString = affiliateURLTemplate.replacingOccurrences(of: "{query}", with: encoded)
        return URL(string: urlString)
    }
}

// MARK: - Transferable: Drag recipe ingredients into Replenish

struct ReplenishIngredientTransfer: @preconcurrency Codable, Sendable {
    let name: String
    let quantity: Double
    let unit: String
    let category: String
    let recipeTitle: String?
}

extension ReplenishIngredientTransfer: Transferable {
    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .freshliIngredient)
        ProxyRepresentation { (value: ReplenishIngredientTransfer) in value.name }
    }
}

extension UTType {
    static let freshliIngredient = UTType(
        exportedAs: "com.freshli.ingredient",
        conformingTo: .json
    )
}

// MARK: - ReplenishItem Transferable (for drag-out)

extension ReplenishItem: Transferable {
    nonisolated static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .freshliReplenishItem)
        ProxyRepresentation { (value: ReplenishItem) in value.name }
    }
}

extension UTType {
    static let freshliReplenishItem = UTType(
        exportedAs: "com.freshli.replenish-item",
        conformingTo: .json
    )
}

// MARK: - Supabase Update Struct (typed Encodable for .update())

struct ReplenishItemUpdate: Encodable {
    var isPurchased: Bool?
    var isUrgent: Bool?
    var estimatedPrice: Double?
    var lastPricePaid: Double?
    var quantity: Double?
    var notes: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case isPurchased = "is_purchased"
        case isUrgent = "is_urgent"
        case estimatedPrice = "estimated_price"
        case lastPricePaid = "last_price_paid"
        case quantity
        case notes
        case updatedAt = "updated_at"
    }
}
