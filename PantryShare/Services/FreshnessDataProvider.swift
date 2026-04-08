import Foundation
import SwiftData
import WidgetKit
import os

// MARK: - Freshness Data Model (Codable for UserDefaults storage)

struct FreshnessData: Codable {
    /// Freshness score from 0.0 to 1.0 (percentage of items saved this week)
    let score: Double

    /// Count of items consumed, donated, or shared this week
    let itemsSavedThisWeek: Int

    /// Consecutive days with no expired items
    let streakDays: Int

    /// Last time this data was calculated
    let lastUpdated: Date

    var percentageDisplay: String {
        String(format: "%.0f%%", score * 100)
    }

    /// Determine ring color based on score
    var ringColor: String {
        switch score {
        case 0.8...1.0: return "green"
        case 0.5..<0.8: return "amber"
        default: return "red"
        }
    }
}

// MARK: - Freshness Data Provider Service

enum FreshnessDataProvider {
    private static let appGroupID = "group.everwise.interactive.PantryShare"
    private static let logger = PSLogger.widget

    private enum Keys {
        static let freshnessData = "freshness_data"
        static let lastStreakCheckDate = "freshness_last_streak_check"
        static let streakStartDate = "freshness_streak_start_date"
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Calculate and Save Freshness Data

    /// Calculate weekly freshness score and save to shared UserDefaults
    /// Call this whenever an item state changes (consumed, donated, shared, or expires)
    @MainActor
    static func updateFreshnessData(modelContext: ModelContext) {
        guard let defaults = sharedDefaults else {
            logger.error("Failed to access shared UserDefaults")
            return
        }

        do {
            // Get current date boundaries
            let calendar = Calendar.current
            let now = Date()
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

            // MARK: Fetch items from past week

            // All items in the past week that were consumed, donated, or shared
            let savedItemsDescriptor = FetchDescriptor<PantryItem>(
                predicate: #Predicate { item in
                    (item.isConsumed || item.isDonated || item.isShared) &&
                    item.dateAdded >= weekAgo
                }
            )
            let savedItems = try modelContext.fetch(savedItemsDescriptor)

            // All items in the past week that expired without being saved
            let expiredItemsDescriptor = FetchDescriptor<PantryItem>(
                predicate: #Predicate { item in
                    !item.isConsumed &&
                    !item.isDonated &&
                    !item.isShared &&
                    item.expiryDate < now &&
                    item.dateAdded >= weekAgo
                }
            )
            let expiredItems = try modelContext.fetch(expiredItemsDescriptor)

            // MARK: Calculate freshness score

            let totalRelevantItems = savedItems.count + expiredItems.count
            let score: Double = totalRelevantItems > 0
                ? Double(savedItems.count) / Double(totalRelevantItems)
                : 1.0 // Perfect score if no items this week

            // MARK: Calculate streak

            let streakDays = calculateStreak(
                modelContext: modelContext,
                calendar: calendar,
                currentDate: now,
                defaults: defaults
            )

            // MARK: Create and save FreshnessData

            let freshnessData = FreshnessData(
                score: min(score, 1.0),
                itemsSavedThisWeek: savedItems.count,
                streakDays: streakDays,
                lastUpdated: now
            )

            if let encoded = try? JSONEncoder().encode(freshnessData) {
                defaults.set(encoded, forKey: Keys.freshnessData)
                logger.info("Freshness data updated: score=\(String(format: "%.2f", freshnessData.score)), streak=\(freshnessData.streakDays)d")

                // Reload widgets
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            logger.error("Failed to update freshness data: \(error.localizedDescription)")
        }
    }

    // MARK: - Calculate Streak

    private static func calculateStreak(
        modelContext: ModelContext,
        calendar: Calendar,
        currentDate: Date,
        defaults: UserDefaults
    ) -> Int {
        // Get last streak check date
        let lastCheckDate: Date? = {
            if let timestamp = defaults.object(forKey: Keys.lastStreakCheckDate) as? TimeInterval {
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        }()

        let lastCheckDay = lastCheckDate.map { calendar.startOfDay(for: $0) }
        let currentDay = calendar.startOfDay(for: currentDate)

        // Check if we've already updated today
        if let lastDay = lastCheckDay, lastDay == currentDay {
            // Return existing streak
            if let timestamp = defaults.object(forKey: Keys.streakStartDate) as? TimeInterval {
                let streakStart = Date(timeIntervalSince1970: timestamp)
                let days = calendar.dateComponents([.day], from: streakStart, to: currentDay).day ?? 0
                return max(days + 1, 0)
            }
        }

        // Check if yesterday had any expired items
        let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDay)!
        let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterday)!

        do {
            let yesterdayExpiredDescriptor = FetchDescriptor<PantryItem>(
                predicate: #Predicate { item in
                    !item.isConsumed &&
                    !item.isDonated &&
                    !item.isShared &&
                    item.expiryDate < yesterdayEnd &&
                    item.expiryDate >= yesterday
                }
            )
            let yesterdayExpired = try modelContext.fetch(yesterdayExpiredDescriptor)

            // If there were expired items yesterday, reset streak
            if !yesterdayExpired.isEmpty {
                defaults.removeObject(forKey: Keys.streakStartDate)
                defaults.set(currentDate.timeIntervalSince1970, forKey: Keys.lastStreakCheckDate)
                return 0
            }

            // Streak continues
            let streakStartDate: Date = {
                if let timestamp = defaults.object(forKey: Keys.streakStartDate) as? TimeInterval {
                    return Date(timeIntervalSince1970: timestamp)
                } else {
                    defaults.set(currentDate.timeIntervalSince1970, forKey: Keys.streakStartDate)
                    return currentDate
                }
            }()

            let days = calendar.dateComponents([.day], from: streakStartDate, to: currentDay).day ?? 0
            defaults.set(currentDate.timeIntervalSince1970, forKey: Keys.lastStreakCheckDate)

            return max(days + 1, 1)
        } catch {
            logger.error("Failed to calculate streak: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Read from Widget Extension

    static func readFreshnessData() -> FreshnessData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: Keys.freshnessData) else {
            return nil
        }

        return try? JSONDecoder().decode(FreshnessData.self, from: data)
    }

    /// Get the latest freshness score (0.0 to 1.0)
    static func getFreshnessScore() -> Double {
        readFreshnessData()?.score ?? 0.0
    }

    /// Get items saved this week
    static func getItemsSavedThisWeek() -> Int {
        readFreshnessData()?.itemsSavedThisWeek ?? 0
    }

    /// Get current streak days
    static func getStreakDays() -> Int {
        readFreshnessData()?.streakDays ?? 0
    }
}
