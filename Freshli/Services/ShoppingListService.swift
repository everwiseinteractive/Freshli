import Foundation
import Observation
import EventKit
import UIKit
import SwiftUI

// MARK: - Models

struct ShoppingItem: Identifiable, Codable, @preconcurrency Sendable {
    let id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var isUrgent: Bool
    var source: String // manual, rescueMission, lowStock
    var addedDate: Date
    var isPurchased: Bool
    var reminderIdentifier: String?

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
        self.reminderIdentifier = nil
    }
}

struct ShoppingList: Identifiable, Codable, @preconcurrency Sendable {
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

// MARK: - EventKit Authorization Status

enum EventKitAuthorizationStatus: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

// MARK: - Service

@Observable
final class ShoppingListService {
    var currentList: ShoppingList
    var allLists: [ShoppingList] = []
    var missingIngredients: [ShoppingItem] = []
    var isAuthorized: Bool = false
    var isSyncing: Bool = false
    var freshliCalendar: EKCalendar?
    var authorizationStatus: EventKitAuthorizationStatus = .notDetermined

    private let userDefaults = UserDefaults.standard
    private let currentListKey = "com.freshli.currentShoppingList"
    private let allListsKey = "com.freshli.allShoppingLists"
    private let missingIngredientsKey = "com.freshli.missingIngredients"
    private let eventStore = EKEventStore()
    private let logger = PSLogger(category: .shopping)
    private let freshliCalendarName = "Freshli Shopping"

    init() {
        // Load or create default list
        if let data = userDefaults.data(forKey: currentListKey),
           let decoded = try? JSONDecoder().decode(ShoppingList.self, from: data) {
            self.currentList = decoded
        } else {
            self.currentList = ShoppingList(name: "Shopping List", isDefault: true)
        }

        loadFromUserDefaults()

        // Initialize EventKit
        Task {
            await initializeEventKit()
        }
    }

    // MARK: - EventKit Setup

    @MainActor
    private func initializeEventKit() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .authorized:
            authorizationStatus = .authorized
            isAuthorized = true
            logger.debug("EventKit already authorized")
            await findOrCreateFreshliCalendar()

        case .notDetermined:
            authorizationStatus = .notDetermined
            logger.debug("EventKit authorization not determined")

        case .denied:
            authorizationStatus = .denied
            isAuthorized = false
            logger.warning("EventKit access denied")

        case .restricted:
            authorizationStatus = .restricted
            isAuthorized = false
            logger.warning("EventKit access restricted")

        @unknown default:
            logger.error("Unknown EventKit authorization status")
        }
    }

    @MainActor
    func requestEventKitAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            if granted {
                authorizationStatus = .authorized
                isAuthorized = true
                logger.info("EventKit access granted")
                await findOrCreateFreshliCalendar()
            } else {
                authorizationStatus = .denied
                isAuthorized = false
                logger.warning("User denied EventKit access")
            }
            return granted
        } catch {
            logger.error("Failed to request EventKit access: \(error)")
            authorizationStatus = .denied
            isAuthorized = false
            return false
        }
    }

    @MainActor
    private func findOrCreateFreshliCalendar() async {
        // Check if Freshli calendar already exists
        let calendars = eventStore.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == freshliCalendarName }) {
            freshliCalendar = existing
            logger.debug("Found existing Freshli calendar")
            return
        }

        // Create new calendar
        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = freshliCalendarName
        calendar.cgColor = UIColor(PSColors.primaryGreen).cgColor

        // Set source — prefer iCloud, fall back to local
        if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = iCloudSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            calendar.source = defaultSource
        }

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            freshliCalendar = calendar
            logger.info("Created new Freshli calendar")
        } catch {
            logger.error("Failed to create Freshli calendar: \(error)")
        }
    }

    // MARK: - Public Methods

    func addItem(name: String, quantity: Double, unit: String, category: String = "other", source: String = "manual") {
        let item = ShoppingItem(name: name, quantity: quantity, unit: unit, category: category, source: source)
        currentList.items.append(item)
        saveToUserDefaults()
    }

    func removeItem(id: UUID) {
        if let item = currentList.items.first(where: { $0.id == id }) {
            // Remove from reminders if synced
            if let reminderId = item.reminderIdentifier {
                Task {
                    await deleteReminder(withIdentifier: reminderId)
                }
            }
        }

        currentList.items.removeAll { $0.id == id }
        missingIngredients.removeAll { $0.id == id }
        saveToUserDefaults()
    }

    func togglePurchased(id: UUID) {
        if let index = currentList.items.firstIndex(where: { $0.id == id }) {
            currentList.items[index].isPurchased.toggle()

            // Update reminder status
            if let reminderId = currentList.items[index].reminderIdentifier {
                Task {
                    await markReminderCompleted(withIdentifier: reminderId, isCompleted: currentList.items[index].isPurchased)
                }
            }

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

    func addToShoppingList(_ items: [ShoppingItem]) async {
        for var item in items {
            // Add reminder if authorized
            if isAuthorized, let reminder = await createReminder(for: item) {
                item.reminderIdentifier = reminder.calendarItemIdentifier
            }
            currentList.items.append(item)
        }
        saveToUserDefaults()
        logger.info("Added \(items.count) items to shopping list")
    }

    func syncShoppingList() async {
        guard isAuthorized else {
            logger.warning("Cannot sync: EventKit not authorized")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // Sync unpurchased items to reminders
            let unsynced = currentList.items.filter { $0.reminderIdentifier == nil && !$0.isPurchased }

            for var item in unsynced {
                if let reminder = await createReminder(for: item) {
                    if let index = currentList.items.firstIndex(where: { $0.id == item.id }) {
                        currentList.items[index].reminderIdentifier = reminder.calendarItemIdentifier
                    }
                }
            }

            saveToUserDefaults()
            logger.info("Synced \(unsynced.count) items to reminders")
        }
    }

    func fetchShoppingList() async -> [ShoppingItem] {
        guard isAuthorized, let calendar = freshliCalendar else {
            return currentList.items
        }

        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }

        // Update local items with reminder data
        await MainActor.run {
            for reminder in reminders {
                if let index = currentList.items.firstIndex(where: { $0.reminderIdentifier == reminder.calendarItemIdentifier }) {
                    currentList.items[index].isPurchased = reminder.isCompleted
                }
            }
            saveToUserDefaults()
        }

        logger.debug("Fetched \(reminders.count) reminders from Freshli calendar")
        return currentList.items
    }

    @MainActor
    func exportToReminders() async {
        guard await requestEventKitAccess() else {
            logger.warning("EventKit access not granted")
            return
        }

        await syncShoppingList()
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

    // MARK: - EventKit Reminders

    @MainActor
    private func createReminder(for item: ShoppingItem) async -> EKReminder? {
        guard let calendar = freshliCalendar else {
            logger.warning("Freshli calendar not found")
            return nil
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.name
        reminder.calendar = calendar
        reminder.notes = buildReminderNotes(for: item)
        reminder.priority = item.isUrgent ? 1 : 5 // 1 = high, 5 = normal

        // Set due date to tomorrow for quick shopping
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)

        do {
            try eventStore.save(reminder, commit: true)
            logger.debug("Created reminder: \(item.name)")
            return reminder
        } catch {
            logger.error("Failed to create reminder: \(error)")
            return nil
        }
    }

    @MainActor
    private func deleteReminder(withIdentifier identifier: String) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            logger.warning("Reminder not found: \(identifier)")
            return
        }

        do {
            try eventStore.remove(reminder, commit: true)
            logger.debug("Deleted reminder: \(identifier)")
        } catch {
            logger.error("Failed to delete reminder: \(error)")
        }
    }

    @MainActor
    private func markReminderCompleted(withIdentifier identifier: String, isCompleted: Bool) async {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            logger.warning("Reminder not found: \(identifier)")
            return
        }

        reminder.isCompleted = isCompleted

        do {
            try eventStore.save(reminder, commit: true)
            logger.debug("Updated reminder completion status: \(identifier)")
        } catch {
            logger.error("Failed to update reminder: \(error)")
        }
    }

    private func buildReminderNotes(for item: ShoppingItem) -> String {
        var notes = "From Freshli Shopping List\n"
        notes += "Quantity: \(String(format: "%.1f", item.quantity)) \(item.unit)\n"
        notes += "Category: \(item.category.uppercased())"

        if item.isUrgent {
            notes += "\nUrgent: Yes"
        }

        if item.source != "manual" {
            notes += "\nSource: \(item.source.uppercased())"
        }

        return notes
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
