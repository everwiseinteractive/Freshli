import SwiftUI
import SwiftData

// MARK: - CelebrationManager
// Central coordinator for triggering and queuing celebrations
// Tracks first-time events via UserDefaults, checks milestone thresholds

@Observable @MainActor
final class CelebrationManager {
    var activeCelebration: CelebrationType?
    var celebrationQueue: [CelebrationType] = []
    var isPresenting = false

    // MARK: - First-Time Event Keys
    private let defaults = UserDefaults.standard
    private static let firstItemKey = "celebration_firstItemAdded"
    private static let firstSaveKey = "celebration_firstFoodSaved"
    private static let firstShareKey = "celebration_firstShare"
    private static let firstDonationKey = "celebration_firstDonation"
    private static let lastStreakDateKey = "celebration_lastStreakDate"
    private static let currentStreakKey = "celebration_currentStreak"
    private static let lastWeeklyRecapKey = "celebration_lastWeeklyRecap"
    private static let unlockedMilestonesKey = "celebration_unlockedMilestones"

    // MARK: - Fire-and-Forget Wrappers
    // Synchronous entry points for SwiftUI views that call from non-async contexts.
    // Each schedules the underlying async work on the main actor.

    func fireItemAdded(modelContext: ModelContext) {
        Task { await self.onItemAdded(modelContext: modelContext) }
    }

    func fireFoodSaved(modelContext: ModelContext) {
        Task { await self.onFoodSaved(modelContext: modelContext) }
    }

    func fireShareCompleted(itemName: String, modelContext: ModelContext) {
        Task { await self.onShareCompleted(itemName: itemName, modelContext: modelContext) }
    }

    func fireDonationCompleted(itemName: String, modelContext: ModelContext) {
        Task { await self.onDonationCompleted(itemName: itemName, modelContext: modelContext) }
    }

    // MARK: - Trigger: Item Added to Pantry

    func onItemAdded(modelContext: ModelContext) async {
        // Check "First Item Added" — one-time celebration
        if !defaults.bool(forKey: Self.firstItemKey) {
            defaults.set(true, forKey: Self.firstItemKey)
            queueCelebration(.firstItemAdded)
            return
        }

        // Check streak
        await updateStreak()

        // Check milestones
        await checkMilestones(modelContext: modelContext)
    }

    // MARK: - Trigger: Item Consumed (Food Saved)

    func onFoodSaved(modelContext: ModelContext) async {
        if !defaults.bool(forKey: Self.firstSaveKey) {
            defaults.set(true, forKey: Self.firstSaveKey)
            queueCelebration(.firstFoodSaved)
            return
        }

        await updateStreak()
        await checkMilestones(modelContext: modelContext)
    }

    // MARK: - Trigger: Recipe Matched

    func onRecipeMatch(recipeName: String) {
        queueCelebration(.recipeMatchSuccess(recipeName: recipeName))
    }

    // MARK: - Trigger: Share Completed

    func onShareCompleted(itemName: String, modelContext: ModelContext) async {
        if !defaults.bool(forKey: Self.firstShareKey) {
            defaults.set(true, forKey: Self.firstShareKey)
        }
        queueCelebration(.shareCompleted(itemName: itemName))
        await checkMilestones(modelContext: modelContext)
    }

    // MARK: - Trigger: Donation Completed

    func onDonationCompleted(itemName: String, modelContext: ModelContext) async {
        if !defaults.bool(forKey: Self.firstDonationKey) {
            defaults.set(true, forKey: Self.firstDonationKey)
        }
        queueCelebration(.donationCompleted(itemName: itemName))
        await checkMilestones(modelContext: modelContext)
    }

    // MARK: - Trigger: Weekly Recap

    func checkWeeklyRecap(modelContext: ModelContext) async {
        let lastRecap = defaults.object(forKey: Self.lastWeeklyRecapKey) as? Date ?? .distantPast
        guard Calendar.current.dateComponents([.day], from: lastRecap, to: Date()).day ?? 0 >= 7 else { return }

        let service = ImpactService(modelContext: modelContext)
        let stats = service.calculateStats()
        guard stats.itemsSaved > 0 else { return }

        defaults.set(Date(), forKey: Self.lastWeeklyRecapKey)
        queueCelebration(.weeklyRecap(
            saved: stats.itemsSaved,
            shared: stats.itemsShared,
            co2: stats.co2Avoided,
            money: stats.moneySaved
        ))
    }

    // MARK: - Streak Tracking

    private func updateStreak() async {
        let today = Calendar.current.startOfDay(for: Date())
        let lastDate = defaults.object(forKey: Self.lastStreakDateKey) as? Date ?? .distantPast
        let lastDay = Calendar.current.startOfDay(for: lastDate)

        let daysDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

        var streak = defaults.integer(forKey: Self.currentStreakKey)

        if daysDiff == 0 {
            // Same day — no streak update
            return
        } else if daysDiff == 1 {
            // Consecutive day
            streak += 1
        } else {
            // Streak broken
            streak = 1
        }

        defaults.set(today, forKey: Self.lastStreakDateKey)
        defaults.set(streak, forKey: Self.currentStreakKey)

        // Celebrate at 3, 7, 14, 30 day streaks
        if [3, 7, 14, 30].contains(streak) {
            queueCelebration(.expiryRescueStreak(count: streak))
        }
    }

    // MARK: - Milestone Checking

    private func checkMilestones(modelContext: ModelContext) async {
        let service = ImpactService(modelContext: modelContext)
        let stats = service.calculateStats()
        let milestones = service.milestones(for: stats)
        var unlocked = Set(defaults.stringArray(forKey: Self.unlockedMilestonesKey) ?? [])

        for milestone in milestones where milestone.isUnlocked {
            if !unlocked.contains(milestone.title) {
                unlocked.insert(milestone.title)
                defaults.set(Array(unlocked), forKey: Self.unlockedMilestonesKey)
                queueCelebration(.achievementUnlock(
                    title: milestone.title,
                    icon: milestone.icon
                ))
                return // Only one milestone per action
            }
        }

        // Community impact at 10, 25, 50 total shared+donated
        let total = stats.itemsShared + stats.itemsDonated
        for threshold in [10, 25, 50] {
            let key = "community_impact_\(threshold)"
            if total >= threshold && !unlocked.contains(key) {
                unlocked.insert(key)
                defaults.set(Array(unlocked), forKey: Self.unlockedMilestonesKey)
                queueCelebration(.communityImpact(totalItems: total, neighbors: max(3, total / 3)))
                return
            }
        }
    }

    // MARK: - Queue Management

    private func queueCelebration(_ type: CelebrationType) {
        if isPresenting {
            celebrationQueue.append(type)
        } else {
            presentCelebration(type)
        }
    }

    private func presentCelebration(_ type: CelebrationType) {
        activeCelebration = type
        isPresenting = true
        FreshliHapticManager.shared.celebrationHaptic(intensity: type.intensity)
    }

    func dismissCelebration() {
        withAnimation(PSMotion.freshliCurve) {
            activeCelebration = nil
            isPresenting = false
        }

        // Present next queued celebration after brief pause
        if !celebrationQueue.isEmpty {
            let next = celebrationQueue.removeFirst()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                self.presentCelebration(next)
            }
        }
    }
}
