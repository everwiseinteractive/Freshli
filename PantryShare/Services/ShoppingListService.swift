import Foundation
import Observation

// MARK: - Models

struct ShoppingItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var isUrgent: Bool
    var source: String // manual, rescueMission, lowStock
    var addedDate: Date
    var isPurchased: Bool

    init(name: String, quantity: Double, unit: String, category: String, isUrgent: Bool = false, source: String = "manual") {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.isUrgent = isUrgent
        self.source = source
        self.addedDate = Date()
        self.isPurchased = false
    }
}

struct ShoppingList: Identifiable, Codable {
    let id: UUID
    var name: String
    var items: [ShoppingItem]
    var createdDate: Date
    var isDefault: Bool

    init(name: String, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.items = []
        self.createdDate = Date()
        self.isDefault = isDefault
    }
}

enum DeliveryPartner: String, Codable, CaseIterable {
    case instacart
    case amazonFresh
    case walmart
    case doordash

    var displayName: String {
        switch self {
        case .instacart: return "Instacart"
        case .amazonFresh: return "Amazon Fresh"
        case .walmart: return "Walmart+"
        case .doordash: return "DoorDash"
        }
    }

    var estimatedDelivery: String {
        switch self {
        case .instacart: return "1 hour"
        case .amazonFresh: return "30 mins"
        case .walmart: return "2 hours"
        case .doordash: return "45 mins"
        }
    }

    var affiliateURL: String {
        switch self {
        case .instacart: return "https://instacart.com"
        case .amazonFresh: return "https://amazon.com/fresh"
        case .walmart: return "https://walmart.com"
        case .doordash: return "https://doordash.com"
        }
    }

    var icon: String {
        switch self {
        case .instacart: return "cart.fill"
        case .amazonFresh: return "bag.fill"
        case .walmart: return "storefront.fill"
        case .doordash: return "bicycle"
        }
    }
}

// MARK: - Service

@Observable
final class ShoppingListService {
    var currentList: ShoppingList
    var allLists: [ShoppingList] = []
    var missingIngredients: [ShoppingItem] = []

    private let userDefaults = UserDefaults.standard
    private let currentListKey = "com.freshli.currentShoppingList"
    private let allListsKey = "com.freshli.allShoppingLists"
    private let missingIngredientsKey = "com.freshli.missingIngredients"

    init() {
        // Load or create default list
        if let data = userDefaults.data(forKey: currentListKey),
           let decoded = try? JSONDecoder().decode(ShoppingList.self, from: data) {
            self.currentList = decoded
        } else {
            self.currentList = ShoppingList(name: "Shopping List", isDefault: true)
        }

        loadFromUserDefaults()
    }

    // MARK: - Public Methods

    func addItem(name: String, quantity: Double, unit: String, category: String = "other", source: String = "manual") {
        let item = ShoppingItem(name: name, quantity: quantity, unit: unit, category: category, source: source)
        currentList.items.append(item)
        saveToUserDefaults()
    }

    func removeItem(id: UUID) {
        currentList.items.removeAll { $0.id == id }
        missingIngredients.removeAll { $0.id == id }
        saveToUserDefaults()
    }

    func togglePurchased(id: UUID) {
        if let index = currentList.items.firstIndex(where: { $0.id == id }) {
            currentList.items[index].isPurchased.toggle()
            saveToUserDefaults()
        }
    }

    func toggleUrgent(id: UUID) {
        if let index = currentList.items.firstIndex(where: { $0.id == id }) {
            currentList.items[index].isUrgent.toggle()
            saveToUserDefaults()
        }
    }

    func addMissingIngredient(_ ingredient: String, quantity: Double = 1.0, unit: String = "pieces", category: String = "other") {
        let item = ShoppingItem(name: ingredient, quantity: quantity, unit: unit, category: category, isUrgent: true, source: "rescueMission")
        missingIngredients.append(item)
        currentList.items.append(item)
        saveToUserDefaults()
    }

    func removeMissingIngredient(id: UUID) {
        missingIngredients.removeAll { $0.id == id }
        removeItem(id: id)
    }

    func exportToReminders() {
        // Stub for EventKit/Reminders integration
        // TODO: Integrate EKRemindersStore and EventKit
        // let store = EKEventStore()
        // store.requestAccess(to: .reminder) { granted, error in
        //     if granted {
        //         let reminder = EKReminder(eventStore: store)
        //         reminder.title = self.currentList.name
        //         self.currentList.items.forEach { item in
        //             reminder.notes = (reminder.notes ?? "") + "\n- \(item.name) (\(item.quantity) \(item.unit))"
        //         }
        //         try? store.save(reminder, commit: true)
        //     }
        // }
    }

    func suggestDeliveryPartner(for items: [ShoppingItem]) -> DeliveryPartner? {
        // Simple logic: prioritize faster delivery for urgent items
        let hasUrgent = items.contains { $0.isUrgent }

        if hasUrgent {
            return .amazonFresh // Fastest delivery
        }

        // Otherwise suggest based on item categories
        let categories = Set(items.map { $0.category })
        if categories.contains("produce") || categories.contains("dairy") {
            return .instacart
        }

        return .instacart // Default
    }

    func createNewList(name: String) {
        let newList = ShoppingList(name: name, isDefault: false)
        allLists.append(newList)
        currentList = newList
        saveToUserDefaults()
    }

    func switchToList(_ list: ShoppingList) {
        currentList = list
        saveToUserDefaults()
    }

    func deleteList(_ list: ShoppingList) {
        allLists.removeAll { $0.id == list.id }
        if currentList.id == list.id {
            if !allLists.isEmpty {
                currentList = allLists[0]
            } else {
                currentList = ShoppingList(name: "Shopping List", isDefault: true)
            }
        }
        saveToUserDefaults()
    }

    func updateItem(_ item: ShoppingItem) {
        if let index = currentList.items.firstIndex(where: { $0.id == item.id }) {
            currentList.items[index] = item
            saveToUserDefaults()
        }
    }

    // MARK: - Private Methods

    private func loadFromUserDefaults() {
        if let data = userDefaults.data(forKey: allListsKey),
           let decoded = try? JSONDecoder().decode([ShoppingList].self, from: data) {
            allLists = decoded
        } else {
            allLists = [currentList]
        }

        if let data = userDefaults.data(forKey: missingIngredientsKey),
           let decoded = try? JSONDecoder().decode([ShoppingItem].self, from: data) {
            missingIngredients = decoded
        }
    }

    private func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(currentList) {
            userDefaults.set(encoded, forKey: currentListKey)
        }

        if let encoded = try? JSONEncoder().encode(allLists) {
            userDefaults.set(encoded, forKey: allListsKey)
        }

        if let encoded = try? JSONEncoder().encode(missingIngredients) {
            userDefaults.set(encoded, forKey: missingIngredientsKey)
        }
    }
}
