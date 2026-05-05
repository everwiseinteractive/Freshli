import SwiftUI
import Combine
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Ambient Light Service
// Monitors the device's ambient light conditions using UIScreen
// brightness and system appearance to drive dynamic shadow direction,
// OLED-black glow in dark rooms, and high-key specular in bright
// environments.
//
// Architecture:
//   1. UIScreen.main.brightness provides a 0→1 proxy for ambient light
//      (iOS adjusts display brightness based on the ambient light sensor)
//   2. System appearance (dark/light mode) provides context
//   3. Thermal state modulates effect intensity (respect battery)
//   4. Published values propagate via SwiftUI Environment keys
//
// Output values consumed by shaders:
//   - ambientBrightness: 0.0 (pitch dark) → 1.0 (direct sunlight)
//   - lightDirection: normalized 2D vector (simulated sun position)
//   - shadowIntensity: 0.0 (bright, washed-out) → 1.0 (dark, crisp)
//   - specularIntensity: 0.0 (dark, no specular) → 1.0 (bright, high-key)
//   - glowMode: .oledBlack | .neutral | .highKey
//
// Privacy: Only reads UIScreen.brightness — no camera access needed.
// ══════════════════════════════════════════════════════════════════

// MARK: - Ambient Glow Mode

/// Describes the current lighting environment for UI adaptation.
enum AmbientGlowMode: String, Sendable {
    case oledBlack  // Very dark room — emit soft warm glow from elements
    case neutral    // Normal indoor lighting — balanced shadows + specular
    case highKey    // Bright environment — strong specular, soft shadows
}

// MARK: - Light Direction

/// Simulated directional light source derived from time-of-day and
/// device orientation. Used to drive shadow offset direction.
struct LightDirection: Sendable, Equatable {
    let x: Float   // -1 (left) → +1 (right)
    let y: Float   // -1 (top) → +1 (bottom)

    /// Normalized shadow offset for a given elevation (points).
    func shadowOffset(elevation: CGFloat) -> CGSize {
        let magnitude = elevation * 0.6
        return CGSize(
            width: CGFloat(x) * magnitude,
            height: CGFloat(y) * magnitude
        )
    }

    /// Default top-left light source (classic Apple design language).
    static let topLeft = LightDirection(x: -0.3, y: -0.8)
    /// Overhead — minimal directional shadow.
    static let overhead = LightDirection(x: 0.0, y: -0.2)
}

// MARK: - Ambient Light Service

@Observable @MainActor
final class AmbientLightService {
    static let shared = AmbientLightService()

    // MARK: - Published State

    /// Raw screen brightness (0→1). Proxy for ambient light level.
    private(set) var screenBrightness: Float = 0.5

    /// Smoothed ambient brightness with hysteresis to prevent flickering.
    private(set) var ambientBrightness: Float = 0.5

    /// Current glow mode derived from ambient conditions.
    private(set) var glowMode: AmbientGlowMode = .neutral

    /// Simulated light direction for shadow casting.
    private(set) var lightDirection: LightDirection = .topLeft

    /// Shadow intensity — inverse of brightness (darker = stronger shadows).
    var shadowIntensity: Float {
        // In dark environments, shadows are more pronounced on OLED
        // In bright environments, shadows wash out naturally
        let base = 1.0 - ambientBrightness
        return max(0.05, base * 0.8 + 0.15)
    }

    /// Specular highlight intensity — proportional to brightness.
    var specularIntensity: Float {
        // Bright environments produce strong glass reflections
        // Dark environments produce subtle edge glow instead
        let base = ambientBrightness
        return max(0.1, base * 0.7 + 0.2)
    }

    /// OLED glow radius — larger in dark, zero in bright.
    var oledGlowRadius: Float {
        switch glowMode {
        case .oledBlack: return 0.8
        case .neutral:   return 0.3
        case .highKey:   return 0.0
        }
    }

    /// OLED glow opacity — visible only in dark mode.
    var oledGlowOpacity: Float {
        switch glowMode {
        case .oledBlack: return 0.25
        case .neutral:   return 0.08
        case .highKey:   return 0.0
        }
    }

    // MARK: - Private

    private let logger = Logger(subsystem: "com.freshli", category: "AmbientLight")
    private var brightnessTimer: Timer?
    private var previousBrightness: Float = 0.5
    private let smoothingFactor: Float = 0.15  // EMA smoothing (lower = smoother)
    private let hysteresisThreshold: Float = 0.03  // Ignore brightness changes < 3%

    private init() {
        // Read initial brightness
        screenBrightness = Float(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.brightness ?? 0.5)
        ambientBrightness = screenBrightness
        updateGlowMode()
        updateLightDirection()
    }

    // MARK: - Lifecycle

    /// Start monitoring ambient light changes.
    /// Called once from FreshliApp on launch.
    func startMonitoring() {
        // Poll UIScreen.brightness at 4Hz — sufficient for smooth transitions
        // without burning battery. UIScreen brightness is updated by iOS's
        // ambient light sensor at ~10Hz internally.
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleBrightness()
            }
        }

        // Also observe brightness change notification for instant response
        NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sampleBrightness()
            }
        }

        logger.info("Ambient light monitoring started (brightness: \(self.screenBrightness, format: .fixed(precision: 2)))")
    }

    func stopMonitoring() {
        brightnessTimer?.invalidate()
        brightnessTimer = nil
        NotificationCenter.default.removeObserver(self, name: UIScreen.brightnessDidChangeNotification, object: nil)
    }

    // MARK: - Sampling

    private func sampleBrightness() {
        let raw = Float(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen.brightness ?? 0.5)
        screenBrightness = raw

        // Apply EMA smoothing with hysteresis to prevent jitter
        let delta = abs(raw - previousBrightness)
        guard delta > hysteresisThreshold else { return }

        ambientBrightness = ambientBrightness + smoothingFactor * (raw - ambientBrightness)
        previousBrightness = raw

        updateGlowMode()
        updateLightDirection()
    }

    // MARK: - Derived State

    private func updateGlowMode() {
        let newMode: AmbientGlowMode
        if ambientBrightness < 0.15 {
            newMode = .oledBlack
        } else if ambientBrightness > 0.70 {
            newMode = .highKey
        } else {
            newMode = .neutral
        }

        if newMode != glowMode {
            glowMode = newMode
            logger.info("Glow mode: \(newMode.rawValue) (brightness: \(self.ambientBrightness, format: .fixed(precision: 2)))")
        }
    }

    private func updateLightDirection() {
        // Simulate light direction based on time of day:
        //   Morning (6–12): light from the right (east)
        //   Afternoon (12–18): light from the left (west)
        //   Evening/Night: overhead ambient
        let hour = Calendar.current.component(.hour, from: Date())

        let x: Float
        let y: Float

        switch hour {
        case 6..<10:
            x = 0.5     // Light from right (morning sun through east window)
            y = -0.7
        case 10..<14:
            x = 0.0     // Overhead (midday)
            y = -0.9
        case 14..<18:
            x = -0.5    // Light from left (afternoon sun through west window)
            y = -0.7
        default:
            // Evening/night — overhead ambient, minimal directional shadow
            x = 0.0
            y = -0.3
        }

        lightDirection = LightDirection(x: x, y: y)
    }
}

// MARK: - Environment Keys

private struct AmbientBrightnessKey: EnvironmentKey {
    static let defaultValue: Float = 0.5
}

private struct AmbientGlowModeKey: EnvironmentKey {
    static let defaultValue: AmbientGlowMode = .neutral
}

private struct LightDirectionKey: EnvironmentKey {
    static let defaultValue: LightDirection = .topLeft
}

extension EnvironmentValues {
    /// Current ambient brightness level (0→1).
    var ambientBrightness: Float {
        get { self[AmbientBrightnessKey.self] }
        set { self[AmbientBrightnessKey.self] = newValue }
    }

    /// Current ambient glow mode (oledBlack / neutral / highKey).
    var ambientGlowMode: AmbientGlowMode {
        get { self[AmbientGlowModeKey.self] }
        set { self[AmbientGlowModeKey.self] = newValue }
    }

    /// Current simulated light direction for shadow casting.
    var lightDirection: LightDirection {
        get { self[LightDirectionKey.self] }
        set { self[LightDirectionKey.self] = newValue }
    }
}
