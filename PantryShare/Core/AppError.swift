import Foundation

enum AppError: LocalizedError {
    case saveFailed
    case deleteFailed
    case syncFailed
    case networkUnavailable
    case authRequired
    case listingClaimFailed
    case listingCreateFailed
    case notificationPermissionDenied
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return String(localized: "Unable to save your changes. Please try again.")
        case .deleteFailed:
            return String(localized: "Unable to delete this item. Please try again.")
        case .syncFailed:
            return String(localized: "Sync is temporarily unavailable. Your changes are saved locally.")
        case .networkUnavailable:
            return String(localized: "No internet connection. Your changes will sync when you're back online.")
        case .authRequired:
            return String(localized: "Please sign in to use this feature.")
        case .listingClaimFailed:
            return String(localized: "This listing may have already been claimed. Please try another.")
        case .listingCreateFailed:
            return String(localized: "Unable to create your listing. Please try again.")
        case .notificationPermissionDenied:
            return String(localized: "Notifications are disabled. Enable them in Settings to get expiry reminders.")
        case .unknown:
            return String(localized: "Something went wrong. Please try again.")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "Check your internet connection and try again.")
        case .notificationPermissionDenied:
            return String(localized: "Open Settings → Freshli → Notifications to enable.")
        case .authRequired:
            return String(localized: "Sign in from the Profile tab to unlock all features.")
        default:
            return nil
        }
    }
}
