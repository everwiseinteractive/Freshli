import SwiftUI
import CoreHaptics

// MARK: - PSHaptics (Simple Haptic Feedback)
/// Basic haptic feedback using UIFeedbackGenerator

@MainActor
final class PSHaptics {
    
    static let shared = PSHaptics()
    
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators
        impact.prepare()
        light.prepare()
        heavy.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    // MARK: - Basic Haptics
    
    func lightTap() {
        light.impactOccurred()
    }
    
    func mediumTap() {
        impact.impactOccurred()
    }
    
    func heavyTap() {
        heavy.impactOccurred()
    }
    
    func selection() {
        selection.selectionChanged()
    }
    
    func success() {
        notification.notificationOccurred(.success)
    }
    
    func warning() {
        notification.notificationOccurred(.warning)
    }
    
    func error() {
        notification.notificationOccurred(.error)
    }
}

// MARK: - FreshliHapticManager (Advanced Haptics with CHHapticEngine)
/// Rich haptic patterns for celebrations and key interactions

@MainActor
final class FreshliHapticManager {
    
    static let shared = FreshliHapticManager()
    
    private var engine: CHHapticEngine?
    private var supportsHaptics = false
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            supportsHaptics = true
            
            // Auto-restart if engine stops
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
        } catch {
            supportsHaptics = false
        }
    }
    
    // MARK: - Celebration Haptics
    
    enum CelebrationIntensity {
        case small
        case medium
        case large
    }
    
    func celebrationHaptic(intensity: CelebrationIntensity) {
        guard supportsHaptics, let engine = engine else {
            // Fallback to simple haptics
            PSHaptics.shared.success()
            return
        }
        
        let pattern = celebrationPattern(for: intensity)
        
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            PSHaptics.shared.success()
        }
    }
    
    private func celebrationPattern(for intensity: CelebrationIntensity) -> CHHapticPattern {
        var events: [CHHapticEvent] = []
        
        switch intensity {
        case .small:
            // Single sharp tap
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0
            ))
            
        case .medium:
            // Double tap with slight delay
            for i in 0..<2 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                    ],
                    relativeTime: Double(i) * 0.1
                ))
            }
            
        case .large:
            // Celebration burst pattern
            for i in 0..<3 {
                events.append(CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                    ],
                    relativeTime: Double(i) * 0.08
                ))
            }
            // Add continuous rumble
            events.append(CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                ],
                relativeTime: 0.25,
                duration: 0.3
            ))
        }
        
        do {
            return try CHHapticPattern(events: events, parameters: [])
        } catch {
            // Fallback to simple pattern
            return try! CHHapticPattern(events: [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [],
                    relativeTime: 0
                )
            ], parameters: [])
        }
    }
}
