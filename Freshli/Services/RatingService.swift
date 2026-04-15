import Foundation
import StoreKit
import UIKit
import SwiftUI

// MARK: - RatingService
// Tracks "joy moments" (recipe completed, item rescued, milestone hit) and
// triggers an App Store review prompt after 3 consecutive joy moments,
// no more than once every 30 days. Apple limits reviews to 3 per year per app
// regardless of how often we call requestReview — this service ensures we call
// it at the highest-value moment (peak user satisfaction).

@MainActor
final class RatingService {

    static let shared = RatingService()
    private init() {}

    // MARK: - UserDefaults Keys

    private let momentsKey      = "rating_joy_moments"
    private let lastRequestKey  = "rating_last_request_date"

    // MARK: - Config

    private let momentsRequired: Int    = 3    // request after N joy moments
    private let minDaysBetween: Double  = 30   // at least 30 days between prompts

    // MARK: - Public API

    /// Call this whenever a high-joy moment occurs:
    /// - Item rescued from the bin (consumed)
    /// - Recipe successfully completed
    /// - Impact milestone reached
    func recordJoyMoment() {
        let count = UserDefaults.standard.integer(forKey: momentsKey) + 1
        UserDefaults.standard.set(count, forKey: momentsKey)
        PSLogger.general.info("RatingService: joy moment \(count)/\(self.momentsRequired) recorded")
        maybeRequestReview(currentCount: count)
    }

    // MARK: - Private Logic

    private func maybeRequestReview(currentCount: Int) {
        guard currentCount >= momentsRequired else { return }

        // Check we haven't asked recently
        if let last = UserDefaults.standard.object(forKey: lastRequestKey) as? Date {
            let days = Date().timeIntervalSince(last) / 86_400
            guard days >= minDaysBetween else {
                PSLogger.general.info("RatingService: skipping — last request was \(Int(days))d ago")
                return
            }
        }

        // Reset counter and record date before requesting to avoid double-firing
        UserDefaults.standard.set(0, forKey: momentsKey)
        UserDefaults.standard.set(Date(), forKey: lastRequestKey)

        // Delay slightly so it appears after any animations complete.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_800))
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }

            AppStore.requestReview(in: windowScene)
            PSLogger.general.info("RatingService: review prompt presented")
        }
    }
}
