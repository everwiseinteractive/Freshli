import Foundation
import SwiftData
import os

@Observable
final class PantryService {
    private let modelContext: ModelContext
    private let notificationService: NotificationService?
    private let logger = PSLogger(category: .pantry)

    init(modelContext: ModelContext, notificationService: NotificationService? = nil) {
        self.modelContext = modelContext
        self.notificationService = notificationService
    }

    // MARK: - CRUD

    func addItem(_ item: PantryItem) {
        modelContext.insert(item)
        do {
            try modelContext.save()
            SpotlightService.indexItem(item)
            logger.info("Added item: \(item.name)")
        } catch {
            logger.error("Failed to add item: \(error.localizedDescription)")
        }
    }

    func deleteItem(_ item: PantryItem) {
        // Cancel any pending reminders before deletion
        notificationService?.cancelReminder(for: item)
        modelContext.delete(item)
        do {
            try modelContext.save()
            SpotlightService.removeItem(item.id)
            logger.info("Deleted item: \(item.name)")
        } catch {
            logger.error("Failed to delete item: \(error.localizedDescription)")
        }
    }

    func saveChanges() {
        do {
            try modelContext.save()
            logger.info("Changes saved")
        } catch {
            logger.error("Failed to save changes: \(error.localizedDescription)")
        }
    }

    func markAsConsumed(_ item: PantryItem) {
        item.isConsumed = true
        notificationService?.cancelReminder(for: item)
        do {
            try modelContext.save()
            SpotlightService.removeItem(item.id)
            logger.info("Marked as consumed: \(item.name)")
        } catch {
            logger.error("Failed to mark consumed: \(error.localizedDescription)")
        }
    }

    func markAsShared(_ item: PantryItem) {
        item.isShared = true
        notificationService?.cancelReminder(for: item)
        do {
            try modelContext.save()
            SpotlightService.removeItem(item.id)
            logger.info("Marked as shared: \(item.name)")
        } catch {
            logger.error("Failed to mark shared: \(error.localizedDescription)")
        }
    }

    func markAsDonated(_ item: PantryItem) {
        item.isDonated = true
        notificationService?.cancelReminder(for: item)
        do {
            try modelContext.save()
            SpotlightService.removeItem(item.id)
            logger.info("Marked as donated: \(item.name)")
        } catch {
            logger.error("Failed to mark donated: \(error.localizedDescription)")
        }
    }

    // MARK: - Queries

    func fetchActiveItems() -> [PantryItem] {
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated
            },
            sortBy: [SortDescriptor(\.expiryDate)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch active items: \(error.localizedDescription)")
            return []
        }
    }

    func fetchExpiringItems(withinDays days: Int = 3) -> [PantryItem] {
        let cutoff = Date.daysFromNow(days)
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated && item.expiryDate <= cutoff
            },
            sortBy: [SortDescriptor(\.expiryDate)]
        )
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch expiring items: \(error.localizedDescription)")
            return []
        }
    }

    func fetchItems(category: FoodCategory? = nil, location: StorageLocation? = nil) -> [PantryItem] {
        var items = fetchActiveItems()
        if let category {
            items = items.filter { $0.category == category }
        }
        if let location {
            items = items.filter { $0.storageLocation == location }
        }
        return items
    }

    func itemCount() -> Int {
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated
            }
        )
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            logger.error("Failed to fetch item count: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Item Updates with Notification Rescheduling

    /// Update an item's expiry date and reschedule its notification reminder.
    func updateItemExpiryDate(_ item: PantryItem, newDate: Date) {
        item.expiryDate = newDate
        // Reschedule the notification for the new date
        notificationService?.rescheduleReminder(for: item)
        do {
            try modelContext.save()
            logger.info("Updated expiry date for \(item.name)")
        } catch {
            logger.error("Failed to update expiry date: \(error.localizedDescription)")
        }
    }

    // MARK: - Seed Data

    /// Load sample data if the pantry is empty.
    func seedSampleDataIfNeeded() {
        guard itemCount() == 0 else {
            logger.debug("Pantry already has items, skipping seed")
            return
        }
        do {
            let items = PreviewSampleData.shared.samplePantryItems
            for item in items {
                modelContext.insert(item)
            }
            try modelContext.save()
            SpotlightService.indexItems(items)
            logger.info("Loaded sample data")
        } catch {
            logger.error("Failed to load sample data: \(error.localizedDescription)")
        }
    }
}
