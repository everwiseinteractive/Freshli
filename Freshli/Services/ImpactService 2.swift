import Foundation
import SwiftData

// MARK: - ImpactService
/// Calculates user impact statistics from pantry data

@MainActor
final class ImpactService {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Impact Stats
    
    struct ImpactStats {
        var itemsSaved: Int
        var itemsShared: Int
        var itemsDonated: Int
        var mealsCreated: Int
        var moneySaved: Double
        var co2Avoided: Double
        
        var totalImpactItems: Int {
            itemsSaved + itemsShared + itemsDonated
        }
    }
    
    /// Calculate current impact statistics
    func calculateStats() -> ImpactStats {
        // Fetch consumed items (saved from waste)
        let savedDescriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate<FreshliItem> { $0.isConsumed }
        )
        let savedCount = (try? modelContext.fetchCount(savedDescriptor)) ?? 0
        
        // Fetch shared items
        let sharedDescriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate<FreshliItem> { $0.isShared }
        )
        let sharedCount = (try? modelContext.fetchCount(sharedDescriptor)) ?? 0
        
        // Fetch donated items
        let donatedDescriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate<FreshliItem> { $0.isDonated }
        )
        let donatedCount = (try? modelContext.fetchCount(donatedDescriptor)) ?? 0
        
        // Fetch user profile for meals created
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profile = try? modelContext.fetch(profileDescriptor).first
        let mealsCreated = profile?.mealsCreated ?? 0
        
        // Calculate estimates
        // Average food item costs ~$3.50
        let moneySaved = Double(savedCount) * 3.50
        
        // Average CO2 footprint per food item: ~2.5 kg CO2
        let co2Avoided = Double(savedCount + sharedCount + donatedCount) * 2.5
        
        return ImpactStats(
            itemsSaved: savedCount,
            itemsShared: sharedCount,
            itemsDonated: donatedCount,
            mealsCreated: mealsCreated,
            moneySaved: moneySaved,
            co2Avoided: co2Avoided
        )
    }
    
    // MARK: - Milestones
    
    struct Milestone {
        let title: String
        let icon: String
        let threshold: Int
        let isUnlocked: Bool
        let description: String
    }
    
    /// Get milestones based on current stats
    func milestones(for stats: ImpactStats) -> [Milestone] {
        [
            Milestone(
                title: "First Step",
                icon: "leaf.fill",
                threshold: 1,
                isUnlocked: stats.itemsSaved >= 1,
                description: "Saved your first item from waste"
            ),
            Milestone(
                title: "Waste Warrior",
                icon: "shield.fill",
                threshold: 10,
                isUnlocked: stats.itemsSaved >= 10,
                description: "Saved 10 items from the landfill"
            ),
            Milestone(
                title: "Eco Champion",
                icon: "star.fill",
                threshold: 50,
                isUnlocked: stats.itemsSaved >= 50,
                description: "Prevented 50 items from going to waste"
            ),
            Milestone(
                title: "Planet Protector",
                icon: "globe.americas.fill",
                threshold: 100,
                isUnlocked: stats.itemsSaved >= 100,
                description: "100 items saved! Your impact is incredible"
            ),
            Milestone(
                title: "Community Hero",
                icon: "heart.fill",
                threshold: 10,
                isUnlocked: stats.itemsShared >= 10,
                description: "Shared 10 items with your community"
            ),
            Milestone(
                title: "Generous Giver",
                icon: "gift.fill",
                threshold: 10,
                isUnlocked: stats.itemsDonated >= 10,
                description: "Donated 10 items to those in need"
            )
        ]
    }
    
    // MARK: - Leaderboard Position (Simulated)
    
    /// Get user's community ranking (mock data for now)
    func getCommunityRanking() -> (position: Int, total: Int, percentile: Int) {
        let stats = calculateStats()
        let totalItems = stats.totalImpactItems
        
        // Simulate ranking based on total impact
        let position = max(1, 150 - (totalItems * 2))
        let total = 500
        let percentile = max(1, 100 - (totalItems * 2))
        
        return (position, total, percentile)
    }
}
