import os

enum PSLogCategory: String {
    case auth, sync, pantry, community, notifications, impact, ui, performance, lifecycle, recipe, general, widget, shopping
}

struct PSLogger: Sendable {
    private let logger: Logger

    nonisolated init(category: PSLogCategory) {
        self.logger = Logger(subsystem: "com.everwise.Freshli", category: category.rawValue)
    }

    nonisolated func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    nonisolated func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    nonisolated func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    nonisolated func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    /// Log with automatic redaction of potentially sensitive values
    nonisolated func sensitive(_ message: String) {
        logger.debug("\(message, privacy: .private)")
    }

    // Convenience static loggers
    nonisolated static let auth = PSLogger(category: .auth)
    nonisolated static let sync = PSLogger(category: .sync)
    nonisolated static let pantry = PSLogger(category: .pantry)
    nonisolated static let community = PSLogger(category: .community)
    nonisolated static let notifications = PSLogger(category: .notifications)
    nonisolated static let impact = PSLogger(category: .impact)
    nonisolated static let ui = PSLogger(category: .ui)
    nonisolated static let performance = PSLogger(category: .performance)
    nonisolated static let lifecycle = PSLogger(category: .lifecycle)
    nonisolated static let recipe = PSLogger(category: .recipe)
    nonisolated static let general = PSLogger(category: .general)
    nonisolated static let widget = PSLogger(category: .widget)
    nonisolated static let shopping = PSLogger(category: .shopping)
}
