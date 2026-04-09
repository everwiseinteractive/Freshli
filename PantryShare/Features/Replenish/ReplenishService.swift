import Foundation
import Observation
import os

// MARK: - Freshli Replenish Service
// Manages the smart replenishment list lifecycle:
// - Auto-populates when items are marked Consumed or Wasted
// - Tracks estimated vs last-paid pricing for budget insights
// - Supports drag-and-drop of recipe ingredients
// - Persists via UserDefaults (mirrors ShoppingListService pattern)

@Observable
final class ReplenishService {
    var items: [ReplenishItem] = []
    var archivedItems: [ReplenishItem] = []

    private let userDefaults = UserDefaults.standard
    private let itemsKey = "com.freshli.replenishItems"
    private let archivedKey = "com.freshli.replenishArchived"
    private let priceHistoryKey = "com.freshli.replenishPriceHistory"
    private let logger = Logger(subsystem: "com.freshli.app", category: "ReplenishService")

    /// Price history: maps item name (lowercased) → last known price
    private(set) var priceHistory: [String: Double] = [:]

    init() {
        loadFromStorage()
    }

    // MARK: - Computed Properties

    var neededItems: [ReplenishItem] {
        items.filter { !$0.isPurchased }
    }

    var purchasedItems: [ReplenishItem] {
        items.filter { $0.isPurchased }
    }

    var urgentItems: [ReplenishItem] {
        neededItems.filter { $0.isUrgent }
    }

    var budgetSummary: ReplenishBudgetSummary {
        let needed = neededItems
        let estimated = needed.compactMap(\.estimatedPrice).reduce(0, +)
        let lastPaid = needed.compactMap(\.lastPricePaid).reduce(0, +)
        return ReplenishBudgetSummary(
            estimatedTotal: estimated,
            lastPaidTotal: lastPaid,
            itemCount: needed.count,
            purchasedCount: purchasedItems.count
        )
    }

    var itemsByCategory: [String: [ReplenishItem]] {
        Dictionary(grouping: neededItems, by: { $0.category })
    }

    // MARK: - Auto-Populate from Pantry Events

    /// Called when a pantry item is consumed — adds it to the replenish list
    func itemConsumed(name: String, category: String, quantity: Double, unit: String) {
        let lastPrice = priceHistory[name.lowercased()]
        let item = ReplenishItem(
            name: name,
            category: category,
            quantity: quantity,
            unit: unit,
            source: .consumed,
            estimatedPrice: estimatedPrice(for: name, category: category),
            lastPricePaid: lastPrice
        )
        addItemIfNotDuplicate(item)
        logger.debug("ReplenishService: Auto-added consumed item '\(name)'")
    }

    /// Called when a pantry item is wasted — adds it to replenish with urgent flag
    func itemWasted(name: String, category: String, quantity: Double, unit: String) {
        let lastPrice = priceHistory[name.lowercased()]
        var item = ReplenishItem(
            name: name,
            category: category,
            quantity: quantity,
            unit: unit,
            source: .wasted,
            estimatedPrice: estimatedPrice(for: name, category: category),
            lastPricePaid: lastPrice
        )
        item.isUrgent = true
        addItemIfNotDuplicate(item)
        logger.debug("ReplenishService: Auto-added wasted item '\(name)' (urgent)")
    }

    // MARK: - Recipe Ingredient Drop

    /// Adds recipe ingredients to the replenish list (from drag-and-drop)
    func addRecipeIngredients(_ ingredients: [ReplenishIngredientTransfer]) {
        for ingredient in ingredients {
            let lastPrice = priceHistory[ingredient.name.lowercased()]
            let item = ReplenishItem(
                name: ingredient.name,
                category: ingredient.category,
                quantity: ingredient.quantity,
                unit: ingredient.unit,
                source: .recipe,
                estimatedPrice: estimatedPrice(for: ingredient.name, category: ingredient.category),
                lastPricePaid: lastPrice,
                notes: ingredient.recipeTitle.map { "From: \($0)" }
            )
            addItemIfNotDuplicate(item)
        }
        logger.debug("ReplenishService: Added \(ingredients.count) recipe ingredients")
    }

    // MARK: - CRUD

    func addItem(
        name: String,
        category: String = "other",
        quantity: Double = 1.0,
        unit: String = "pieces",
        estimatedPrice: Double? = nil
    ) {
        let lastPrice = priceHistory[name.lowercased()]
        let item = ReplenishItem(
            name: name,
            category: category,
            quantity: quantity,
            unit: unit,
            source: .manual,
            estimatedPrice: estimatedPrice ?? self.estimatedPrice(for: name, category: category),
            lastPricePaid: lastPrice
        )
        addItemIfNotDuplicate(item)
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveToStorage()
    }

    func togglePurchased(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPurchased.toggle()
        if items[index].isPurchased {
            // Record the estimated price as last-paid for future reference
            if let price = items[index].estimatedPrice {
                recordPrice(for: items[index].name, price: price)
            }
        }
        saveToStorage()
    }

    func toggleUrgent(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isUrgent.toggle()
        saveToStorage()
    }

    func updateEstimatedPrice(id: UUID, price: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].estimatedPrice = price
        saveToStorage()
    }

    func updateQuantity(id: UUID, quantity: Double) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].quantity = quantity
        saveToStorage()
    }

    // MARK: - Archive (clear purchased)

    func archivePurchasedItems() {
        let purchased = purchasedItems
        archivedItems.append(contentsOf: purchased)
        items.removeAll { $0.isPurchased }
        saveToStorage()
        logger.debug("ReplenishService: Archived \(purchased.count) purchased items")
    }

    func clearAll() {
        items.removeAll()
        saveToStorage()
    }

    // MARK: - Price History

    func recordPrice(for itemName: String, price: Double) {
        priceHistory[itemName.lowercased()] = price
        savePriceHistory()
    }

    // MARK: - Private Helpers

    private func addItemIfNotDuplicate(_ item: ReplenishItem) {
        // Merge into existing item if same name and not purchased
        if let index = items.firstIndex(where: {
            $0.name.lowercased() == item.name.lowercased() && !$0.isPurchased
        }) {
            items[index].quantity += item.quantity
            if item.isUrgent { items[index].isUrgent = true }
            if let price = item.estimatedPrice, items[index].estimatedPrice == nil {
                items[index].estimatedPrice = price
            }
        } else {
            items.append(item)
        }
        saveToStorage()
    }

    /// Heuristic pricing based on category averages (placeholder for real pricing API)
    private func estimatedPrice(for name: String, category: String) -> Double {
        // Check price history first
        if let historical = priceHistory[name.lowercased()] {
            return historical
        }
        // Category-based estimates
        switch category {
        case "dairy": return 4.99
        case "meat": return 8.99
        case "seafood": return 12.99
        case "fruits", "vegetables": return 3.49
        case "bakery": return 3.99
        case "frozen": return 5.49
        case "beverages": return 2.99
        case "snacks": return 4.49
        case "grains": return 3.29
        case "condiments": return 3.99
        case "canned": return 2.49
        default: return 3.99
        }
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        let decoder = JSONDecoder()

        if let data = userDefaults.data(forKey: itemsKey),
           let decoded = try? decoder.decode([ReplenishItem].self, from: data) {
            items = decoded
        }

        if let data = userDefaults.data(forKey: archivedKey),
           let decoded = try? decoder.decode([ReplenishItem].self, from: data) {
            archivedItems = decoded
        }

        if let data = userDefaults.data(forKey: priceHistoryKey),
           let decoded = try? decoder.decode([String: Double].self, from: data) {
            priceHistory = decoded
        }
    }

    private func saveToStorage() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(items) {
            userDefaults.set(data, forKey: itemsKey)
        }
        if let data = try? encoder.encode(archivedItems) {
            userDefaults.set(data, forKey: archivedKey)
        }
    }

    private func savePriceHistory() {
        if let data = try? JSONEncoder().encode(priceHistory) {
            userDefaults.set(data, forKey: priceHistoryKey)
        }
    }
}
