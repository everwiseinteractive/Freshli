import Foundation
import UserNotifications

@Observable
final class NotificationService {
    private(set) var isAuthorized = false

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func scheduleExpiryReminder(for item: PantryItem, daysBefore: Int = 1) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Expiring Soon")
        content.body = String(localized: "\(item.name) expires \(item.expiryDate.expiryDisplayText). Use it, share it, or donate it!")
        content.sound = .default
        content.categoryIdentifier = "EXPIRY_REMINDER"

        guard let triggerDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: item.expiryDate) else { return }

        let now = Date()
        guard triggerDate > now else { return }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "expiry-\(item.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func cancelReminder(for item: PantryItem) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["expiry-\(item.id.uuidString)"])
    }

    func scheduleRemindersForAllItems(_ items: [PantryItem], daysBefore: Int = 1) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in items where item.isActive {
            scheduleExpiryReminder(for: item, daysBefore: daysBefore)
        }
    }

    // MARK: - Community Notifications

    /// Schedule a timed reminder for community actions (e.g., pickup claimed item).
    func scheduleCommunityReminder(title: String, body: String, delayHours: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "COMMUNITY_REMINDER"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(delayHours * 3600),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "community-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notify when someone claims the user's listing.
    func notifyListingClaimed(itemName: String) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Someone wants your \(itemName)!")
        content.body = String(localized: "A community member claimed your listing. Check the app for details.")
        content.sound = .default
        content.categoryIdentifier = "LISTING_CLAIMED"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "claimed-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Register Categories

    func registerCategories() {
        let cookAction = UNNotificationAction(identifier: "COOK", title: String(localized: "Cook It"), options: .foreground)
        let shareAction = UNNotificationAction(identifier: "SHARE", title: String(localized: "Share It"), options: .foreground)
        let donateAction = UNNotificationAction(identifier: "DONATE", title: String(localized: "Donate It"), options: .foreground)

        let expiryCategory = UNNotificationCategory(
            identifier: "EXPIRY_REMINDER",
            actions: [cookAction, shareAction, donateAction],
            intentIdentifiers: [],
            options: []
        )

        let viewAction = UNNotificationAction(identifier: "VIEW_LISTING", title: String(localized: "View Listing"), options: .foreground)

        let communityCategory = UNNotificationCategory(
            identifier: "COMMUNITY_REMINDER",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        let claimedCategory = UNNotificationCategory(
            identifier: "LISTING_CLAIMED",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            expiryCategory,
            communityCategory,
            claimedCategory
        ])
    }
}
