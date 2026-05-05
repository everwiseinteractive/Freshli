import Foundation
import AVFoundation
import os

enum ScanResult {
    case barcode(String)
    case receipt([ScannedReceiptItem])
    case error(ScanError)
}

struct ScannedReceiptItem {
    let name: String
    let quantity: Double
    let suggestedCategory: FoodCategory
}

enum ScanError: LocalizedError {
    case cameraUnavailable
    case permissionDenied
    case scanFailed
    case noItemsFound

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: return String(localized: "Camera is not available on this device")
        case .permissionDenied: return String(localized: "Camera permission is required to scan items")
        case .scanFailed: return String(localized: "Unable to scan. Please try again or add manually.")
        case .noItemsFound: return String(localized: "No items found on the receipt. Try adding manually.")
        }
    }
}

@Observable @MainActor
final class ScannerService {
    private let logger = PSLogger(category: .pantry)
    private let barcodeLookup = BarcodeLookupService()

    var isCameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    /// Request camera permission for barcode scanning.
    /// Returns true if permission is granted (or already authorized).
    func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            // User hasn't been asked yet
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            // User denied or restricted access
            logger.warning("Camera permission denied or restricted")
            return false
        @unknown default:
            return false
        }
    }

    /// Look up a barcode against the Open Food Facts product database.
    /// Returns a fully-populated `FreshliItem` (name, brand, category,
    /// storage, sensible shelf-life, barcode persisted) the user can
    /// review and adjust before saving. Throws a `BarcodeLookupService.LookupError`
    /// with a user-friendly localized message when the product can't be
    /// found, the network is unavailable, or the API rate-limits us.
    ///
    /// This replaces the prior 3-product hardcoded dictionary which gave
    /// real users the impression the scanner was broken.
    func lookupBarcode(_ code: String) async throws -> FreshliItem {
        try await barcodeLookup.lookup(barcode: code)
    }

    /// Synchronous variant kept for backward compatibility with call sites
    /// that haven't migrated to the async API yet. Returns `nil` and lets
    /// the caller fall back to manual entry; does not perform the lookup
    /// (the network call must run on the async API). Marked deprecated to
    /// flag remaining call sites.
    @available(*, deprecated, message: "Use the async `lookupBarcode(_:)` overload — this fallback never finds products and is only kept to avoid call-site breakage.")
    func lookupBarcodeSync(_ code: String) -> FreshliItem? {
        guard !code.isEmpty else {
            logger.warning("Barcode is empty")
            return nil
        }
        logger.warning("Synchronous barcode lookup is deprecated — call site should migrate to async lookupBarcode")
        return nil
    }
}
