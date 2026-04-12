import Foundation
import SwiftData
import WidgetKit
import os

// MARK: - Watch Connectivity Service
//
// Bridges pantry data from the iOS app to the Apple Watch companion
// via a shared App Group UserDefaults. The Watch app and its
// complications read from this shared store to display expiry alerts,
// rescue counts, and streak data without needing a WCSession —
// UserDefaults + WidgetKit timeline refresh is simpler, more
// battery-efficient, and works even when the Watch app isn't running.
//
// Called from the same places as WidgetDataService.updateWidgetData()
// — whenever an item is added, consumed, shared, donated, or deleted.

enum WatchConnectivityService {
    /// Shared App Group suite name — must match the suite used in
    /// FreshliWatch/FreshliWatchHomeView.swift and the complication.
    private static let suiteName = "group.everwise.interactive.Freshli"

    private static let logger = Logger(subsystem: "com.freshli.app", category: "WatchSync")

    /// Push the current pantry state to the shared App Group so the
    /// Watch app and complications can read it. Call this whenever
    /// pantry data changes.
    @MainActor
    static func updateWatchData(modelContext: ModelContext) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            logger.warning("WatchSync: App Group suite not available")
            return
        }

        // Fetch active (not consumed/shared/donated) items
        let descriptor = FetchDescriptor<FreshliItem>(
            predicate: #Predicate { !$0.isConsumed && !$0.isShared && !$0.isDonated },
            sortBy: [SortDescriptor(\FreshliItem.expiryDate)]
        )

        do {
            let items = try modelContext.fetch(descriptor)
            let now = Date()
            let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now

            // Expiring within 48h
            let expiringItems = items.filter { $0.expiryDate <= twoDaysFromNow }
            let expiringNames = expiringItems.prefix(5).map(\.name).joined(separator: "|")

            // This week's rescues (consumed + shared + donated)
            let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
            let allItemsDescriptor = FetchDescriptor<FreshliItem>()
            let allItems = try modelContext.fetch(allItemsDescriptor)
            let weeklyRescues = allItems.filter {
                ($0.isConsumed || $0.isShared || $0.isDonated)
            }

            // Streak from UserDefaults (same source as HomeView)
            let streak = UserDefaults.standard.integer(forKey: "celebration_currentStreak")

            // CO₂ estimate (2.5kg base per item)
            let co2 = Double(weeklyRescues.count) * 2.5

            // Write to shared defaults
            defaults.set(weeklyRescues.count, forKey: "watchItemsSaved")
            defaults.set(expiringItems.count, forKey: "watchExpiringCount")
            defaults.set(co2, forKey: "watchCO2Avoided")
            defaults.set(streak, forKey: "watchStreakDays")
            defaults.set(expiringNames, forKey: "watchExpiringNames")

            // Tell WidgetKit to refresh Watch complications
            WidgetCenter.shared.reloadAllTimelines()

            logger.debug("WatchSync: pushed \(weeklyRescues.count) saved, \(expiringItems.count) expiring, streak \(streak)")
        } catch {
            logger.error("WatchSync: fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
