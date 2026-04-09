import Foundation
import SwiftData
import WidgetKit
import os

// MARK: - Widget Data Service
// Writes pantry and impact data to shared App Group UserDefaults
// so the widget extension can display it without direct SwiftData access.

enum WidgetDataService {
    static let appGroupID = "group.everwise.interactive.Freshli"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Keys

    private enum Keys {
        static let expiringItems = "widget_expiring_items"
        static let totalItems = "widget_total_items"
        static let itemsSaved = "widget_items_saved"
        static let itemsShared = "widget_items_shared"
        static let itemsDonated = "widget_items_donated"
        static let co2Avoided = "widget_co2_avoided"
        static let lastUpdated = "widget_last_updated"
    }

    // MARK: - Debouncing

    private static var lastUpdateTime: Date?
    private static let minimumUpdateInterval: TimeInterval = 5.0 // 5 second debounce

    private static let logger = PSLogger(category: .widget)

    // MARK: - Write from Main App

    @MainActor
    static func updateWidgetData(modelContext: ModelContext) {
        guard let defaults = sharedDefaults else { return }

        // Debounce rapid updates
        if let lastUpdate = lastUpdateTime, Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            logger.debug("Widget update debounced - too soon since last update")
            return
        }
        lastUpdateTime = Date()

        do {
            // Fetch pantry items
            let itemDescriptor = FetchDescriptor<FreshliItem>(
                predicate: #Predicate { !$0.isConsumed && !$0.isShared && !$0.isDonated },
                sortBy: [SortDescriptor(\FreshliItem.expiryDate)]
            )
            let items = try modelContext.fetch(itemDescriptor)

            // Serialize expiring items (top 6)
            let expiringData: [[String: Any]] = items.prefix(6).map { item in
                [
                    "id": item.id.uuidString,
                    "name": item.name,
                    "category": item.categoryRaw,
                    "daysUntilExpiry": item.expiryDate.daysUntilExpiry
                ]
            }

            defaults.set(expiringData, forKey: Keys.expiringItems)
            defaults.set(items.count, forKey: Keys.totalItems)

            // Fetch profile stats
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            if let profile = profiles.first {
                defaults.set(profile.itemsSaved, forKey: Keys.itemsSaved)
                defaults.set(profile.itemsShared, forKey: Keys.itemsShared)
                defaults.set(profile.itemsDonated, forKey: Keys.itemsDonated)
                defaults.set(profile.estimatedCO2Avoided, forKey: Keys.co2Avoided)
            }

            defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdated)

            // Reload widget timelines to reflect updated data
            WidgetCenter.shared.reloadAllTimelines()
            logger.info("Widget data updated successfully")
        } catch {
            logger.error("Failed to update widget data: \(error.localizedDescription)")
        }
    }

    // MARK: - Read from Widget Extension

    static func readExpiringItems() -> [WidgetExpiringItem] {
        guard let defaults = sharedDefaults,
              let data = defaults.array(forKey: Keys.expiringItems) as? [[String: Any]] else {
            return []
        }

        return data.compactMap { dict in
            guard let name = dict["name"] as? String,
                  let category = dict["category"] as? String,
                  let days = dict["daysUntilExpiry"] as? Int else { return nil }
            return WidgetExpiringItem(name: name, category: category, daysUntilExpiry: days)
        }
    }

    static func readTotalItems() -> Int {
        sharedDefaults?.integer(forKey: Keys.totalItems) ?? 0
    }

    static func readItemsSaved() -> Int {
        sharedDefaults?.integer(forKey: Keys.itemsSaved) ?? 0
    }

    static func readItemsShared() -> Int {
        sharedDefaults?.integer(forKey: Keys.itemsShared) ?? 0
    }

    static func readCO2Avoided() -> Double {
        sharedDefaults?.double(forKey: Keys.co2Avoided) ?? 0
    }
}

// MARK: - Widget Data Model (shared between app and widget)

struct WidgetExpiringItem: Codable {
    let name: String
    let category: String
    let daysUntilExpiry: Int

    var emoji: String {
        switch category {
        case "fruits": return "🍎"
        case "vegetables": return "🥬"
        case "dairy": return "🥛"
        case "meat": return "🥩"
        case "bakery": return "🍞"
        case "grains": return "🌾"
        case "frozen": return "🧊"
        case "canned": return "🥫"
        case "beverages": return "🥤"
        case "snacks": return "🍿"
        case "condiments": return "🧂"
        default: return "🍽️"
        }
    }

    var expiryLabel: String {
        switch daysUntilExpiry {
        case ...0: return String(localized: "Expired")
        case 1: return String(localized: "Tomorrow")
        default: return String(localized: "\(daysUntilExpiry)d left")
        }
    }

    var urgencyColor: String {
        switch daysUntilExpiry {
        case ...0: return "expired"
        case 1...2: return "warning"
        default: return "fresh"
        }
    }
}
