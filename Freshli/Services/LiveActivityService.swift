import ActivityKit
import Foundation
import os

// MARK: - Live Activity Service
// Manages all Freshli Live Activities:
//   1. Expiring Soon — persistent Lock Screen activity with green→amber progress
//   2. Community Claim — pickup distance + claim code in Dynamic Island
//   3. Recipe Timer — current step + countdown in Dynamic Island

@Observable @MainActor
final class LiveActivityService {

    private let logger = PSLogger(category: .lifecycle)

    // MARK: - Availability

    func areActivitiesAvailable() -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Scenario 1: Expiring Soon

    /// Start an expiry Live Activity for an item with <6 hours remaining.
    /// The progress bar slowly transitions from green (1.0) to amber (0.0).
    @discardableResult
    func startExpirySoon(
        itemName: String,
        category: String,
        quantity: String,
        minutesRemaining: Int,
        expiryDate: Date
    ) -> Activity<FreshliExpiryAttributes>? {
        guard areActivitiesAvailable() else {
            logger.debug("Live Activities not available on this device")
            return nil
        }

        // Only one expiry activity at a time
        let existing = Activity<FreshliExpiryAttributes>.activities
        guard existing.isEmpty else {
            logger.debug("Expiry activity already running")
            return nil
        }

        let attributes = FreshliExpiryAttributes(
            itemName: itemName,
            category: category,
            quantity: quantity
        )

        let totalMinutes = max(minutesRemaining, 1)
        let progress = Double(totalMinutes) / 360.0 // 6 hours = 360 min

        let state = FreshliExpiryAttributes.ContentState(
            progress: min(progress, 1.0),
            minutesRemaining: totalMinutes,
            expiryDate: expiryDate,
            status: "expiring"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: expiryDate),
                pushType: nil
            )
            logger.info("Started expiry activity for \(itemName): \(activity.id)")
            return activity
        } catch {
            logger.error("Failed to start expiry activity: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update the expiry progress (call periodically, e.g. every 5 minutes).
    func updateExpiryProgress(minutesRemaining: Int, expiryDate: Date) async {
        let progress = Double(max(minutesRemaining, 0)) / 360.0
        let status = minutesRemaining <= 0 ? "expired" : "expiring"

        let state = FreshliExpiryAttributes.ContentState(
            progress: min(progress, 1.0),
            minutesRemaining: max(minutesRemaining, 0),
            expiryDate: expiryDate,
            status: status
        )

        for activity in Activity<FreshliExpiryAttributes>.activities {
            await activity.update(.init(state: state, staleDate: expiryDate))
        }
    }

    /// Mark an expiring item as rescued (consumed, shared, or donated).
    func markExpiryRescued(activityID: String) async {
        let state = FreshliExpiryAttributes.ContentState(
            progress: 0,
            minutesRemaining: 0,
            expiryDate: .now,
            status: "rescued"
        )

        for activity in Activity<FreshliExpiryAttributes>.activities where activity.id == activityID {
            await activity.update(.init(state: state, staleDate: nil))
            try? await Task.sleep(for: .seconds(30))
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .default)
        }
    }

    // MARK: - Scenario 2: Community Claim (Pickup)

    /// Start a claim activity when the user begins traveling to pick up a shared item.
    @discardableResult
    func startClaim(
        itemName: String,
        category: String,
        claimCode: String,
        pickupLocation: String,
        sharerName: String,
        distanceMeters: Double,
        etaMinutes: Int
    ) -> Activity<FreshliClaimAttributes>? {
        guard areActivitiesAvailable() else {
            logger.debug("Live Activities not available on this device")
            return nil
        }

        let attributes = FreshliClaimAttributes(
            itemName: itemName,
            category: category,
            claimCode: claimCode,
            pickupLocation: pickupLocation,
            sharerName: sharerName
        )

        let state = FreshliClaimAttributes.ContentState(
            distanceMeters: distanceMeters,
            etaMinutes: etaMinutes,
            status: "en_route"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            logger.info("Started claim activity for \(itemName): \(activity.id)")
            return activity
        } catch {
            logger.error("Failed to start claim activity: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update distance and ETA as the user moves toward the pickup.
    func updateClaimProgress(distanceMeters: Double, etaMinutes: Int) async {
        let status: String
        if distanceMeters < 50 {
            status = "arrived"
        } else if distanceMeters < 200 {
            status = "arriving"
        } else {
            status = "en_route"
        }

        let state = FreshliClaimAttributes.ContentState(
            distanceMeters: distanceMeters,
            etaMinutes: etaMinutes,
            status: status
        )

        for activity in Activity<FreshliClaimAttributes>.activities {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// Mark a claim as collected and end the activity.
    func markClaimCollected(activityID: String) async {
        let state = FreshliClaimAttributes.ContentState(
            distanceMeters: 0,
            etaMinutes: 0,
            status: "collected"
        )

        for activity in Activity<FreshliClaimAttributes>.activities where activity.id == activityID {
            await activity.update(.init(state: state, staleDate: nil))
            try? await Task.sleep(for: .seconds(15))
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .default)
        }
    }

    // MARK: - Scenario 3: Recipe Timer

    /// Start a recipe timer Live Activity.
    @discardableResult
    func startRecipeTimer(
        recipeName: String,
        recipeEmoji: String,
        currentStep: Int,
        totalSteps: Int,
        stepDescription: String,
        stepDurationSeconds: Int
    ) -> Activity<FreshliRecipeTimerAttributes>? {
        guard areActivitiesAvailable() else {
            logger.debug("Live Activities not available on this device")
            return nil
        }

        let attributes = FreshliRecipeTimerAttributes(
            recipeName: recipeName,
            recipeEmoji: recipeEmoji
        )

        let timerEnd = Date.now.addingTimeInterval(TimeInterval(stepDurationSeconds))

        let state = FreshliRecipeTimerAttributes.ContentState(
            currentStep: currentStep,
            totalSteps: totalSteps,
            stepDescription: stepDescription,
            timerEnd: timerEnd,
            stepDurationSeconds: stepDurationSeconds,
            status: "cooking"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: timerEnd),
                pushType: nil
            )
            logger.info("Started recipe timer for \(recipeName): \(activity.id)")
            return activity
        } catch {
            logger.error("Failed to start recipe timer: \(error.localizedDescription)")
            return nil
        }
    }

    /// Advance to the next recipe step with a new timer.
    func advanceRecipeStep(
        currentStep: Int,
        totalSteps: Int,
        stepDescription: String,
        stepDurationSeconds: Int
    ) async {
        let timerEnd = Date.now.addingTimeInterval(TimeInterval(stepDurationSeconds))
        let status = currentStep > totalSteps ? "done" : "cooking"

        let state = FreshliRecipeTimerAttributes.ContentState(
            currentStep: min(currentStep, totalSteps),
            totalSteps: totalSteps,
            stepDescription: stepDescription,
            timerEnd: timerEnd,
            stepDurationSeconds: stepDurationSeconds,
            status: status
        )

        for activity in Activity<FreshliRecipeTimerAttributes>.activities {
            await activity.update(.init(state: state, staleDate: timerEnd))
        }
    }

    /// End the recipe timer (recipe complete or cancelled).
    func endRecipeTimer(activityID: String) async {
        for activity in Activity<FreshliRecipeTimerAttributes>.activities where activity.id == activityID {
            let finalState = FreshliRecipeTimerAttributes.ContentState(
                currentStep: 0,
                totalSteps: 0,
                stepDescription: "Done!",
                timerEnd: .now,
                stepDurationSeconds: 0,
                status: "done"
            )
            await activity.update(.init(state: finalState, staleDate: nil))
            try? await Task.sleep(for: .seconds(10))
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .default)
        }
    }

    // MARK: - Legacy Support

    /// Start an expiry rescue Live Activity (legacy API — wraps new expiry method).
    @discardableResult
    func startExpiryRescue(
        itemName: String,
        category: String,
        quantity: String,
        hoursRemaining: Int
    ) -> Activity<FreshliWidgetsAttributes>? {
        guard areActivitiesAvailable() else {
            logger.debug("Live Activities not available on this device")
            return nil
        }

        let attributes = FreshliWidgetsAttributes(
            itemName: itemName,
            category: category,
            quantity: quantity
        )

        let state = FreshliWidgetsAttributes.ContentState(
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

    /// Update a Live Activity when the item is rescued.
    func markRescued(activityID: String) async {
        let state = FreshliWidgetsAttributes.ContentState(
            hoursRemaining: 0,
            status: "rescued"
        )

        for activity in Activity<FreshliWidgetsAttributes>.activities where activity.id == activityID {
            await activity.update(.init(state: state, staleDate: nil))
            try? await Task.sleep(for: .seconds(30))
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: .default)
        }
    }

    // MARK: - End All

    /// End all active Freshli Live Activities.
    func endAll() async {
        let rescuedState = FreshliWidgetsAttributes.ContentState(hoursRemaining: 0, status: "rescued")
        for activity in Activity<FreshliWidgetsAttributes>.activities {
            await activity.end(.init(state: rescuedState, staleDate: nil), dismissalPolicy: .immediate)
        }

        let expiryState = FreshliExpiryAttributes.ContentState(
            progress: 0, minutesRemaining: 0, expiryDate: .now, status: "rescued"
        )
        for activity in Activity<FreshliExpiryAttributes>.activities {
            await activity.end(.init(state: expiryState, staleDate: nil), dismissalPolicy: .immediate)
        }

        let claimState = FreshliClaimAttributes.ContentState(
            distanceMeters: 0, etaMinutes: 0, status: "collected"
        )
        for activity in Activity<FreshliClaimAttributes>.activities {
            await activity.end(.init(state: claimState, staleDate: nil), dismissalPolicy: .immediate)
        }

        let recipeState = FreshliRecipeTimerAttributes.ContentState(
            currentStep: 0, totalSteps: 0, stepDescription: "", timerEnd: .now,
            stepDurationSeconds: 0, status: "done"
        )
        for activity in Activity<FreshliRecipeTimerAttributes>.activities {
            await activity.end(.init(state: recipeState, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    /// Check pantry items and start Live Activities for urgently expiring ones.
    func checkAndStartActivities(items: [(name: String, category: String, quantity: String, hoursRemaining: Int)]) {
        let existing = Activity<FreshliWidgetsAttributes>.activities
        guard existing.isEmpty else { return }

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
