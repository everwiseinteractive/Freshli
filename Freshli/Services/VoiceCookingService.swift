import Foundation
import AVFoundation
import SwiftUI

// MARK: - Voice Cooking Service
// Hands-free voice assistant for rescue recipes. Reads steps aloud,
// advances automatically, and suggests sustainability tips between steps.

// MARK: - Service

@MainActor
@Observable
final class VoiceCookingService: NSObject {
    static let shared = VoiceCookingService()

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingSteps: [String] = []

    var isActive: Bool = false
    var isSpeaking: Bool = false
    var currentStepIndex: Int = 0
    var currentStepText: String = ""
    var currentTip: String? = nil

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    /// Begin a hands-free cooking session with the given recipe steps.
    func start(recipeName: String, steps: [String]) {
        guard !steps.isEmpty else { return }
        pendingSteps = steps
        currentStepIndex = 0
        isActive = true
        currentStepText = steps[0]
        currentTip = zeroWasteTip(for: recipeName)
        speak("Okay, let's cook \(recipeName). Step 1 of \(steps.count). \(steps[0])")
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        pendingSteps = []
        isActive = false
        isSpeaking = false
        currentStepIndex = 0
        currentStepText = ""
        currentTip = nil
    }

    func nextStep() {
        guard isActive else { return }
        let nextIndex = currentStepIndex + 1
        guard nextIndex < pendingSteps.count else {
            speak("All steps complete. Amazing rescue — your waste warrior streak grows!")
            isActive = false
            return
        }
        currentStepIndex = nextIndex
        currentStepText = pendingSteps[nextIndex]
        speak("Step \(nextIndex + 1). \(pendingSteps[nextIndex])")
    }

    func previousStep() {
        guard isActive, currentStepIndex > 0 else { return }
        currentStepIndex -= 1
        currentStepText = pendingSteps[currentStepIndex]
        speak("Going back to step \(currentStepIndex + 1). \(pendingSteps[currentStepIndex])")
    }

    func repeatStep() {
        guard isActive else { return }
        speak("Step \(currentStepIndex + 1). \(currentStepText)")
    }

    // MARK: - Speaking

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1.05
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer.speak(utterance)
    }

    // MARK: - Zero-Waste Tips

    private func zeroWasteTip(for recipeName: String) -> String {
        let l = recipeName.lowercased()
        if l.contains("carrot")   { return "Tip: Regrow carrot tops in a jar of water for fresh herbs in 5 days." }
        if l.contains("spring onion") || l.contains("scallion") { return "Tip: Spring onion roots regrow in water — stand white ends in a glass." }
        if l.contains("potato")   { return "Tip: Save the peels, toss with olive oil and salt, and bake for crisps." }
        if l.contains("herb")     { return "Tip: Freeze leftover herbs in olive-oil ice cubes for instant flavour next time." }
        if l.contains("lemon")    { return "Tip: Freeze lemon zest — it's often more flavourful than the juice." }
        if l.contains("bread")    { return "Tip: Turn stale bread into breadcrumbs in a food processor — freezes well." }
        if l.contains("apple")    { return "Tip: Simmer apple peels with sugar for a quick compote." }
        return "Tip: Save vegetable offcuts in a freezer bag to make stock later."
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceCookingService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
