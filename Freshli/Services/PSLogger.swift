import Foundation
import os

// MARK: - PSLogger
/// Structured logging with os.Logger

struct PSLogger {
    
    enum Category: String {
        case app = "App"
        case auth = "Auth"
        case sync = "Sync"
        case pantry = "Pantry"
        case network = "Network"
        case ui = "UI"
    }
    
    private let logger: Logger
    
    init(category: Category) {
        self.logger = Logger(subsystem: "com.freshli.app", category: category.rawValue)
    }
    
    func debug(_ message: String) {
        logger.debug("\(message)")
    }
    
    func info(_ message: String) {
        logger.info("\(message)")
    }
    
    func warning(_ message: String) {
        logger.warning("\(message)")
    }
    
    func error(_ message: String) {
        logger.error("\(message)")
    }
    
    // MARK: - Predefined Loggers
    
    static let app = PSLogger(category: .app)
    static let auth = PSLogger(category: .auth)
    static let sync = PSLogger(category: .sync)
    static let pantry = PSLogger(category: .pantry)
    static let network = PSLogger(category: .network)
    static let ui = PSLogger(category: .ui)
}
