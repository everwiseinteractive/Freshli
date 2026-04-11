import Foundation
import UIKit
import UserNotifications

@Observable @MainActor
final class NotificationService {
    private(set) var isAuthorized = false

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                PSLogger.notifications.info("Notification authorization granted")
            } else {
                PSLogger.notifications.warning("Notification authorization denied by user")
            }
        } catch {
            isAuthorized = false
            PSLogger.notifications.error("Authorization request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Expiry Reminders

    /// Schedule an expiry reminder for a single item. Notification identifier is deterministic based on item ID.
    func scheduleExpiryReminder(for item: FreshliItem, daysBefore: Int = 1) {
        guard isAuthorized else {
            PSLogger.notifications.debug("Cannot schedule reminder: not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Expiring Soon")
        content.body = String(localized: "\(item.name) expires \(item.expiryDate.expiryDisplayText). Use it, share it, or donate it!")
        content.sound = .default
        content.categoryIdentifier = "EXPIRY_REMINDER"
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: item.expiryDate) else {
            PSLogger.notifications.error("Failed to calculate trigger date for \(item.name)")
            return
        }

        let now = Date()
        guard triggerDate > now else {
            PSLogger.notifications.debug("Trigger date is in the past for \(item.name), skipping")
            return
        }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // Deterministic identifier based on item ID so we can cancel it later
        let identifier = "expiry-\(item.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                PSLogger.notifications.error("Failed to schedule reminder for \(item.name): \(error.localizedDescription)")
            } else {
                PSLogger.notifications.info("Scheduled reminder for \(item.name) on \(triggerDate)")
            }
        }
    }

    /// Reschedule a reminder when an item's expiry date is edited.
    func rescheduleReminder(for item: FreshliItem, daysBefore: Int = 1) {
        // Cancel the old reminder
        cancelReminder(for: item)
        // Schedule with new date
        scheduleExpiryReminder(for: item, daysBefore: daysBefore)
    }

    /// Cancel a reminder for a specific item (used when item is consumed, shared, donated, or deleted).
    func cancelReminder(for item: FreshliItem) {
        let identifier = "expiry-\(item.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Clear all expired item reminders.
    func clearExpiredReminders(_ items: [FreshliItem]) {
        let now = Date()
        for item in items where item.expiryDate <= now {
            cancelReminder(for: item)
        }
    }

    /// Reschedule reminders for all active items (call after batch operations).
    /// Only removes and re-adds reminders for changed items to avoid notification gaps.
    func scheduleRemindersForAllItems(_ items: [FreshliItem], daysBefore: Int = 1) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let pendingIds = Set(pendingRequests.map { $0.identifier })
            let activeItemIds = Set(items.filter { $0.isActive }.map { "expiry-\($0.id.uuidString)" })

            // Remove notifications for items that are no longer active
            let toRemove = pendingIds.subtracting(activeItemIds)
            if !toRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(toRemove))
                PSLogger.notifications.info("Removed \(toRemove.count) expired notification requests")
            }

            // Add notifications for items that don't have them yet
            let toAdd = activeItemIds.subtracting(pendingIds)
            for item in items where item.isActive && toAdd.contains("expiry-\(item.id.uuidString)") {
                self.scheduleExpiryReminder(for: item, daysBefore: daysBefore)
            }

            if !toAdd.isEmpty {
                PSLogger.notifications.info("Added \(toAdd.count) new notification requests")
            }
        }
    }

    // MARK: - Community Notifications

    /// Schedule a timed reminder for community actions (e.g., pickup claimed item).
    /// Uses a deterministic identifier based on listing ID if provided, otherwise generates one.
    func scheduleCommunityReminder(title: String, body: String, delayHours: Int, listingId: UUID? = nil) {
        guard isAuthorized else {
            PSLogger.notifications.debug("Cannot schedule community reminder: not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "COMMUNITY_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(delayHours * 3600),
            repeats: false
        )

        // Use deterministic identifier based on listing ID if available
        let identifier = listingId.map { "community-listing-\($0.uuidString)" } ?? "community-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                PSLogger.notifications.error("Failed to schedule community reminder: \(error.localizedDescription)")
            } else {
                PSLogger.notifications.info("Scheduled community reminder with ID: \(identifier)")
            }
        }
    }

    /// Notify when someone claims the user's listing.
    func notifyListingClaimed(itemName: String, listingId: UUID? = nil) {
        guard isAuthorized else {
            PSLogger.notifications.debug("Cannot notify listing claimed: not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Someone wants your \(itemName)!")
        content.body = String(localized: "A community member claimed your listing. Check the app for details.")
        content.sound = .default
        content.categoryIdentifier = "LISTING_CLAIMED"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = listingId.map { "claimed-\($0.uuidString)" } ?? "claimed-\(UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                PSLogger.notifications.error("Failed to notify listing claimed: \(error.localizedDescription)")
            } else {
                PSLogger.notifications.info("Sent listing claimed notification for: \(itemName)")
            }
        }
    }

    // MARK: - Register Categories

    /// Register notification categories with proper actions for user interaction.
    func registerCategories() {
        // Expiry reminder actions
        let cookAction = UNNotificationAction(identifier: "COOK", title: String(localized: "Cook It"), options: .foreground)
        let shareAction = UNNotificationAction(identifier: "SHARE", title: String(localized: "Share It"), options: .foreground)
        let donateAction = UNNotificationAction(identifier: "DONATE", title: String(localized: "Donate It"), options: .foreground)
        let dismissAction = UNNotificationAction(identifier: "DISMISS", title: String(localized: "Dismiss"), options: .destructive)

        let expiryCategory = UNNotificationCategory(
            identifier: "EXPIRY_REMINDER",
            actions: [cookAction, shareAction, donateAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Community reminder action
        let viewAction = UNNotificationAction(identifier: "VIEW_LISTING", title: String(localized: "View Listing"), options: .foreground)

        let communityCategory = UNNotificationCategory(
            identifier: "COMMUNITY_REMINDER",
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let claimedCategory = UNNotificationCategory(
            identifier: "LISTING_CLAIMED",
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            expiryCategory,
            communityCategory,
            claimedCategory
        ])
    }
}
