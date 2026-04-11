import Foundation
import os

// MARK: - Rescue Streak Service
// Duolingo-style daily streak mechanic. Every day a user rescues food
// (consumes, shares, or completes a recipe) their streak grows.
// Miss a day and it resets to zero. Longest-ever streak is preserved forever.

@MainActor
final class RescueStreakService {

    static let shared = RescueStreakService()
    private init() {}

    private let logger = Logger(subsystem: "com.freshli.app", category: "RescueStreak")

    // MARK: - UserDefaults Keys

    private let currentKey   = "rescue_streak_current"
    private let longestKey   = "rescue_streak_longest"
    private let lastDateKey  = "rescue_streak_last_date"
    private let totalDaysKey = "rescue_streak_total_days"

    // MARK: - Public Read Properties

    var currentStreak: Int  { UserDefaults.standard.integer(forKey: currentKey) }
    var longestStreak: Int  { UserDefaults.standard.integer(forKey: longestKey) }
    var totalDaysActive: Int { UserDefaults.standard.integer(forKey: totalDaysKey) }

    var lastActivityDate: Date? {
        UserDefaults.standard.object(forKey: lastDateKey) as? Date
    }

    /// Whether the user has already rescued food today (streak-wise).
    var hasActivityToday: Bool {
        guard let last = lastActivityDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: - Record Activity

    struct StreakResult {
        let newStreak: Int
        let streakGrew: Bool    // true when the count just increased
        let isNew: Bool          // true when this is the very first day
        let hitMilestone: Int?  // 7, 14, 30, 50, 100 …
    }

    /// Call this whenever the user rescues food. Thread-safe (MainActor).
    @discardableResult
    func recordActivity() -> StreakResult {
        let cal = Calendar.current
        let today = Date()
        let defaults = UserDefaults.standard

        let oldStreak = currentStreak

        if hasActivityToday {
            // Already recorded today — no change
            return StreakResult(newStreak: oldStreak, streakGrew: false, isNew: false, hitMilestone: nil)
        }

        let isConsecutive: Bool
        if let last = lastActivityDate {
            // Yesterday = consecutive; any earlier = broken streak
            let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
            let lastDay   = cal.startOfDay(for: last)
            isConsecutive = lastDay >= yesterday
        } else {
            isConsecutive = false
        }

        let newStreak = isConsecutive ? oldStreak + 1 : 1
        let isNew = oldStreak == 0 && newStreak == 1

        defaults.set(newStreak, forKey: currentKey)
        defaults.set(today, forKey: lastDateKey)
        defaults.set(totalDaysActive + 1, forKey: totalDaysKey)

        // Update longest streak record
        if newStreak > longestStreak {
            defaults.set(newStreak, forKey: longestKey)
        }

        // Also keep backward-compatible key for HomeView streakStrip
        defaults.set(newStreak, forKey: "celebration_currentStreak")
        defaults.set(today, forKey: "celebration_lastStreakDate")

        let milestone = streakMilestone(for: newStreak)
        logger.info("RescueStreak: \(newStreak) days (grew=\(newStreak > oldStreak))")

        return StreakResult(
            newStreak: newStreak,
            streakGrew: newStreak > oldStreak,
            isNew: isNew,
            hitMilestone: milestone
        )
    }

    // MARK: - Helpers

    private let milestones = [3, 7, 14, 30, 50, 100, 365]

    private func streakMilestone(for streak: Int) -> Int? {
        milestones.first { $0 == streak }
    }

    /// Human-readable label for a streak milestone celebration toast.
    func milestoneMessage(for streak: Int) -> String {
        switch streak {
        case 3:   return "🔥 3-day streak! You're on fire!"
        case 7:   return "🔥 One full week! You're a Rescue Hero!"
        case 14:  return "🔥 14 days! Incredible dedication!"
        case 30:  return "🌟 30-day streak! You're a Legend!"
        case 50:  return "🏆 50 days! Absolute zero-waste warrior!"
        case 100: return "👑 100-day streak! Hall of fame!"
        case 365: return "🌍 A full year! Earth thanks you!"
        default:  return "🔥 \(streak)-day streak! Keep it up!"
        }
    }
}
