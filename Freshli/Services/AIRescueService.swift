import Foundation
import FoundationModels
import os

// MARK: - FoundationModels Rescue Service
//
// On-device Apple Intelligence recipe generator. Uses iOS 26's
// `FoundationModels` framework to produce bespoke rescue recipes
// tailored to the user's actual at-risk pantry items — entirely on-device,
// with zero network calls and zero cost per query.
//
// This augments (does not replace) the rule-based `RescueChefService`.
// When Apple Intelligence is available, the AI-generated missions appear
// at the top of the Rescue Chef screen as a distinct "Ask Freshli AI"
// section. When it is not available (older devices, unsupported region,
// model still downloading, user has Apple Intelligence disabled), the
// rule-based system runs alone and the AI section is hidden.
//
// Privacy note: the user's pantry contents never leave their phone.

// MARK: - Generable Output Types
//
// These types define the structured output schema the LLM must produce.
// `@Generable` + `@Guide` tell FoundationModels exactly what shape and
// meaning each field has — the model is constrained to produce valid JSON
// matching the schema, so we never need to parse free-form text.

@Generable
struct AIRescueMission {
    @Guide(description: "Short catchy recipe title, max 6 words, use an action verb like 'Whip', 'Transform', 'Rescue', 'Blend', 'Roast'")
    let title: String

    @Guide(description: "One-sentence description of the recipe, max 120 characters, explaining what the user will cook")
    let description: String

    @Guide(description: "Estimated cook time in minutes, between 5 and 90")
    let estimatedMinutes: Int

    @Guide(description: "Difficulty level: one of 'easy', 'medium', or 'hard'")
    let difficulty: String

    @Guide(description: "Names of the at-risk pantry items this recipe uses, copied verbatim from the input list")
    let usedItems: [String]

    @Guide(description: "Additional pantry staples the user will need that are not on the at-risk list (e.g. 'olive oil', 'salt'). Keep to 5 items maximum.")
    let additionalItems: [String]

    @Guide(description: "Between 4 and 7 clear cooking steps, each a single sentence starting with an action verb")
    let steps: [String]

    @Guide(description: "A single sentence explaining why this recipe rescues food waste, e.g. 'Saves 2 servings of spinach before tomorrow's expiry'")
    let impactNote: String
}

@Generable
struct AIRescueResponse {
    @Guide(description: "Exactly 3 diverse rescue recipes, ranked by how many at-risk items they rescue. The first recipe should rescue the most items.")
    let missions: [AIRescueMission]
}

// MARK: - Service

@Observable @MainActor
final class AIRescueService {
    /// The AI-generated missions, ready to render.
    private(set) var missions: [UsageMission] = []

    /// Whether a generation request is currently in flight.
    private(set) var isGenerating: Bool = false

    /// The most recent user-visible error, if any.
    private(set) var lastError: String?

    /// Whether Apple Intelligence is available on this device for us to use.
    /// Read this on view appear to decide whether to show the AI section.
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private let logger = Logger(subsystem: "com.freshli.app", category: "AIRescue")

    // Cached session — reusing the session across requests gives the model
    // a warm context and noticeably faster responses for subsequent queries.
    private var session: LanguageModelSession?

    static let shared = AIRescueService()

    private init() {}

    // MARK: - Public API

    /// Generate bespoke rescue recipes for the user's at-risk items using
    /// on-device Apple Intelligence. Call this only after confirming
    /// `isAvailable == true`. Results are published via the observable
    /// `missions` property.
    func generateMissions(for atRiskItems: [FreshliItem]) async {
        guard isAvailable else {
            logger.info("AIRescue: Apple Intelligence unavailable — skipping")
            missions = []
            return
        }

        guard !atRiskItems.isEmpty else {
            missions = []
            return
        }

        isGenerating = true
        lastError = nil
        defer { isGenerating = false }

        // Build a compact prompt describing the user's at-risk pantry. We
        // include the name, quantity, and days-until-expiry for each item so
        // the model can pick recipes that use the most urgent ingredients.
        let pantryDescription = buildPantryDescription(atRiskItems)

        let prompt = """
        My pantry has these items about to expire:

        \(pantryDescription)

        Generate exactly 3 rescue recipes that use as many of these items as \
        possible. Prioritize recipes that combine multiple at-risk ingredients \
        in one dish, and favor quick, easy cooking when the urgency is high. \
        Use only the pantry items listed above plus common kitchen staples.
        """

        do {
            let session = try getOrCreateSession()
            let response = try await session.respond(
                to: prompt,
                generating: AIRescueResponse.self
            )

            let aiMissions = response.content.missions
            logger.info("AIRescue: model generated \(aiMissions.count) missions")

            // Map the Generable output to the app's existing UsageMission
            // type so the view layer can render AI missions through the
            // same components as rule-based missions.
            missions = aiMissions.map { aiMission in
                convertToUsageMission(aiMission, atRiskItems: atRiskItems)
            }
        } catch {
            logger.error("AIRescue: generation failed: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "Rescue Chef couldn't cook up ideas this time. Please try again.")
            missions = []
        }
    }

    /// Clear the cached session and any generated missions. Call when the
    /// user signs out, switches households, or manually refreshes.
    func reset() {
        session = nil
        missions = []
        lastError = nil
    }

    // MARK: - Private Helpers

    private func getOrCreateSession() throws -> LanguageModelSession {
        if let session { return session }

        let instructions = """
        You are Freshli's Rescue Chef — an assistant that helps users rescue \
        food that's about to expire by turning it into delicious meals. You \
        are warm, encouraging, and practical. Your recipes are simple enough \
        for a weeknight and use standard home kitchen equipment. You never \
        suggest recipes the user cannot make from the listed pantry items \
        plus common staples. You prioritize recipes that rescue multiple \
        items at once to maximize food waste prevention.
        """

        let newSession = LanguageModelSession(instructions: instructions)
        session = newSession
        return newSession
    }

    private func buildPantryDescription(_ items: [FreshliItem]) -> String {
        let now = Date()
        return items
            .sorted { $0.expiryDate < $1.expiryDate }
            .map { item in
                let hoursRemaining = Calendar.current.dateComponents(
                    [.hour], from: now, to: item.expiryDate
                ).hour ?? 0
                let urgency: String = {
                    if hoursRemaining <= 0 { return "EXPIRED — use immediately" }
                    if hoursRemaining <= 12 { return "expires in \(hoursRemaining)h — critical" }
                    if hoursRemaining <= 48 { return "expires in \(hoursRemaining)h — urgent" }
                    return "expires in \(hoursRemaining / 24) days"
                }()
                let quantity = "\(item.quantity) \(item.unit.displayName)"
                return "- \(item.name) (\(quantity), \(urgency))"
            }
            .joined(separator: "\n")
    }

    private func convertToUsageMission(
        _ aiMission: AIRescueMission,
        atRiskItems: [FreshliItem]
    ) -> UsageMission {
        // Find the FreshliItems whose names the model claims to use. We do
        // a case-insensitive contains match because the model may say
        // "spinach" when the user's item is called "Fresh Spinach Bag".
        let usedFreshliItems: [FreshliItem] = aiMission.usedItems.compactMap { mentionedName in
            let needle = mentionedName.lowercased()
            return atRiskItems.first { item in
                let haystack = item.name.lowercased()
                return haystack.contains(needle) || needle.contains(haystack)
            }
        }

        // If the model completely hallucinated ingredients, fall back to
        // the most urgent at-risk item so the mission still renders.
        let resolvedItems = usedFreshliItems.isEmpty
            ? [atRiskItems.min(by: { $0.expiryDate < $1.expiryDate })].compactMap { $0 }
            : usedFreshliItems

        // Determine urgency from the most urgent item the mission uses.
        let urgency: UrgencyLevel = {
            guard let mostUrgent = resolvedItems.min(by: { $0.expiryDate < $1.expiryDate }) else {
                return .moderate
            }
            let hours = Calendar.current.dateComponents(
                [.hour], from: Date(), to: mostUrgent.expiryDate
            ).hour ?? 0
            if hours <= 12 { return .critical }
            if hours <= 24 { return .urgent }
            return .moderate
        }()

        return UsageMission(
            id: UUID(),
            title: aiMission.title,
            description: aiMission.description,
            urgencyLevel: urgency,
            freshliItems: resolvedItems,
            estimatedMinutes: max(5, min(aiMission.estimatedMinutes, 120)),
            difficulty: parseDifficulty(aiMission.difficulty),
            steps: aiMission.steps,
            additionalItems: aiMission.additionalItems
        )
    }

    private func parseDifficulty(_ raw: String) -> RecipeDifficulty {
        switch raw.lowercased() {
        case "easy": return .easy
        case "hard", "difficult", "advanced": return .hard
        default: return .medium
        }
    }
}
