import EventKit
import AppIntents
import UserNotifications
import SwiftUI
import Supabase
import os

// MARK: - Freshli System Sync (Swift 6.3)
// Senior iOS Engineer implementation.
// Bridges Freshli with Apple Calendar, Reminders, Shortcuts (App Intents),
// and Time-Sensitive Notification Interruptions.

private nonisolated let logger = Logger(subsystem: "com.freshli.app", category: "SystemSync")

// MARK: - 1. Calendar Integration — EventActor

/// An actor that owns all EventKit calendar operations, ensuring thread-safe
/// access to the `EKEventStore` singleton.
actor EventActor {
    private let store = EKEventStore()

    /// Request calendar access and sync high-value expiry dates as all-day events.
    /// - Parameters:
    ///   - items: Pantry items whose expiry dates should appear in Calendar.
    ///   - calendarTitle: Name of the dedicated Freshli calendar (created if missing).
    func syncExpiryDates(
        for items: [SupabaseFreshliItem],
        calendarTitle: String = "Freshli Expiry"
    ) async throws {
        // Request write access
        let granted = try await store.requestWriteOnlyAccessToEvents()
        guard granted else {
            logger.warning("Calendar write access denied.")
            throw SystemSyncError.calendarAccessDenied
        }

        // Find or create the Freshli calendar
        let calendar = try freshlCalendar(titled: calendarTitle)

        for item in items {
            // Skip items that already have a synced event (idempotent)
            let predicate = store.predicateForEvents(
                withStart: Calendar.current.startOfDay(for: item.expiryDate),
                end: Calendar.current.date(byAdding: .day, value: 1, to: item.expiryDate) ?? item.expiryDate,
                calendars: [calendar]
            )
            let existing = store.events(matching: predicate)
            let alreadySynced = existing.contains { $0.title == "🥬 \(item.name) expires" }
            guard !alreadySynced else { continue }

            // Create all-day event
            let event = EKEvent(eventStore: store)
            event.title = "🥬 \(item.name) expires"
            event.notes = "Freshli reminder — use \(item.name) before it expires!\nCategory: \(item.category)"
            event.isAllDay = true
            event.startDate = item.expiryDate
            event.endDate = item.expiryDate
            event.calendar = calendar

            // Custom alerts: 1 day before + morning of
            let dayBeforeAlarm = EKAlarm(relativeOffset: -86400) // −24 h
            let morningAlarm   = EKAlarm(relativeOffset: -32400) // −9 h (morning of expiry day)
            event.alarms = [dayBeforeAlarm, morningAlarm]

            try store.save(event, span: .thisEvent)
            logger.info("Synced calendar event for \(item.name)")
        }
    }

    // MARK: Helpers

    private func freshlCalendar(titled title: String) throws -> EKCalendar {
        if let existing = store.calendars(for: .event).first(where: { $0.title == title }) {
            return existing
        }
        let cal = EKCalendar(for: .event, eventStore: store)
        cal.title = title
        cal.cgColor = UIColor(FreshliColor.freshliGreen).cgColor
        // Use the default local calendar source
        if let source = store.defaultCalendarForNewEvents?.source {
            cal.source = source
        }
        try store.saveCalendar(cal, commit: true)
        logger.info("Created Freshli calendar: \(title)")
        return cal
    }
}

// MARK: - 2. Reminders — Push to Reminders

/// Service that creates native iOS Reminders from expiring pantry items.
actor ReminderActor {
    private let store = EKEventStore()

    /// Push a pantry item into the iOS Reminders app as a checklist entry
    /// in a "Freshli — Use Today" list.
    func pushToReminders(
        item: SupabaseFreshliItem,
        listTitle: String = "Freshli — Use Today"
    ) async throws {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            logger.warning("Reminders access denied.")
            throw SystemSyncError.remindersAccessDenied
        }

        let list = try freshliReminderList(titled: listTitle)

        let reminder = EKReminder(eventStore: store)
        reminder.title = "Use \(item.name)"
        reminder.notes = "This item expires today. Open Freshli to find recipe suggestions!"
        reminder.calendar = list
        reminder.priority = Int(EKReminderPriority.high.rawValue)

        // Due today at noon
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 12
        reminder.dueDateComponents = components

        try store.save(reminder, commit: true)
        logger.info("Created reminder for \(item.name)")
    }

    // MARK: Helpers

    private func freshliReminderList(titled title: String) throws -> EKCalendar {
        if let existing = store.calendars(for: .reminder).first(where: { $0.title == title }) {
            return existing
        }
        let list = EKCalendar(for: .reminder, eventStore: store)
        list.title = title
        list.cgColor = UIColor(FreshliColor.freshliGreen).cgColor
        if let source = store.defaultCalendarForNewReminders()?.source {
            list.source = source
        }
        try store.saveCalendar(list, commit: true)
        logger.info("Created Freshli reminder list: \(title)")
        return list
    }
}

// MARK: - 3. App Intents — "What's for Dinner?" Shortcut

/// Siri / Shortcuts intent: "What's for dinner?" queries Freshli's Recipe Rescue
/// suggestions based on items expiring soonest.
struct WhatsForDinnerIntent: AppIntent {
    static var title: LocalizedStringResource { "What's for Dinner?" }
    static var description: IntentDescription {
        IntentDescription(
            "Get a dinner suggestion from Freshli based on items expiring soon.",
            categoryName: "Freshli Recipes"
        )
    }
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let session = try await AppSupabase.client.auth.session
        let userId = session.user.id
        let service = FreshliSupabaseService()

        // Items expiring within 2 days
        let expiring = try await service.fetchExpiringItems(for: userId, within: 2)

        guard !expiring.isEmpty else {
            return .result(dialog: "Your pantry is looking great — nothing's expiring soon! Check Freshli for general recipe ideas.")
        }

        // Build ingredient list from top 5 expiring items
        let ingredients = expiring.prefix(5).map(\.name)
        let ingredientList = ingredients.joined(separator: ", ")

        // Construct a simple suggestion (in production, RecipeService would provide full matches)
        let suggestion: String
        if ingredients.count >= 3 {
            suggestion = "How about a stir-fry with \(ingredientList)? Open Freshli's Recipe Rescue for the full recipe!"
        } else {
            suggestion = "You could use your \(ingredientList) tonight. Open Freshli's Recipe Rescue for recipe ideas!"
        }

        return .result(dialog: "\(suggestion)")
    }
}

// Note: WhatsForDinnerIntent shortcut is registered in FreshliIntents.swift
// (only one AppShortcutsProvider conformance is allowed per app target).

// MARK: - 4. Notification Interruption — Time Sensitive Expiry Alerts

/// Configures and sends expiry notifications at the `timeSensitive` interruption
/// level so they break through Focus modes when food is about to spoil.
struct FreshliTimeSensitiveNotifications {

    /// Schedule a time-sensitive notification for an item expiring within 24 hours.
    static func scheduleExpiryAlert(for item: SupabaseFreshliItem) async throws {
        let center = UNUserNotificationCenter.current()

        // Request authorization including timeSensitive
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else {
            logger.warning("Notification authorization denied.")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "⏰ \(item.name) Expires Today!"
        content.body = "Use it before it goes to waste. Tap to find a quick recipe."
        content.sound = .default
        content.interruptionLevel = .timeSensitive   // Breaks through Focus
        content.relevanceScore = 1.0                 // High priority in summary
        content.categoryIdentifier = "EXPIRY_ALERT"
        content.threadIdentifier = "freshli-expiry-\(item.id)"

        // Trigger at 8 AM on expiry day
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: item.expiryDate)
        dateComponents.hour = 8
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "expiry-\(item.id)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        logger.info("Scheduled time-sensitive alert for \(item.name)")
    }

    /// Batch-schedule alerts for all items expiring within `days`.
    static func scheduleAlerts(for items: [SupabaseFreshliItem], expiringWithinDays days: Int = 1) async {
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        let expiring = items.filter { $0.expiryDate <= cutoff && $0.expiryDate >= Date() }

        for item in expiring {
            do {
                try await scheduleExpiryAlert(for: item)
            } catch {
                logger.error("Failed to schedule alert for \(item.name): \(error)")
            }
        }
    }
}

// MARK: - Errors

enum SystemSyncError: LocalizedError {
    case calendarAccessDenied
    case remindersAccessDenied

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "Freshli needs Calendar access to sync expiry dates. Please enable it in Settings."
        case .remindersAccessDenied:
            return "Freshli needs Reminders access to create checklists. Please enable it in Settings."
        }
    }
}
