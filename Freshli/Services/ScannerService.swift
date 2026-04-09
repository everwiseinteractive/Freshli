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

@Observable
final class ScannerService {
    private let logger = PSLogger(category: .pantry)

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

    /// Look up a barcode and return the product information if available.
    /// For unknown barcodes, returns nil so the user can enter details manually.
    /// Note: In production, this should integrate with a product database API
    /// (e.g., Open Food Facts, GS1 UPC database) to provide real-time data.
    func lookupBarcode(_ code: String) -> FreshliItem? {
        guard !code.isEmpty else {
            logger.warning("Barcode is empty")
            return nil
        }

        // MVP: Sample product database with hardcoded barcodes
        let sampleProducts: [String: (String, FoodCategory, StorageLocation)] = [
            "5000159407236": ("Heinz Baked Beans", .canned, .pantry),
            "5010477348678": ("Cadbury Dairy Milk", .snacks, .pantry),
            "5000128654296": ("PG Tips Tea", .beverages, .pantry),
        ]

        if let product = sampleProducts[code] {
            return FreshliItem(
                name: product.0,
                category: product.1,
                storageLocation: product.2,
                quantity: 1,
                unit: .pieces,
                expiryDate: .daysFromNow(30)
            )
        }

        // Unknown barcode: log and return nil for manual entry
        logger.debug("Unknown barcode: \(code)")
        return nil
    }
}
