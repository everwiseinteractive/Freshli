import Foundation
import AVFoundation

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
    var isCameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func lookupBarcode(_ code: String) -> PantryItem? {
        // In a production app, this would call a product database API.
        // For the MVP, return a sample item based on barcode pattern.
        let sampleProducts: [String: (String, FoodCategory, StorageLocation)] = [
            "5000159407236": ("Heinz Baked Beans", .canned, .pantry),
            "5010477348678": ("Cadbury Dairy Milk", .snacks, .pantry),
            "5000128654296": ("PG Tips Tea", .beverages, .pantry),
        ]

        if let product = sampleProducts[code] {
            return PantryItem(
                name: product.0,
                category: product.1,
                storageLocation: product.2,
                quantity: 1,
                unit: .pieces,
                expiryDate: .daysFromNow(30)
            )
        }

        // For unknown barcodes, return nil so the user can fill in manually.
        return nil
    }
}
