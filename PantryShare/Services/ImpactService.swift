import Foundation
import SwiftData

@Observable
final class ImpactService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    struct ImpactStats {
        var itemsSaved: Int = 0
        var itemsShared: Int = 0
        var itemsDonated: Int = 0
        var mealsCreated: Int = 0

        var moneySaved: Double { Double(itemsSaved) * 3.50 }
        var co2Avoided: Double { Double(itemsSaved + itemsShared + itemsDonated) * 2.5 }
        var totalMealsHelped: Int { itemsShared + itemsDonated }

        var moneySavedDisplay: String { String(format: "$%.0f", moneySaved) }
        var co2Display: String { String(format: "%.1fkg", co2Avoided) }
    }

    func calculateStats() -> ImpactStats {
        let consumed = fetchCount(isConsumed: true)
        let shared = fetchCount(isShared: true)
        let donated = fetchCount(isDonated: true)

        return ImpactStats(
            itemsSaved: consumed + shared + donated,
            itemsShared: shared,
            itemsDonated: donated,
            mealsCreated: consumed
        )
    }

    private func fetchCount(isConsumed: Bool = false, isShared: Bool = false, isDonated: Bool = false) -> Int {
        let descriptor = FetchDescriptor<PantryItem>(
            predicate: #Predicate<PantryItem> { item in
                item.isConsumed == isConsumed && item.isShared == isShared && item.isDonated == isDonated
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
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
                progress: min(1, Double(stats.itemsSaved) / 1)
            ),
            Milestone(
                icon: "fork.knife",
                title: String(localized: "Home Chef"),
                description: String(localized: "Cook 5 meals from your pantry"),
                isUnlocked: stats.mealsCreated >= 5,
                progress: min(1, Double(stats.mealsCreated) / 5)
            ),
            Milestone(
                icon: "hand.raised.fill",
                title: String(localized: "Generous Neighbor"),
                description: String(localized: "Share 5 items with your community"),
                isUnlocked: stats.itemsShared >= 5,
                progress: min(1, Double(stats.itemsShared) / 5)
            ),
            Milestone(
                icon: "heart.fill",
                title: String(localized: "Donation Hero"),
                description: String(localized: "Donate 10 items to those in need"),
                isUnlocked: stats.itemsDonated >= 10,
                progress: min(1, Double(stats.itemsDonated) / 10)
            ),
            Milestone(
                icon: "dollarsign.circle.fill",
                title: String(localized: "Smart Saver"),
                description: String(localized: "Save $50 by reducing waste"),
                isUnlocked: stats.moneySaved >= 50,
                progress: min(1, stats.moneySaved / 50)
            ),
            Milestone(
                icon: "star.fill",
                title: String(localized: "Waste Warrior"),
                description: String(localized: "Save 50 items from going to waste"),
                isUnlocked: stats.itemsSaved >= 50,
                progress: min(1, Double(stats.itemsSaved) / 50)
            ),
            Milestone(
                icon: "person.3.fill",
                title: String(localized: "Community Leader"),
                description: String(localized: "Share or donate 25 items total"),
                isUnlocked: stats.totalMealsHelped >= 25,
                progress: min(1, Double(stats.totalMealsHelped) / 25)
            ),
            Milestone(
                icon: "cloud.fill",
                title: String(localized: "Climate Champion"),
                description: String(localized: "Avoid 100kg of CO₂ emissions"),
                isUnlocked: stats.co2Avoided >= 100,
                progress: min(1, stats.co2Avoided / 100)
            ),
        ]
    }
}
