import Foundation
import SwiftData

@Observable
final class PantryService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD

    func addItem(_ item: PantryItem) {
        modelContext.insert(item)
        try? modelContext.save()
    }

    func deleteItem(_ item: PantryItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    func saveChanges() {
        try? modelContext.save()
    }

    func markAsConsumed(_ item: PantryItem) {
        item.isConsumed = true
        try? modelContext.save()
    }

    func markAsShared(_ item: PantryItem) {
        item.isShared = true
        try? modelContext.save()
    }

    func markAsDonated(_ item: PantryItem) {
        item.isDonated = true
        try? modelContext.save()
    }

    // MARK: - Queries

    func fetchActiveItems() -> [PantryItem] {
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated
            },
            sortBy: [SortDescriptor(\.expiryDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func fetchExpiringItems(withinDays days: Int = 3) -> [PantryItem] {
        let cutoff = Date.daysFromNow(days)
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                !item.isConsumed && !item.isShared && !item.isDonated && item.expiryDate <= cutoff
            },
            sortBy: [SortDescriptor(\.expiryDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
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
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Seed Data

    func seedSampleDataIfNeeded() {
        guard itemCount() == 0 else { return }
        for item in PreviewSampleData.shared.samplePantryItems {
            modelContext.insert(item)
        }
        try? modelContext.save()
    }
}
