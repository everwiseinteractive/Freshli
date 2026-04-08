import AppIntents
import SwiftData
import SwiftUI

// MARK: - App Shortcuts Provider
// Registers shortcuts with Siri, Shortcuts app, and Spotlight.

struct PantryShareShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowExpiringItemsIntent(),
            phrases: [
                "Show expiring items in \(.applicationName)",
                "What's expiring in \(.applicationName)",
                "Check my \(.applicationName) pantry"
            ],
            shortTitle: "Expiring Items",
            systemImageName: "exclamationmark.triangle"
        )

        AppShortcut(
            intent: AddPantryItemIntent(),
            phrases: [
                "Add item to \(.applicationName)",
                "Add to my \(.applicationName) pantry",
                "Track food in \(.applicationName)"
            ],
            shortTitle: "Add Item",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ShowImpactIntent(),
            phrases: [
                "Show my \(.applicationName) impact",
                "How much food have I saved in \(.applicationName)",
                "My \(.applicationName) stats"
            ],
            shortTitle: "My Impact",
            systemImageName: "leaf.fill"
        )

        AppShortcut(
            intent: OpenCommunityIntent(),
            phrases: [
                "Open \(.applicationName) community",
                "Browse food listings in \(.applicationName)",
                "Find shared food in \(.applicationName)"
            ],
            shortTitle: "Community",
            systemImageName: "person.2.fill"
        )
    }
}

// MARK: - Show Expiring Items Intent

struct ShowExpiringItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Expiring Items"
    static var description: IntentDescription = "Shows pantry items that are expiring soon."
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: PantryItem.self)
        let context = container.mainContext
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate { !$0.isConsumed && !$0.isShared && !$0.isDonated },
            sortBy: [SortDescriptor(\PantryItem.expiryDate)]
        )
        let items = try context.fetch(descriptor)

        let expiringSoon = items.filter {
            $0.expiryStatus == .expiringSoon || $0.expiryStatus == .expiringToday || $0.expiryStatus == .expired
        }

        if expiringSoon.isEmpty {
            return .result(dialog: "You have no items expiring soon. Your pantry is looking great!")
        } else {
            let names = expiringSoon.prefix(5).map(\.name).joined(separator: ", ")
            return .result(dialog: "You have \(expiringSoon.count) items expiring soon: \(names)")
        }
    }
}

// MARK: - Add Pantry Item Intent

struct AddPantryItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Pantry Item"
    static var description: IntentDescription = "Add a new item to your pantry."
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Item Name")
    var itemName: String

    @Parameter(title: "Category", default: "other")
    var category: String

    @Parameter(title: "Days Until Expiry", default: 7)
    var daysUntilExpiry: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: PantryItem.self)
        let context = container.mainContext

        let foodCategory = FoodCategory(rawValue: category) ?? .other
        let item = PantryItem(
            name: itemName,
            category: foodCategory,
            storageLocation: .pantry,
            quantity: 1,
            unit: .pieces,
            expiryDate: Calendar.current.date(byAdding: .day, value: daysUntilExpiry, to: Date()) ?? Date()
        )
        context.insert(item)
        try context.save()

        return .result(dialog: "Added \(itemName) to your pantry. It expires in \(daysUntilExpiry) days.")
    }
}

// MARK: - Show Impact Intent

struct ShowImpactIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Impact"
    static var description: IntentDescription = "Shows your food waste reduction impact."
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: UserProfile.self)
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        let profile = profiles.first

        let saved = profile?.itemsSaved ?? 0
        let shared = profile?.itemsShared ?? 0
        let donated = profile?.itemsDonated ?? 0
        let co2 = profile?.estimatedCO2Avoided ?? 0

        return .result(dialog: "You've saved \(saved) items, shared \(shared), donated \(donated), and avoided \(String(format: "%.1f", co2)) kg of CO\u{2082} emissions. Keep it up!")
    }
}

// MARK: - Open Community Intent

struct OpenCommunityIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Community"
    static var description: IntentDescription = "Opens the community tab to browse shared food listings."
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        return .result(dialog: "Opening the Freshli community...")
    }
}

// MARK: - Mark Item as Used Intent

struct MarkItemUsedIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Item as Used"
    static var description: IntentDescription = "Mark a pantry item as consumed."

    @Parameter(title: "Item Name")
    var itemName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: PantryItem.self)
        let context = container.mainContext
        let searchName = itemName
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                item.name == searchName && !item.isConsumed
            }
        )
        let items = try context.fetch(descriptor)

        if let item = items.first {
            item.isConsumed = true
            try context.save()
            return .result(dialog: "Marked \(itemName) as used. Nice work reducing waste!")
        } else {
            return .result(dialog: "Couldn't find \(itemName) in your pantry.")
        }
    }
}
