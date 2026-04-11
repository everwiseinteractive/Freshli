import Foundation
import SwiftUI

// MARK: - Retailer Purchase

struct RetailerPurchase: Identifiable, Codable {
    let id: UUID
    let retailerName: String
    let itemName: String
    let category: String
    let quantity: Double
    let unit: String
    let purchasedAt: Date
    var isImported: Bool

    init(id: UUID = UUID(), retailerName: String, itemName: String, category: String,
         quantity: Double = 1, unit: String = "pieces", purchasedAt: Date, isImported: Bool = false) {
        self.id = id
        self.retailerName = retailerName
        self.itemName = itemName
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.purchasedAt = purchasedAt
        self.isImported = isImported
    }
}

// MARK: - Retailer Definition

struct RetailerDefinition: Identifiable {
    let id: String           // "tesco", "sainsburys", "waitrose" …
    let name: String
    let logoColor: Color
    let logoAccent: Color
    let loyaltyProgramName: String
    let supportsAutoSync: Bool
    let countries: [String]
}

extension RetailerDefinition {
    static let all: [RetailerDefinition] = [
        RetailerDefinition(
            id: "tesco",
            name: "Tesco",
            logoColor: Color(hex: 0x005DA4),
            logoAccent: Color(hex: 0xF02B2B),
            loyaltyProgramName: "Clubcard",
            supportsAutoSync: true,
            countries: ["GB", "IE"]
        ),
        RetailerDefinition(
            id: "sainsburys",
            name: "Sainsbury's",
            logoColor: Color(hex: 0xFF8000),
            logoAccent: Color(hex: 0x8B2252),
            loyaltyProgramName: "Nectar",
            supportsAutoSync: true,
            countries: ["GB"]
        ),
        RetailerDefinition(
            id: "waitrose",
            name: "Waitrose",
            logoColor: Color(hex: 0x006B3C),
            logoAccent: Color(hex: 0x1A1A1A),
            loyaltyProgramName: "myWaitrose",
            supportsAutoSync: false,
            countries: ["GB"]
        ),
        RetailerDefinition(
            id: "wholefoods",
            name: "Whole Foods",
            logoColor: Color(hex: 0x00674B),
            logoAccent: Color(hex: 0x1A1A1A),
            loyaltyProgramName: "Amazon Prime",
            supportsAutoSync: true,
            countries: ["US", "GB"]
        ),
        RetailerDefinition(
            id: "kroger",
            name: "Kroger",
            logoColor: Color(hex: 0x004B98),
            logoAccent: Color(hex: 0xE31837),
            loyaltyProgramName: "Kroger Plus",
            supportsAutoSync: true,
            countries: ["US"]
        ),
        RetailerDefinition(
            id: "walmart",
            name: "Walmart",
            logoColor: Color(hex: 0x0071CE),
            logoAccent: Color(hex: 0xFFC220),
            loyaltyProgramName: "Walmart+",
            supportsAutoSync: false,
            countries: ["US"]
        ),
    ]

    static func retailer(for id: String) -> RetailerDefinition? {
        all.first { $0.id == id }
    }
}

// MARK: - Retailer Integration Service

@MainActor
@Observable
final class RetailerIntegrationService {

    static let shared = RetailerIntegrationService()
    private init() { loadConnections() }

    // MARK: - State

    var connectedRetailerIds: Set<String> = []
    var pendingPurchases: [RetailerPurchase] = []
    var isSyncing = false
    var lastSyncDate: Date?
    var connectionError: String?

    var connectedRetailers: [RetailerDefinition] {
        RetailerDefinition.all.filter { connectedRetailerIds.contains($0.id) }
    }

    // MARK: - Persistence Keys

    private let connectedKey  = "retailer_connected_ids"
    private let pendingKey    = "retailer_pending_purchases"
    private let lastSyncKey   = "retailer_last_sync_date"

    // MARK: - Connection

    /// Simulate OAuth / loyalty card link flow.
    /// In production: open retailer OAuth URL, handle callback, store token securely in Keychain.
    func connect(retailer: RetailerDefinition) async -> Bool {
        isSyncing = true
        connectionError = nil
        // Simulate network handshake delay
        try? await Task.sleep(for: .milliseconds(1400))
        connectedRetailerIds.insert(retailer.id)
        saveConnections()
        isSyncing = false
        // Immediately fetch a first batch of purchases
        await syncPurchases(for: retailer)
        return true
    }

    func disconnect(retailer: RetailerDefinition) {
        connectedRetailerIds.remove(retailer.id)
        pendingPurchases.removeAll { $0.retailerName == retailer.name }
        saveConnections()
    }

    // MARK: - Sync

    /// Pull recent purchases from all connected retailers.
    func syncAll() async {
        guard !connectedRetailers.isEmpty else { return }
        isSyncing = true
        for retailer in connectedRetailers {
            await syncPurchases(for: retailer)
        }
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey)
        isSyncing = false
    }

    private func syncPurchases(for retailer: RetailerDefinition) async {
        // Simulate API latency
        try? await Task.sleep(for: .milliseconds(600))
        let purchases = simulatedPurchases(for: retailer)
        // Merge — don't duplicate
        let existing = Set(pendingPurchases.map { $0.id })
        let fresh = purchases.filter { !existing.contains($0.id) }
        pendingPurchases.append(contentsOf: fresh)
    }

    // MARK: - Import to Pantry

    /// Mark a purchase as imported (call after FreshliItem is created from it).
    func markImported(_ purchase: RetailerPurchase) {
        if let i = pendingPurchases.firstIndex(where: { $0.id == purchase.id }) {
            pendingPurchases[i].isImported = true
        }
    }

    // MARK: - Simulated Data
    // In production these come from the retailer's loyalty API.

    private func simulatedPurchases(for retailer: RetailerDefinition) -> [RetailerPurchase] {
        let now = Date()
        let sevenDaysAgo = now.addingTimeInterval(-7 * 86_400)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        let yesterday    = now.addingTimeInterval(-1 * 86_400)

        switch retailer.id {
        case "tesco":
            return [
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Organic Spinach", category: "vegetables", quantity: 200, unit: "grams", purchasedAt: threeDaysAgo),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Free Range Eggs", category: "dairy", quantity: 6, unit: "pieces", purchasedAt: yesterday),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Whole Milk", category: "dairy", quantity: 2, unit: "liters", purchasedAt: yesterday),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Sourdough Bread", category: "bakery", quantity: 1, unit: "pieces", purchasedAt: yesterday),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Chicken Breast", category: "meat", quantity: 500, unit: "grams", purchasedAt: sevenDaysAgo),
            ]
        case "sainsburys":
            return [
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Smoked Salmon", category: "seafood", quantity: 120, unit: "grams", purchasedAt: yesterday),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Greek Yogurt", category: "dairy", quantity: 500, unit: "grams", purchasedAt: threeDaysAgo),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Cherry Tomatoes", category: "vegetables", quantity: 300, unit: "grams", purchasedAt: threeDaysAgo),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Penne Pasta", category: "grains", quantity: 500, unit: "grams", purchasedAt: sevenDaysAgo),
            ]
        case "wholefoods":
            return [
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Avocado", category: "fruits", quantity: 2, unit: "pieces", purchasedAt: yesterday),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Almond Milk", category: "dairy", quantity: 1, unit: "liters", purchasedAt: threeDaysAgo),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Kale", category: "vegetables", quantity: 150, unit: "grams", purchasedAt: threeDaysAgo),
            ]
        case "kroger":
            return [
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Ground Beef", category: "meat", quantity: 500, unit: "grams", purchasedAt: threeDaysAgo),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Cheddar Cheese", category: "dairy", quantity: 200, unit: "grams", purchasedAt: yesterday),
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Broccoli", category: "vegetables", quantity: 1, unit: "pieces", purchasedAt: threeDaysAgo),
            ]
        default:
            return [
                RetailerPurchase(id: UUID(), retailerName: retailer.name, itemName: "Mixed Salad Leaves", category: "vegetables", quantity: 100, unit: "grams", purchasedAt: yesterday),
            ]
        }
    }

    // MARK: - Persistence

    private func saveConnections() {
        UserDefaults.standard.set(Array(connectedRetailerIds), forKey: connectedKey)
    }

    private func loadConnections() {
        if let saved = UserDefaults.standard.array(forKey: connectedKey) as? [String] {
            connectedRetailerIds = Set(saved)
        }
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }
}
