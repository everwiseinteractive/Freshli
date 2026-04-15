import Foundation
@preconcurrency import UserNotifications

// MARK: - FreshliPredictionAlertService

/// Schedules "Gentle Reminder" notifications exactly 24 hours before
/// the AI predicts an item will expire or run out — whichever comes first.
@Observable @MainActor
final class FreshliPredictionAlertService {
    private let logger = PSLogger(category: .notifications)
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Schedule Prediction Alerts

    /// Schedules gentle reminder notifications for all predictions that have a critical date
    /// more than 24 hours from now. Cancels stale alerts for items no longer predicted to be at risk.
    func scheduleAlerts(for predictions: [FreshliPrediction]) {
        let now = Date()
        let calendar = Calendar.current

        // Gather identifiers we're about to schedule
        var scheduledIds: Set<String> = []

        for prediction in predictions {
            let identifier = predictionAlertId(for: prediction.id)
            scheduledIds.insert(identifier)

            // Alert fires 24 hours before the critical date
            guard let alertDate = calendar.date(byAdding: .hour, value: -24, to: prediction.criticalDate),
                  alertDate > now else {
                // Already within 24h or past — schedule an immediate gentle nudge if not already sent
                if prediction.estimatedDaysRemaining <= 1 && prediction.estimatedDaysRemaining >= 0 {
                    scheduleImmediateNudge(for: prediction)
                }
                continue
            }

            let content = buildContent(for: prediction)
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            notificationCenter.add(request) { [logger] error in
                if let error {
                    logger.error("Failed to schedule prediction alert for \(prediction.itemName): \(error.localizedDescription)")
                } else {
                    logger.info("Scheduled prediction alert for \(prediction.itemName) at \(alertDate)")
                }
            }
        }

        // Clean up stale prediction alerts
        cleanupStaleAlerts(keeping: scheduledIds)
    }

    /// Schedule a single alert for one item (e.g., after a prediction refresh).
    func scheduleAlert(for prediction: FreshliPrediction) {
        scheduleAlerts(for: [prediction])
    }

    /// Cancel the prediction alert for a specific item (consumed, refilled, deleted).
    func cancelAlert(for itemId: UUID) {
        let identifier = predictionAlertId(for: itemId)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        logger.debug("Cancelled prediction alert for item \(itemId)")
    }

    /// Cancel all prediction alerts.
    func cancelAllAlerts() {
        notificationCenter.getPendingNotificationRequests { [notificationCenter, logger] requests in
            let predictionIds = requests
                .filter { $0.identifier.hasPrefix("freshli-predict-") }
                .map(\.identifier)

            if !predictionIds.isEmpty {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: predictionIds)
                logger.info("Cancelled \(predictionIds.count) prediction alerts")
            }
        }
    }

    // MARK: - Notification Categories

    /// Registers the prediction reminder notification category with actionable buttons.
    func registerCategory() {
        let refillAction = UNNotificationAction(
            identifier: "FRESHLI_REFILL",
            title: String(localized: "Refill"),
            options: .foreground
        )
        let consumedAction = UNNotificationAction(
            identifier: "FRESHLI_CONSUMED",
            title: String(localized: "Mark Consumed"),
            options: .foreground
        )
        let dismissAction = UNNotificationAction(
            identifier: "FRESHLI_DISMISS",
            title: String(localized: "Dismiss"),
            options: .destructive
        )

        let category = UNNotificationCategory(
            identifier: "FRESHLI_PREDICTION",
            actions: [refillAction, consumedAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Merge with existing categories rather than replacing
        notificationCenter.getNotificationCategories { [notificationCenter] existing in
            var categories = existing
            categories.insert(category)
            notificationCenter.setNotificationCategories(categories)
        }
    }

    // MARK: - Private

    private func predictionAlertId(for itemId: UUID) -> String {
        "freshli-predict-\(itemId.uuidString)"
    }

    private func buildContent(for prediction: FreshliPrediction) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "FRESHLI_PREDICTION"
        content.sound = .default

        let itemName = prediction.itemName

        switch prediction.reason {
        case .expiryBeforeDepletion:
            content.title = String(localized: "Gentle Reminder")
            content.body = String(localized: "\(itemName) is predicted to expire tomorrow. Use it, share it, or donate it!")
        case .depletionBeforeExpiry:
            content.title = String(localized: "Gentle Reminder")
            content.body = String(localized: "You'll likely finish \(itemName) by tomorrow. Time to refill?")
        case .bothSameDay:
            content.title = String(localized: "Gentle Reminder")
            content.body = String(localized: "\(itemName) may run out and expire around the same time — use it up or refill!")
        case .noHistory:
            content.title = String(localized: "Gentle Reminder")
            content.body = String(localized: "\(itemName) may be running low. Check your pantry!")
        }

        // Attach item ID in userInfo so the app can navigate to it
        content.userInfo = ["itemId": prediction.id.uuidString]

        return content
    }

    private func scheduleImmediateNudge(for prediction: FreshliPrediction) {
        let nudgeId = "freshli-predict-nudge-\(prediction.id.uuidString)"
        let content = buildContent(for: prediction)

        // Fire in 30 seconds (avoids duplicate if app just opened)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        let request = UNNotificationRequest(identifier: nudgeId, content: content, trigger: trigger)

        notificationCenter.add(request) { [logger] error in
            if let error {
                logger.error("Failed to schedule immediate nudge: \(error.localizedDescription)")
            }
        }
    }

    private func cleanupStaleAlerts(keeping validIds: Set<String>) {
        notificationCenter.getPendingNotificationRequests { [notificationCenter, logger] requests in
            let staleIds = requests
                .filter { $0.identifier.hasPrefix("freshli-predict-") && !validIds.contains($0.identifier) }
                .map(\.identifier)

            if !staleIds.isEmpty {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: staleIds)
                logger.info("Cleaned up \(staleIds.count) stale prediction alerts")
            }
        }
    }
}
