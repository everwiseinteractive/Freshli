import ActivityKit
import Foundation
import os

// MARK: - Live Activity Service
// Manages food expiry rescue Live Activities.
// Starts a Live Activity when a pantry item is about to expire,
// and updates/ends it when the item is consumed, shared, or donated.

@Observable
final class LiveActivityService {

    private let logger = PSLogger(category: .lifecycle)

    /// Check if Live Activities are supported and enabled on this device.
    func areActivitiesAvailable() -> Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        } else {
            return false
        }
    }

    /// Start an expiry rescue Live Activity for a pantry item.
    /// Returns the Activity if successful, nil if Live Activities are unavailable or activation fails.
    @discardableResult
    func startExpiryRescue(
        itemName: String,
        category: String,
        quantity: String,
        hoursRemaining: Int
    ) -> Activity<PantryShareWidgetsAttributes>? {
        guard areActivitiesAvailable() else {
            logger.debug("Live Activities not available on this device")
            return nil
        }

        let attributes = PantryShareWidgetsAttributes(
            itemName: itemName,
            category: category,
            quantity: quantity
        )

        let state = PantryShareWidgetsAttributes.ContentState(
            hoursRemaining: hoursRemaining,
            status: "expiring"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            logger.info("Started expiry rescue for \(itemName): \(activity.id)")
            return activity
        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update a Live Activity when the item is rescued (consumed, shared, or donated).
    func markRescued(activityID: String) async {
        let state = PantryShareWidgetsAttributes.ContentState(
            hoursRemaining: 0,
            status: "rescued"
        )

        for activity in Activity<PantryShareWidgetsAttributes>.activities {
            if activity.id == activityID {
                await activity.update(.init(state: state, staleDate: nil))
                // End after 30 seconds to show the "rescued" state
                try? await Task.sleep(for: .seconds(30))
                await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .default)
                break
            }
        }
    }

    /// End all active expiry rescue activities.
    func endAll() async {
        for activity in Activity<PantryShareWidgetsAttributes>.activities {
            let state = PantryShareWidgetsAttributes.ContentState(
                hoursRemaining: 0,
                status: "rescued"
            )
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    /// Check pantry items and start Live Activities for urgently expiring ones.
    func checkAndStartActivities(items: [(name: String, category: String, quantity: String, hoursRemaining: Int)]) {
        // Only start for items expiring within 24 hours, max 1 at a time
        let existing = Activity<PantryShareWidgetsAttributes>.activities
        guard existing.isEmpty else { return } // Don't stack activities

        if let urgent = items.first(where: { $0.hoursRemaining <= 24 && $0.hoursRemaining > 0 }) {
            startExpiryRescue(
                itemName: urgent.name,
                category: urgent.category,
                quantity: urgent.quantity,
                hoursRemaining: urgent.hoursRemaining
            )
        }
    }
}
