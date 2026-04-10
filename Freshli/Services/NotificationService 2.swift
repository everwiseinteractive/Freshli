import Foundation
import UserNotifications

// MARK: - NotificationService
/// Manages local notifications for expiring items

@MainActor
final class NotificationService {
    
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            PSLogger.app.error("Notification authorization failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Schedule Notifications
    
    func scheduleReminder(for item: FreshliItem, daysBeforeExpiry: Int = 1) {
        let content = UNMutableNotificationContent()
        content.title = "Item Expiring Soon"
        content.body = "\(item.name) expires \(item.expiryDate.expiryDisplayText)"
        content.sound = .default
        content.categoryIdentifier = "EXPIRING_ITEM"
        content.userInfo = ["itemId": item.id.uuidString]
        
        // Calculate trigger date
        let calendar = Calendar.current
        let reminderDate = calendar.date(byAdding: .day, value: -daysBeforeExpiry, to: item.expiryDate) ?? item.expiryDate
        
        guard reminderDate > Date() else { return }
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                PSLogger.app.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelReminder(for item: FreshliItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }
    
    func rescheduleReminder(for item: FreshliItem) {
        cancelReminder(for: item)
        scheduleReminder(for: item)
    }
    
    // MARK: - Batch Operations
    
    func scheduleReminders(for items: [FreshliItem]) {
        items.forEach { scheduleReminder(for: $0) }
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
