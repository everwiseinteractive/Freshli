import SwiftUI
import VisionKit

/// A UIViewControllerRepresentable wrapping VisionKit's DataScannerViewController.
/// Highlights recognized text with animated bounding boxes and reports results upstream.
struct LiveScannerView: UIViewControllerRepresentable {
    /// Called each time new text items are recognized by the scanner.
    let onTextRecognized: ([String]) -> Void

    static var isDeviceSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTextRecognized: onTextRecognized)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: false // We draw custom highlights
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        weak var scanner: DataScannerViewController?
        let onTextRecognized: ([String]) -> Void

        /// Overlay layer for custom bounding-box animations.
        private var highlightLayers: [RecognizedItem.ID: CAShapeLayer] = [:]

        init(onTextRecognized: @escaping ([String]) -> Void) {
            self.onTextRecognized = onTextRecognized
            super.init()
        }

        // MARK: - DataScannerViewControllerDelegate

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems, in: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            processItems(allItems, in: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in removedItems {
                highlightLayers[item.id]?.removeFromSuperlayer()
                highlightLayers.removeValue(forKey: item.id)
            }
            processItems(allItems, in: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            // Pulse animation on tap
            if let layer = highlightLayers[item.id] {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 1.0
                pulse.toValue = 1.08
                pulse.duration = 0.15
                pulse.autoreverses = true
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(pulse, forKey: "pulse")
            }
        }

        // MARK: - Processing

        private func processItems(_ allItems: [RecognizedItem], in dataScanner: DataScannerViewController) {
            var texts: [String] = []

            for item in allItems {
                guard case .text(let text) = item else { continue }
                texts.append(text.transcript)
                updateHighlight(for: item, bounds: text.bounds, in: dataScanner)
            }

            if !texts.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onTextRecognized(texts)
                }
            }
        }

        private func updateHighlight(for item: RecognizedItem, bounds: RecognizedItem.Bounds, in controller: DataScannerViewController) {
            let overlayView = controller.overlayContainerView

            let path = UIBezierPath()
            path.move(to: bounds.topLeft)
            path.addLine(to: bounds.topRight)
            path.addLine(to: bounds.bottomRight)
            path.addLine(to: bounds.bottomLeft)
            path.close()

            if let existing = highlightLayers[item.id] {
                // Animate path update for smooth tracking
                let animation = CABasicAnimation(keyPath: "path")
                animation.fromValue = existing.path
                animation.toValue = path.cgPath
                animation.duration = 0.15
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                existing.path = path.cgPath
                existing.add(animation, forKey: "pathUpdate")
            } else {
                let layer = CAShapeLayer()
                layer.path = path.cgPath
                layer.fillColor = UIColor.systemGreen.withAlphaComponent(0.12).cgColor
                layer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8).cgColor
                layer.lineWidth = 1.5
                layer.cornerRadius = 4

                // Entrance animation — scale in + fade
                layer.opacity = 0
                overlayView.layer.addSublayer(layer)
                highlightLayers[item.id] = layer

                CATransaction.begin()
                CATransaction.setAnimationDuration(0.3)
                CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))

                let fadeIn = CABasicAnimation(keyPath: "opacity")
                fadeIn.fromValue = 0
                fadeIn.toValue = 1
                fadeIn.duration = 0.3

                let scaleUp = CABasicAnimation(keyPath: "transform.scale")
                scaleUp.fromValue = 0.92
                scaleUp.toValue = 1.0
                scaleUp.duration = 0.3

                layer.opacity = 1
                layer.add(fadeIn, forKey: "fadeIn")
                layer.add(scaleUp, forKey: "scaleIn")

                CATransaction.commit()
            }
        }

        /// Start scanning. Called from the SwiftUI side via onAppear.
        func startScanning() {
            try? scanner?.startScanning()
        }

        /// Stop scanning.
        func stopScanning() {
            scanner?.stopScanning()
            for layer in highlightLayers.values {
                layer.removeFromSuperlayer()
            }
            highlightLayers.removeAll()
        }
    }
}
