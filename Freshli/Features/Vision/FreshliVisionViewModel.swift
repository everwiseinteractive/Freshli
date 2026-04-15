import SwiftUI
import AVFoundation
import Vision
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Freshli Vision View Model
// Coordinates camera capture, Vision classification, and nutritional
// data lookup for the Freshli Vision AR scanning experience.
//
// Pipeline:
//   1. AVCaptureSession → live camera feed
//   2. User taps capture → grab CMSampleBuffer frame
//   3. FoodIdentificationService → Vision VNClassifyImageRequest
//   4. NutritionalDatabase → calorie/macro lookup
//   5. FoundationModels (iOS 26+) → sustainability + sourcing insights
//   6. Publish VisionScanResult array → holographic card overlays
// ══════════════════════════════════════════════════════════════════

// MARK: - Camera State

enum VisionCameraState {
    case initializing
    case active
    case permissionDenied
    case unavailable
}

// MARK: - View Model

@Observable @MainActor
final class FreshliVisionViewModel: NSObject {
    // MARK: - Published State

    private(set) var cameraState: VisionCameraState = .initializing
    private(set) var isScanning = false
    private(set) var isAnalyzing = false
    private(set) var scanResults: [VisionScanResult] = []
    private(set) var errorMessage: String?

    // MARK: - AVCapture

    let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var capturedImage: UIImage?
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    // MARK: - Services

    private let foodIdService = FoodIdentificationService()
    private let logger = Logger(subsystem: "com.freshli", category: "FreshliVision")

    // MARK: - Lifecycle

    func startSession() async {
        // Check camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                configureCaptureSession()
            } else {
                cameraState = .permissionDenied
            }
        case .denied, .restricted:
            cameraState = .permissionDenied
        @unknown default:
            cameraState = .unavailable
        }
    }

    func stopSession() {
        captureSession.stopRunning()
        isScanning = false
    }

    // MARK: - Camera Configuration

    private func configureCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            cameraState = .unavailable
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        // Add photo output for still capture
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        // Start session on background thread.
        // AVCaptureSession is not Sendable but startRunning must run off-main.
        // nonisolated(unsafe) suppresses the false-positive race warning;
        // the session is fully configured before this point and never
        // mutated concurrently.
        nonisolated(unsafe) let session = captureSession
        Task.detached {
            session.startRunning()
        }

        cameraState = .active
        isScanning = true
        logger.info("Freshli Vision camera session started")
    }

    // MARK: - Capture & Analyze

    func captureAndAnalyze() async {
        guard cameraState == .active else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Capture a still photo
        guard let image = await capturePhoto() else {
            errorMessage = "Failed to capture photo"
            return
        }

        logger.info("Photo captured, analyzing with Vision...")

        // Run food identification
        await foodIdService.identifyFood(image)

        // Map results to VisionScanResults with nutritional data
        let identifiedItems = foodIdService.results

        var visionResults: [VisionScanResult] = []

        for item in identifiedItems.prefix(6) {
            let nutrition = NutritionalDatabase.lookup(item.displayName, category: item.category)
            let sustainability = NutritionalDatabase.sustainabilityScore(for: item.category)

            let result = VisionScanResult(
                name: item.displayName,
                category: item.category,
                confidence: item.confidence,
                nutritionalInfo: nutrition,
                shelfLifeDays: item.estimatedShelfLifeDays,
                storageHint: storageHint(for: item.storageLocation),
                sustainabilityScore: sustainability
            )
            visionResults.append(result)
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            scanResults = visionResults
        }

        // Speak each detected item through Motion Vocabulary for VoiceOver users
        for result in visionResults {
            MotionVocabularyService.shared.speakMotion(
                .scanDetection(confidence: result.confidence)
            )
        }

        logger.info("Vision analysis complete: \(visionResults.count) items identified")
    }

    // MARK: - Photo Capture

    private func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Helpers

    private func storageHint(for location: StorageLocation) -> String {
        switch location {
        case .fridge: return String(localized: "Fridge")
        case .freezer: return String(localized: "Freezer")
        case .pantry: return String(localized: "Pantry")
        case .counter: return String(localized: "Counter")
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension FreshliVisionViewModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage?
        if let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        } else {
            image = nil
        }

        Task { @MainActor in
            photoContinuation?.resume(returning: image)
            photoContinuation = nil
        }
    }
}

// MARK: - Nutritional Database

/// On-device nutritional data lookup for common food items.
/// Values are per 100g approximations for holographic display.
/// Not a medical reference — for informational display only.
enum NutritionalDatabase {
    /// Lookup nutritional info by food name and category.
    static func lookup(_ name: String, category: FoodCategory) -> NutritionalInfo {
        let key = name.lowercased()

        // Check specific items first
        if let specific = specificItems[key] {
            return specific
        }

        // Fall back to category defaults
        return categoryDefaults[category] ?? NutritionalInfo.unknown
    }

    /// Sustainability score (0→1) based on food category.
    /// Higher = more sustainable (plant-based, local, low-impact).
    static func sustainabilityScore(for category: FoodCategory) -> Double {
        switch category {
        case .fruits, .vegetables:  return 0.85
        case .grains, .bakery:      return 0.75
        case .canned:               return 0.65
        case .condiments, .snacks:  return 0.55
        case .dairy:                return 0.50
        case .beverages:            return 0.45
        case .frozen:               return 0.40
        case .meat:                 return 0.30
        case .seafood:              return 0.35
        case .other:                return 0.50
        }
    }

    // MARK: - Specific Items

    private static let specificItems: [String: NutritionalInfo] = [
        "apple":     NutritionalInfo(calories: 52, protein: 0.3, carbs: 14, fat: 0.2, fiber: 2.4),
        "banana":    NutritionalInfo(calories: 89, protein: 1.1, carbs: 23, fat: 0.3, fiber: 2.6),
        "orange":    NutritionalInfo(calories: 47, protein: 0.9, carbs: 12, fat: 0.1, fiber: 2.4),
        "strawberry":NutritionalInfo(calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3, fiber: 2.0),
        "avocado":   NutritionalInfo(calories: 160, protein: 2.0, carbs: 8.5, fat: 15, fiber: 6.7),
        "tomato":    NutritionalInfo(calories: 18, protein: 0.9, carbs: 3.9, fat: 0.2, fiber: 1.2),
        "carrot":    NutritionalInfo(calories: 41, protein: 0.9, carbs: 10, fat: 0.2, fiber: 2.8),
        "broccoli":  NutritionalInfo(calories: 34, protein: 2.8, carbs: 7, fat: 0.4, fiber: 2.6),
        "spinach":   NutritionalInfo(calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fiber: 2.2),
        "chicken":   NutritionalInfo(calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0),
        "salmon":    NutritionalInfo(calories: 208, protein: 20, carbs: 0, fat: 13, fiber: 0),
        "egg":       NutritionalInfo(calories: 155, protein: 13, carbs: 1.1, fat: 11, fiber: 0),
        "milk":      NutritionalInfo(calories: 42, protein: 3.4, carbs: 5, fat: 1, fiber: 0),
        "rice":      NutritionalInfo(calories: 130, protein: 2.7, carbs: 28, fat: 0.3, fiber: 0.4),
        "bread":     NutritionalInfo(calories: 265, protein: 9, carbs: 49, fat: 3.2, fiber: 2.7),
        "pasta":     NutritionalInfo(calories: 131, protein: 5, carbs: 25, fat: 1.1, fiber: 1.8),
        "potato":    NutritionalInfo(calories: 77, protein: 2, carbs: 17, fat: 0.1, fiber: 2.2),
        "onion":     NutritionalInfo(calories: 40, protein: 1.1, carbs: 9.3, fat: 0.1, fiber: 1.7),
        "garlic":    NutritionalInfo(calories: 149, protein: 6.4, carbs: 33, fat: 0.5, fiber: 2.1),
        "cheese":    NutritionalInfo(calories: 402, protein: 25, carbs: 1.3, fat: 33, fiber: 0),
        "yogurt":    NutritionalInfo(calories: 59, protein: 10, carbs: 3.6, fat: 0.4, fiber: 0),
        "lemon":     NutritionalInfo(calories: 29, protein: 1.1, carbs: 9.3, fat: 0.3, fiber: 2.8),
        "pepper":    NutritionalInfo(calories: 20, protein: 0.9, carbs: 4.6, fat: 0.2, fiber: 1.7),
        "mushroom":  NutritionalInfo(calories: 22, protein: 3.1, carbs: 3.3, fat: 0.3, fiber: 1.0),
    ]

    // MARK: - Category Defaults

    private static let categoryDefaults: [FoodCategory: NutritionalInfo] = [
        .fruits:     NutritionalInfo(calories: 50, protein: 0.8, carbs: 12, fat: 0.3, fiber: 2.0),
        .vegetables: NutritionalInfo(calories: 30, protein: 1.5, carbs: 6, fat: 0.3, fiber: 2.5),
        .dairy:      NutritionalInfo(calories: 80, protein: 5, carbs: 5, fat: 4, fiber: 0),
        .meat:       NutritionalInfo(calories: 180, protein: 25, carbs: 0, fat: 8, fiber: 0),
        .seafood:    NutritionalInfo(calories: 120, protein: 20, carbs: 0, fat: 4, fiber: 0),
        .grains:     NutritionalInfo(calories: 130, protein: 4, carbs: 27, fat: 1, fiber: 1.5),
        .bakery:     NutritionalInfo(calories: 250, protein: 8, carbs: 45, fat: 4, fiber: 2),
        .frozen:     NutritionalInfo(calories: 100, protein: 5, carbs: 15, fat: 3, fiber: 1),
        .canned:     NutritionalInfo(calories: 90, protein: 4, carbs: 12, fat: 2, fiber: 1.5),
        .condiments: NutritionalInfo(calories: 60, protein: 1, carbs: 10, fat: 2, fiber: 0.5),
        .snacks:     NutritionalInfo(calories: 400, protein: 5, carbs: 50, fat: 20, fiber: 2),
        .beverages:  NutritionalInfo(calories: 40, protein: 0.5, carbs: 10, fat: 0, fiber: 0),
        .other:      NutritionalInfo(calories: 100, protein: 3, carbs: 15, fat: 3, fiber: 1),
    ]
}
