import Foundation
import SwiftData

/// Calculates weekly impact wrap data for the Spotify Wrapped-style summary
@Observable
final class ImpactWrapDataService {
    private let modelContext: ModelContext

    struct WeeklyWrapData {
        // Core impact metrics
        let itemsSaved: Int
        let itemsDonated: Int
        let itemsShared: Int
        let totalItemsImpacted: Int

        // Financial impact
        let moneySaved: Double
        let moneySavedDisplay: String

        // Environmental impact
        let co2Avoided: Double
        let co2AvoidedDisplay: String
        let treesEquivalent: Int

        // Category insights
        let topCategorySaved: FoodCategory
        let topCategoryCount: Int
        let categoryBreakdown: [(category: FoodCategory, count: Int)]

        // Temporal insights
        let bestDayOfWeek: String
        let currentStreak: Int
        let streakLabel: String

        // Comparison to previous week
        let weekOverWeekChange: Double
        let weekOverWeekLabel: String

        // Week date range
        let weekStartDate: Date
        let weekEndDate: Date
        let weekDisplayRange: String
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Calculate weekly impact wrap data for the current week
    func calculateCurrentWeekWrapData() -> WeeklyWrapData? {
        let calendar = Calendar.current
        let now = Date()

        // Get current week boundaries (Monday-Sunday)
        let components = calendar.dateComponents([.weekday], from: now)
        let weekday = components.weekday ?? 1
        let daysToMonday = weekday == 1 ? -6 : 2 - weekday
        let weekStart = calendar.date(byAdding: .day, value: daysToMonday, to: now)!
            .startOfDay

        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            .endOfDay

        return calculateWrapData(from: weekStart, to: weekEnd)
    }

    /// Calculate weekly impact wrap data for a specific date range
    func calculateWrapData(from startDate: Date, to endDate: Date) -> WeeklyWrapData? {
        let descriptor = FetchDescriptor<PantryItem>()
        guard let allItems = try? modelContext.fetch(descriptor) else {
            return nil
        }

        // Filter items by date range
        let weekItems = allItems.filter { item in
            item.dateAdded >= startDate && item.dateAdded <= endDate
        }

        // Calculate core metrics
        let itemsSaved = weekItems.filter(\.isConsumed).count
        let itemsDonated = weekItems.filter(\.isDonated).count
        let itemsShared = weekItems.filter(\.isShared).count
        let totalItemsImpacted = itemsSaved + itemsDonated + itemsShared

        // Calculate money saved
        // Average: $2-8 per item based on category
        let moneySaved = calculateMoneySaved(weekItems)
        let moneySavedDisplay = String(format: "$%.0f", moneySaved)

        // Calculate CO2 avoided
        // Base: 2.5kg CO2 per item + category adjustments
        let co2Avoided = calculateCO2Avoided(weekItems)
        let co2AvoidedDisplay = String(format: "%.1f", co2Avoided)

        // Calculate trees equivalent
        // 1 tree absorbs ~22kg CO2/year, so weekly ≈ 22*7/365 ≈ 0.42kg per tree
        let treesEquivalent = max(1, Int(co2Avoided / (22.0 * 7.0 / 365.0)))

        // Find top category
        let categoryBreakdown = calculateCategoryBreakdown(weekItems)
        let topCategory = categoryBreakdown.first ?? (category: .other, count: 0)

        // Calculate best day of week
        let bestDay = calculateBestDayOfWeek(weekItems)

        // Calculate streak
        let (streak, streakLabel) = calculateStreak(allItems)

        // Calculate week-over-week comparison
        let (wowChange, wowLabel) = calculateWeekOverWeekComparison(
            currentWeek: weekItems,
            allItems: allItems,
            weekStart: startDate
        )

        // Format date range
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let weekDisplay = "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"

        return WeeklyWrapData(
            itemsSaved: itemsSaved,
            itemsDonated: itemsDonated,
            itemsShared: itemsShared,
            totalItemsImpacted: totalItemsImpacted,
            moneySaved: moneySaved,
            moneySavedDisplay: moneySavedDisplay,
            co2Avoided: co2Avoided,
            co2AvoidedDisplay: co2AvoidedDisplay,
            treesEquivalent: treesEquivalent,
            topCategorySaved: topCategory.category,
            topCategoryCount: topCategory.count,
            categoryBreakdown: categoryBreakdown,
            bestDayOfWeek: bestDay,
            currentStreak: streak,
            streakLabel: streakLabel,
            weekOverWeekChange: wowChange,
            weekOverWeekLabel: wowLabel,
            weekStartDate: startDate,
            weekEndDate: endDate,
            weekDisplayRange: weekDisplay
        )
    }

    // MARK: - Calculation Helpers

    private func calculateMoneySaved(_ items: [PantryItem]) -> Double {
        var total: Double = 0

        for item in items {
            // Base: $3.50 per item
            var itemValue: Double = 3.50

            // Adjust by category
            itemValue = adjustMoneyByCategory(itemValue, category: item.category)

            // Adjust by quantity
            itemValue *= item.quantity

            // Only count consumed items (higher value than donated/shared)
            if item.isConsumed {
                total += itemValue
            } else {
                total += itemValue * 0.75 // Donated/shared worth slightly less
            }
        }

        return max(0, total)
    }

    private func adjustMoneyByCategory(_ baseValue: Double, category: FoodCategory) -> Double {
        switch category {
        case .dairy, .meat, .seafood:
            return baseValue * 2.0 // Premium foods
        case .fruits, .vegetables, .bakery:
            return baseValue * 1.5 // Moderate value
        case .beverages:
            return baseValue * 1.8
        default:
            return baseValue
        }
    }

    private func calculateCO2Avoided(_ items: [PantryItem]) -> Double {
        var total: Double = 0

        for item in items {
            // Base: 2.5kg CO2 per item
            var co2: Double = 2.5

            // Adjust by category (heavier foods = more CO2)
            co2 = adjustCO2ByCategory(co2, category: item.category)

            // Adjust by quantity
            co2 *= item.quantity

            total += co2
        }

        return max(0, total)
    }

    private func adjustCO2ByCategory(_ baseValue: Double, category: FoodCategory) -> Double {
        switch category {
        case .meat, .seafood:
            return baseValue * 3.0 // Highest carbon footprint
        case .dairy:
            return baseValue * 2.5
        case .bakery, .frozen:
            return baseValue * 1.8
        case .beverages:
            return baseValue * 1.5
        default:
            return baseValue
        }
    }

    private func calculateCategoryBreakdown(_ items: [PantryItem]) -> [(category: FoodCategory, count: Int)] {
        var breakdown: [FoodCategory: Int] = [:]

        for item in items where item.isConsumed {
            breakdown[item.category, default: 0] += Int(item.quantity)
        }

        return breakdown
            .sorted { $0.value > $1.value }
            .map { (category: $0.key, count: $0.value) }
    }

    private func calculateBestDayOfWeek(_ items: [PantryItem]) -> String {
        var dayCount: [Int: Int] = [:] // weekday: count

        for item in items where item.isConsumed {
            let weekday = Calendar.current.component(.weekday, from: item.dateAdded)
            dayCount[weekday, default: 0] += 1
        }

        let bestWeekday = dayCount.max(by: { $0.value < $1.value })?.key ?? 2
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[min(bestWeekday, 7)]
    }

    private func calculateStreak(_ allItems: [PantryItem]) -> (count: Int, label: String) {
        let calendar = Calendar.current
        let today = Date().startOfDay
        var streak = 0
        var currentDate = today

        // Count backwards from today
        while true {
            let itemsOnDay = allItems.filter { item in
                calendar.isDate(item.dateAdded, inSameDayAs: currentDate) && item.isConsumed
            }

            if itemsOnDay.isEmpty {
                break
            }

            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? Date()
        }

        let label: String
        if streak >= 7 {
            label = "🔥 Amazing! You're on fire!"
        } else if streak >= 3 {
            label = "🔥 Keep it up!"
        } else if streak >= 1 {
            label = "Great start!"
        } else {
            label = "Start your streak today!"
        }

        return (streak, label)
    }

    private func calculateWeekOverWeekComparison(
        currentWeek: [PantryItem],
        allItems: [PantryItem],
        weekStart: Date
    ) -> (change: Double, label: String) {
        let calendar = Calendar.current
        let previousWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let previousWeekEnd = calendar.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart

        let previousWeekItems = allItems.filter { item in
            item.dateAdded >= previousWeekStart && item.dateAdded <= previousWeekEnd && item.isConsumed
        }

        let currentCount = currentWeek.filter(\.isConsumed).count
        let previousCount = previousWeekItems.count

        if previousCount == 0 {
            return (1.0, "New!")
        }

        let percentChange = Double(currentCount - previousCount) / Double(previousCount)

        let label: String
        if percentChange > 0.2 {
            label = String(format: "%.0f%% more than last week!", percentChange * 100)
        } else if percentChange > 0 {
            label = "Better than last week!"
        } else if percentChange == 0 {
            label = "Same as last week"
        } else {
            label = String(format: "%.0f%% less than last week", abs(percentChange) * 100)
        }

        return (percentChange, label)
    }
}

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        let startOfDay = self.startOfDay
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
}
