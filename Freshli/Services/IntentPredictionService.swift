import Foundation
import SwiftData
import SwiftUI
import os

// MARK: - Intent Prediction Service (Apple Intelligence Adaptive UI)
//
// Predicts the user's most likely next action and drives the
// `predictiveSurface` Metal shader on the Predictive Surface card
// and `intentGlow` on secondary UI elements.
//
// Architecture:
//   1. Heuristic layer — always available, zero-latency
//      (time of day + pantry state + recent actions)
//   2. User Pattern Tracker — records timestamped actions and
//      learns behavioural rhythms (e.g. "user checks pantry at 7am")
//   3. Foundation Models layer (iOS 26+ with Apple Intelligence)
//      analyses patterns and enriches predictions with contextual
//      reasoning via on-device LLM
//
// Output: per-section glow intensities (0→1) consumed by
// HomeView's PredictiveSurfaceCard via `.metalPredictiveSurface()`.
//
// Privacy: all prediction happens on-device. No data leaves the phone.

// MARK: - Intent Types

/// Actions the user might take next, ordered by typical frequency.
enum PredictedIntent: String, CaseIterable, Sendable {
    case rescueFood     // Cook expiring items (highest urgency)
    case addItems       // Add new groceries (just shopped)
    case checkRecipes   // Browse recipe ideas
    case shareFood      // Donate to community
    case viewImpact     // Check environmental impact
    case managePantry   // Review/organize pantry

    /// Freshli green glow for food rescue, teal for community, warm for impact
    var glowColor: (r: Float, g: Float, b: Float) {
        switch self {
        case .rescueFood:   return (0.13, 0.77, 0.37)  // primaryGreen
        case .addItems:     return (0.16, 0.65, 0.53)   // teal-green
        case .checkRecipes: return (0.09, 0.64, 0.29)   // headerGreen
        case .shareFood:    return (0.08, 0.72, 0.65)   // accentTeal
        case .viewImpact:   return (0.22, 0.80, 0.45)   // bright green
        case .managePantry: return (0.13, 0.60, 0.35)   // mid green
        }
    }
}

/// A scored prediction with confidence and reasoning.
struct IntentScore: Sendable {
    let intent: PredictedIntent
    let confidence: Float   // 0.0–1.0
    let reason: String      // Human-readable reasoning
}

// MARK: - User Pattern Event

/// A timestamped record of a user action — the raw signal that the
/// pattern tracker uses to learn behavioural rhythms.
struct UserPatternEvent: Codable, Sendable {
    let action: String      // PredictedIntent.rawValue or custom action
    let timestamp: Date
    let hourOfDay: Int      // 0–23, pre-computed for fast pattern matching
    let dayOfWeek: Int      // 1–7 (Sun–Sat)
}

// MARK: - Service

@Observable @MainActor
final class IntentPredictionService {
    // Published glow intensities for each UI section.
    // Views observe these to drive `.metalIntentGlow(intensity:)`.
    private(set) var rescueFoodGlow: Float = 0
    private(set) var addItemsGlow: Float = 0
    private(set) var checkRecipesGlow: Float = 0
    private(set) var shareFoodGlow: Float = 0
    private(set) var viewImpactGlow: Float = 0
    private(set) var managePantryGlow: Float = 0

    /// The top predicted intent, or nil if no strong prediction.
    private(set) var topIntent: PredictedIntent?

    /// Human-readable explanation for the current top prediction.
    /// Displayed on the Predictive Surface card.
    private(set) var topPredictionReason: String = ""

    /// All scored predictions, sorted by confidence descending.
    private(set) var predictions: [IntentScore] = []

    /// Recent user action history for pattern learning (last 50 events).
    private(set) var recentActions: [UserPatternEvent] = []

    /// Whether Foundation Models analysis is currently running.
    private(set) var isAnalysing = false

    private let logger = PSLogger(category: .pantry)
    private let storageKey = "freshli_user_pattern_events"
    private let maxStoredEvents = 200

    // MARK: - Public API

    /// Runs intent prediction based on current pantry state.
    /// Call on app foreground, after item changes, or periodically.
    func predict(
        expiringCount: Int,
        expiredCount: Int,
        totalItems: Int,
        recentlyAdded: Int,
        recentlyConsumed: Int,
        recentlyShared: Int,
        streakDays: Int,
        hourOfDay: Int? = nil
    ) {
        let hour = hourOfDay ?? Calendar.current.component(.hour, from: Date())

        var scores: [IntentScore] = []

        // ── Heuristic: Rescue Food ──
        // High urgency if items are expiring/expired
        let rescueBase: Float = expiredCount > 0 ? 0.85 :
                                expiringCount >= 3 ? 0.72 :
                                expiringCount >= 1 ? 0.55 : 0.15
        // Mealtime boost (11–13, 17–19)
        let mealtimeBoost: Float = (hour >= 11 && hour <= 13) || (hour >= 17 && hour <= 19) ? 0.15 : 0.0
        let rescueScore = min(rescueBase + mealtimeBoost, 1.0)
        scores.append(IntentScore(
            intent: .rescueFood,
            confidence: rescueScore,
            reason: expiredCount > 0 ? "\(expiredCount) expired item\(expiredCount > 1 ? "s" : "") — rescue now" :
                    expiringCount > 0 ? "\(expiringCount) item\(expiringCount > 1 ? "s" : "") expiring soon" :
                    "Pantry looks fresh"
        ))

        // ── Heuristic: Add Items ──
        // High if pantry is empty or user recently shopped (evening, weekends)
        let addBase: Float = totalItems == 0 ? 0.80 :
                             totalItems < 3 ? 0.60 : 0.20
        let shoppingTime: Float = (hour >= 16 && hour <= 20) ? 0.12 : 0.0
        let recentAddBoost: Float = recentlyAdded >= 2 ? 0.15 : 0.0  // momentum
        let addScore = min(addBase + shoppingTime + recentAddBoost, 1.0)
        scores.append(IntentScore(
            intent: .addItems,
            confidence: addScore,
            reason: totalItems == 0 ? "Empty pantry — time to stock up" :
                    totalItems < 3 ? "Low stock — might need groceries" :
                    "Pantry well stocked"
        ))

        // ── Heuristic: Check Recipes ──
        let recipeBase: Float = expiringCount >= 2 ? 0.52 : 0.25
        let browsingTime: Float = (hour >= 10 && hour <= 14) || (hour >= 16 && hour <= 18) ? 0.10 : 0.0
        let recipeScore = min(recipeBase + browsingTime, 1.0)
        scores.append(IntentScore(
            intent: .checkRecipes,
            confidence: recipeScore,
            reason: expiringCount >= 2 ? "Multiple items to rescue — browse ideas" : "Recipe inspiration"
        ))

        // ── Heuristic: Share Food ──
        let shareBase: Float = expiredCount >= 2 ? 0.45 :
                               expiringCount >= 3 && recentlyShared > 0 ? 0.38 : 0.12
        let shareScore = min(shareBase, 1.0)
        scores.append(IntentScore(
            intent: .shareFood,
            confidence: shareScore,
            reason: recentlyShared > 0 ? "You've been sharing — keep the wave going" : "Share surplus with neighbors"
        ))

        // ── Heuristic: View Impact ──
        let impactBase: Float = streakDays >= 3 ? 0.35 :
                                recentlyConsumed >= 2 ? 0.30 : 0.10
        let impactScore = min(impactBase, 1.0)
        scores.append(IntentScore(
            intent: .viewImpact,
            confidence: impactScore,
            reason: streakDays >= 3 ? "\(streakDays)-day streak — see your impact" : "Track your environmental impact"
        ))

        // ── Heuristic: Manage Pantry ──
        let manageBase: Float = totalItems >= 10 ? 0.28 : 0.12
        let manageScore = min(manageBase, 1.0)
        scores.append(IntentScore(
            intent: .managePantry,
            confidence: manageScore,
            reason: totalItems >= 10 ? "Large pantry — might want to organize" : "Quick pantry check"
        ))

        // Sort by confidence
        scores.sort { $0.confidence > $1.confidence }
        predictions = scores

        // Set top intent (only if reasonably confident)
        if let top = scores.first, top.confidence >= 0.35 {
            topIntent = top.intent
        } else {
            topIntent = nil
        }

        // Map to per-section glow intensities with smoothing
        // Only the top 2 intents get visible glow, others fade
        updateGlowIntensities(from: scores)

        logger.debug("Intent predicted: \(topIntent?.rawValue ?? "none") (\(scores.first?.confidence ?? 0))")
    }

    // MARK: - Glow Mapping

    private func updateGlowIntensities(from scores: [IntentScore]) {
        // Only top 2 predictions glow — prevents visual noise
        let glowScores = scores.prefix(2)

        // Reset all to zero
        var glows: [PredictedIntent: Float] = [:]
        for intent in PredictedIntent.allCases {
            glows[intent] = 0
        }

        // Apply glow for top predictions
        for (index, score) in glowScores.enumerated() {
            // Scale: top prediction gets full confidence, second gets 60%
            let scale: Float = index == 0 ? 1.0 : 0.6
            // Minimum threshold — don't glow below 0.3 confidence
            let glow = score.confidence >= 0.30 ? score.confidence * scale : 0
            glows[score.intent] = glow
        }

        // Animate transitions using withAnimation on the glow values
        rescueFoodGlow = glows[.rescueFood] ?? 0
        addItemsGlow = glows[.addItems] ?? 0
        checkRecipesGlow = glows[.checkRecipes] ?? 0
        shareFoodGlow = glows[.shareFood] ?? 0
        viewImpactGlow = glows[.viewImpact] ?? 0
        managePantryGlow = glows[.managePantry] ?? 0
    }

    // MARK: - Convenience

    /// Returns the glow intensity for a given intent.
    func glowIntensity(for intent: PredictedIntent) -> Float {
        switch intent {
        case .rescueFood:   return rescueFoodGlow
        case .addItems:     return addItemsGlow
        case .checkRecipes: return checkRecipesGlow
        case .shareFood:    return shareFoodGlow
        case .viewImpact:   return viewImpactGlow
        case .managePantry: return managePantryGlow
        }
    }

    /// Returns the glow color for a given intent as resolved RGB.
    func glowColor(for intent: PredictedIntent) -> (r: Float, g: Float, b: Float) {
        intent.glowColor
    }

    /// The resolved SwiftUI Color for the top predicted intent's glow.
    var topIntentColor: Color {
        guard let intent = topIntent else { return FLColors.aiGlow }
        let c = intent.glowColor
        return Color(red: Double(c.r), green: Double(c.g), blue: Double(c.b))
    }

    /// SF Symbol icon for the top predicted intent.
    var topIntentIcon: String {
        switch topIntent {
        case .rescueFood:   return "fork.knife"
        case .addItems:     return "plus.circle.fill"
        case .checkRecipes: return "book.pages.fill"
        case .shareFood:    return "hand.raised.fill"
        case .viewImpact:   return "leaf.fill"
        case .managePantry: return "refrigerator.fill"
        case .none:         return "sparkles"
        }
    }

    /// Display title for the top predicted intent.
    var topIntentTitle: String {
        switch topIntent {
        case .rescueFood:   return String(localized: "Rescue expiring food")
        case .addItems:     return String(localized: "Add new items")
        case .checkRecipes: return String(localized: "Find a recipe")
        case .shareFood:    return String(localized: "Share with neighbors")
        case .viewImpact:   return String(localized: "See your impact")
        case .managePantry: return String(localized: "Check your pantry")
        case .none:         return String(localized: "Freshli Intelligence")
        }
    }

    // MARK: - User Pattern Tracking

    /// Records a user action for pattern learning. Call this whenever
    /// the user performs a meaningful action (tab switch, item consumed, etc.)
    func recordAction(_ intent: PredictedIntent) {
        let now = Date()
        let cal = Calendar.current
        let event = UserPatternEvent(
            action: intent.rawValue,
            timestamp: now,
            hourOfDay: cal.component(.hour, from: now),
            dayOfWeek: cal.component(.weekday, from: now)
        )

        recentActions.append(event)

        // Trim to max stored events
        if recentActions.count > maxStoredEvents {
            recentActions = Array(recentActions.suffix(maxStoredEvents))
        }

        // Persist to UserDefaults
        persistEvents()
    }

    /// Loads previously recorded pattern events from disk.
    func loadStoredEvents() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let events = try? JSONDecoder().decode([UserPatternEvent].self, from: data) else {
            return
        }
        recentActions = events
        logger.debug("Loaded \(events.count) pattern events")
    }

    private func persistEvents() {
        if let data = try? JSONEncoder().encode(recentActions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Generates a compact behavioural summary for the Foundation Models engine.
    /// Groups actions by hour-of-day to surface rhythms like "user checks pantry
    /// at 7am and 6pm" or "user browses recipes around lunchtime".
    func patternSummary() -> String {
        guard !recentActions.isEmpty else { return "No usage history yet." }

        // Count actions by hour for each intent
        var hourCounts: [String: [Int: Int]] = [:]
        for event in recentActions {
            hourCounts[event.action, default: [:]][event.hourOfDay, default: 0] += 1
        }

        var lines: [String] = []
        lines.append("Usage patterns (last \(recentActions.count) actions):")

        for (action, hours) in hourCounts.sorted(by: { $0.value.values.reduce(0, +) > $1.value.values.reduce(0, +) }) {
            let total = hours.values.reduce(0, +)
            let peakHour = hours.max(by: { $0.value < $1.value })?.key ?? 0
            lines.append("  \(action): \(total) times, peak at \(peakHour):00")
        }

        let now = Calendar.current.component(.hour, from: Date())
        lines.append("Current hour: \(now):00")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Foundation Models Enhancement (iOS 26+)
//
// When Apple Intelligence is available, enriches the heuristic
// predictions with contextual reasoning from the on-device LLM.
// Falls back gracefully to pure heuristics when unavailable.

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Pattern Analysis Output
//
// Structured output schema the on-device LLM must produce.
// @Generable constrains the model to valid JSON matching this shape.

@Generable
struct PatternAnalysis {
    @Guide(description: "The predicted next action: one of rescueFood, addItems, checkRecipes, shareFood, viewImpact, managePantry")
    var predictedAction: String

    @Guide(description: "Confidence from 0.0 to 1.0 that this is what the user wants to do right now")
    var confidence: Double

    @Guide(description: "One sentence explaining why, referencing the user's patterns. Max 80 characters. Be warm and specific, e.g. 'You usually check recipes around lunchtime'")
    var reasoning: String
}

@available(iOS 26.0, *)
extension IntentPredictionService {

    /// Analyses user behaviour patterns using Foundation Models and enriches
    /// the heuristic predictions with contextual, pattern-aware reasoning.
    /// The on-device LLM sees:
    ///   • Pantry state (expiring items, quantities)
    ///   • Behavioural patterns (action frequencies by hour-of-day)
    ///   • Current time context
    func analysePatterns(pantrySnapshot: String) async {
        guard SystemLanguageModel.default.isAvailable else {
            logger.debug("Foundation Models not available — using heuristics only")
            return
        }

        isAnalysing = true
        defer { isAnalysing = false }

        do {
            let session = LanguageModelSession(
                instructions: """
                You are Freshli's on-device intelligence engine. You analyse a user's \
                food management patterns to predict what they want to do next. \
                Be warm, specific, and reference their actual habits when explaining.
                """
            )

            let patterns = patternSummary()
            let prompt = """
            Given the user's pantry state and their usage patterns, predict \
            the single most helpful action they should take right now.

            Pantry State:
            \(pantrySnapshot)

            \(patterns)

            Current time: \(Date().formatted(date: .abbreviated, time: .shortened))
            """

            let response = try await session.respond(to: prompt, generating: PatternAnalysis.self)
            let analysis = response.content

            // Apply the AI analysis
            if let aiIntent = PredictedIntent(rawValue: analysis.predictedAction) {
                let aiConfidence = Float(min(max(analysis.confidence, 0.0), 1.0))

                if let index = predictions.firstIndex(where: { $0.intent == aiIntent }) {
                    var boosted = predictions
                    let original = boosted[index]

                    // Blend heuristic + AI confidence (AI gets 60% weight if high)
                    let blended = max(original.confidence, aiConfidence * 0.6 + original.confidence * 0.4)

                    boosted[index] = IntentScore(
                        intent: original.intent,
                        confidence: min(blended, 1.0),
                        reason: analysis.reasoning
                    )
                    boosted.sort { $0.confidence > $1.confidence }
                    predictions = boosted

                    if let top = boosted.first, top.confidence >= 0.35 {
                        topIntent = top.intent
                        topPredictionReason = analysis.reasoning
                    }
                    updateGlowIntensities(from: boosted)
                }

                logger.debug("AI pattern analysis: \(analysis.predictedAction) @ \(analysis.confidence) — \(analysis.reasoning)")
            }
        } catch {
            logger.debug("Foundation Models pattern analysis failed: \(error.localizedDescription)")
            // Graceful fallback — heuristic predictions remain
        }
    }

    /// Legacy enhancement method — now delegates to the richer pattern analyser.
    func enhanceWithAI(pantrySnapshot: String) async {
        await analysePatterns(pantrySnapshot: pantrySnapshot)
    }
}
#endif
