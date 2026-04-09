import Foundation
import SwiftData
import os

@Observable
final class ImpactService {
    private let modelContext: ModelContext
    private let logger = PSLogger(category: .impact)

    // Cache for stats to reduce redundant queries
    private var cachedStats: ImpactStats?
    private var lastStatsCacheTime: Date?
    private let statsCacheDuration: TimeInterval = 60.0 // Cache for 60 seconds

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    struct ImpactStats {
        var itemsSaved: Int = 0
        var itemsShared: Int = 0
        var itemsDonated: Int = 0
        var mealsCreated: Int = 0

        // Impact metrics: $3.50 per item saved (average food cost), 2.5kg CO2 per item (production + waste)
        var moneySaved: Double {
            let total = Double(itemsSaved)
            return max(0, total * 3.50) // Ensure no negative values
        }

        var co2Avoided: Double {
            let total = Double(max(0, itemsSaved + itemsShared + itemsDonated)) // Prevent negative totals
            return total * 2.5
        }

        var totalMealsHelped: Int {
            max(0, itemsShared + itemsDonated) // Ensure non-negative
        }

        var moneySavedDisplay: String {
            String(format: "$%.0f", moneySaved.isFinite ? moneySaved : 0)
        }

        var co2Display: String {
            String(format: "%.1fkg", co2Avoided.isFinite ? co2Avoided : 0)
        }
    }

    func calculateStats() -> ImpactStats {
        // Check cache first
        if let cached = cachedStats, let cacheTime = lastStatsCacheTime,
           Date().timeIntervalSince(cacheTime) < statsCacheDuration {
            logger.debug("Using cached stats")
            return cached
        }

        // Optimize: batch all counts into a single predicate-based query
        let descriptor = FetchDescriptor<FreshliItem>()
        let allItems = (try? modelContext.fetch(descriptor)) ?? []

        let consumed = allItems.filter(\.isConsumed).count
        let shared = allItems.filter(\.isShared).count
        let donated = allItems.filter(\.isDonated).count

        let stats = ImpactStats(
            itemsSaved: consumed + shared + donated,
            itemsShared: shared,
            itemsDonated: donated,
            mealsCreated: consumed
        )

        // Update cache
        cachedStats = stats
        lastStatsCacheTime = Date()
        logger.info("Calculated stats - saved: \(stats.itemsSaved), shared: \(stats.itemsShared), donated: \(stats.itemsDonated)")

        return stats
    }

    private func fetchCount(isConsumed: Bool = false, isShared: Bool = false, isDonated: Bool = false) -> Int {
        let descriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate<FreshliItem> { item in
                item.isConsumed == isConsumed && item.isShared == isShared && item.isDonated == isDonated
            }
        )
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            logger.error("Failed to fetch count: \(error.localizedDescription)")
            return 0
        }
    }

    // MARK: - Milestones

    struct Milestone: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
        let isUnlocked: Bool
        let progress: Double
    }

    func milestones(for stats: ImpactStats) -> [Milestone] {
        [
            Milestone(
                icon: "leaf.fill",
                title: String(localized: "First Saver"),
                description: String(localized: "Save your first item from waste"),
                isUnlocked: stats.itemsSaved >= 1,
                progress: min(1.0, Double(max(0, stats.itemsSaved)) / 1.0)
            ),
            Milestone(
                icon: "fork.knife",
                title: String(localized: "Home Chef"),
                description: String(localized: "Cook 5 meals from your pantry"),
                isUnlocked: stats.mealsCreated >= 5,
                progress: min(1.0, Double(max(0, stats.mealsCreated)) / 5.0)
            ),
            Milestone(
                icon: "hand.raised.fill",
                title: String(localized: "Generous Neighbor"),
                description: String(localized: "Share 5 items with your community"),
                isUnlocked: stats.itemsShared >= 5,
                progress: min(1.0, Double(max(0, stats.itemsShared)) / 5.0)
            ),
            Milestone(
                icon: "heart.fill",
                title: String(localized: "Donation Hero"),
                description: String(localized: "Donate 10 items to those in need"),
                isUnlocked: stats.itemsDonated >= 10,
                progress: min(1.0, Double(max(0, stats.itemsDonated)) / 10.0)
            ),
            Milestone(
                icon: "dollarsign.circle.fill",
                title: String(localized: "Smart Saver"),
                description: String(localized: "Save $50 by reducing waste"),
                isUnlocked: stats.moneySaved >= 50,
                progress: min(1.0, max(0, stats.moneySaved) / 50.0)
            ),
            Milestone(
                icon: "star.fill",
                title: String(localized: "Waste Warrior"),
                description: String(localized: "Save 50 items from going to waste"),
                isUnlocked: stats.itemsSaved >= 50,
                progress: min(1.0, Double(max(0, stats.itemsSaved)) / 50.0)
            ),
            Milestone(
                icon: "person.3.fill",
                title: String(localized: "Community Leader"),
                description: String(localized: "Share or donate 25 items total"),
                isUnlocked: stats.totalMealsHelped >= 25,
                progress: min(1.0, Double(max(0, stats.totalMealsHelped)) / 25.0)
            ),
            Milestone(
                icon: "cloud.fill",
                title: String(localized: "Climate Champion"),
                description: String(localized: "Avoid 100kg of CO₂ emissions"),
                isUnlocked: stats.co2Avoided >= 100,
                progress: min(1.0, max(0, stats.co2Avoided) / 100.0)
            ),
        ]
    }
}
