import os

enum PSLogCategory: String {
    case auth, sync, pantry, community, notifications, impact, ui, performance, lifecycle, recipe, general, widget
}

struct PSLogger {
    private let logger: Logger

    init(category: PSLogCategory) {
        self.logger = Logger(subsystem: "com.everwise.PantryShare", category: category.rawValue)
    }

    func debug(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    /// Log with automatic redaction of potentially sensitive values
    func sensitive(_ message: String) {
        logger.debug("\(message, privacy: .private)")
    }

    // Convenience static loggers
    static let auth = PSLogger(category: .auth)
    static let sync = PSLogger(category: .sync)
    static let pantry = PSLogger(category: .pantry)
    static let community = PSLogger(category: .community)
    static let notifications = PSLogger(category: .notifications)
    static let impact = PSLogger(category: .impact)
    static let ui = PSLogger(category: .ui)
    static let performance = PSLogger(category: .performance)
    static let lifecycle = PSLogger(category: .lifecycle)
    static let recipe = PSLogger(category: .recipe)
    static let general = PSLogger(category: .general)
    static let widget = PSLogger(category: .widget)
}
