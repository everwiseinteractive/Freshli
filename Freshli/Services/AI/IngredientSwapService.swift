import Foundation
import SwiftData

// MARK: - Ingredient Swap Provider Protocol
// LLM-ready interface. Swap `DeterministicSwapProvider` for any GPT/Gemini/
// Claude-backed implementation — the async signature is identical.

protocol IngredientSwapProvider: Sendable {
    /// Rewrite a single step replacing `original` ingredient with `substitute`.
    func rewrite(step: String, replacing original: String, with substitute: String) async -> String
}

// MARK: - Deterministic Provider (fast, offline, zero latency)

struct DeterministicSwapProvider: IngredientSwapProvider {
    func rewrite(step: String, replacing original: String, with substitute: String) async -> String {
        var result = step
        let options: String.CompareOptions = [.caseInsensitive]
        var searchStart = result.startIndex
        while searchStart < result.endIndex,
              let range = result.range(of: original, options: options, range: searchStart..<result.endIndex) {
            let isCapital = result[range].first?.isUppercase == true
            let rep = isCapital
                ? (substitute.prefix(1).uppercased() + substitute.dropFirst())
                : substitute.lowercased()
            result.replaceSubrange(range, with: rep)
            searchStart = result.index(range.lowerBound,
                                       offsetBy: rep.count,
                                       limitedBy: result.endIndex) ?? result.endIndex
        }
        return result
    }
}

// MARK: - Ingredient Swap Service

@MainActor
final class IngredientSwapService {

    static let shared = IngredientSwapService()
    private let provider: any IngredientSwapProvider

    private init(provider: any IngredientSwapProvider = DeterministicSwapProvider()) {
        self.provider = provider
    }

    // MARK: - Common Semantic Substitution Pairs

    // Each entry: words that name the "missing" ingredient → candidates from pantry.
    // Checked when the recipe's own substitutions dict has no match.
    private let semanticPairs: [(need: [String], have: [String])] = [
        (["kale", "swiss chard", "collard greens"],
         ["spinach", "arugula", "rocket", "spring greens", "lettuce", "baby leaves"]),
        (["spinach", "arugula", "rocket", "spring greens"],
         ["kale", "cabbage", "watercress", "baby leaves"]),
        (["chicken breast"],
         ["chicken thighs", "chicken", "turkey breast", "rotisserie chicken"]),
        (["beef mince", "ground beef"],
         ["pork mince", "turkey mince", "chicken mince", "lamb mince"]),
        (["milk", "whole milk"],
         ["oat milk", "almond milk", "soy milk", "coconut milk", "skimmed milk", "semi-skimmed"]),
        (["butter"],
         ["olive oil", "coconut oil", "ghee", "margarine", "vegetable oil"]),
        (["lemon", "lemon juice"],
         ["lime", "lime juice", "orange juice", "apple cider vinegar", "white wine vinegar"]),
        (["onion", "yellow onion", "white onion"],
         ["shallots", "red onion", "spring onion", "scallion", "leek"]),
        (["garlic"],
         ["garlic powder", "garlic paste", "garlic flakes"]),
        (["tomatoes", "tomato"],
         ["cherry tomatoes", "canned tomatoes", "tomato paste", "passata", "tomato puree"]),
        (["pasta"],
         ["spaghetti", "penne", "fusilli", "linguine", "noodles", "rice noodles"]),
        (["rice", "white rice"],
         ["brown rice", "quinoa", "cauliflower rice", "couscous", "bulgur wheat"]),
        (["cream", "heavy cream", "double cream"],
         ["coconut cream", "greek yogurt", "sour cream", "crème fraîche", "cream cheese"]),
        (["parsley"],
         ["coriander", "basil", "chives", "dill", "tarragon", "flat-leaf parsley"]),
        (["basil"],
         ["parsley", "oregano", "thyme", "tarragon", "mint"]),
        (["coriander", "cilantro"],
         ["parsley", "basil", "chives", "mint"]),
        (["bread crumbs", "breadcrumbs"],
         ["panko", "crushed crackers", "oats", "crushed cornflakes"]),
        (["soy sauce"],
         ["tamari", "coconut aminos", "fish sauce", "worcestershire sauce"]),
        (["coconut milk"],
         ["almond milk", "oat milk", "soy milk", "cream", "evaporated milk"]),
        (["bell pepper", "capsicum", "red pepper"],
         ["courgette", "zucchini", "aubergine", "eggplant", "green beans"]),
        (["cream cheese"],
         ["ricotta", "mascarpone", "greek yogurt", "cottage cheese"]),
        (["bacon", "pancetta"],
         ["lardons", "prosciutto", "ham", "smoked tofu"]),
        (["mushrooms"],
         ["courgette", "zucchini", "aubergine", "eggplant"]),
    ]

    // MARK: - Public API

    /// Compute swaps for a recipe: returns { missing ingredient → available pantry substitute }.
    func computeSwaps(
        recipeIngredients: [String],
        pantryItems: [FreshliItem],
        substitutions: [String: [String]] = [:]
    ) -> [String: String] {
        let pantryNames = pantryItems.map { $0.name.lowercased() }
        var swaps: [String: String] = [:]

        for ingredient in recipeIngredients {
            let lower = ingredient.lowercased()

            // Skip if user already has this ingredient
            let alreadyHave = pantryNames.contains(where: {
                $0.localizedCaseInsensitiveContains(lower) ||
                lower.localizedCaseInsensitiveContains($0)
            })
            if alreadyHave { continue }

            // 1) Recipe's own substitutions map
            if let alternatives = substitutions[ingredient] {
                for alt in alternatives {
                    if let pantryName = pantryItems.first(where: {
                        $0.name.localizedCaseInsensitiveContains(alt) ||
                        alt.localizedCaseInsensitiveContains($0.name)
                    })?.name {
                        swaps[ingredient] = pantryName
                        break
                    }
                }
                if swaps[ingredient] != nil { continue }
            }

            // 2) Semantic fallback via common pairs
            for pair in semanticPairs {
                let matches = pair.need.contains(where: {
                    lower.localizedCaseInsensitiveContains($0) ||
                    $0.localizedCaseInsensitiveContains(lower)
                })
                guard matches else { continue }
                for alt in pair.have {
                    if let pantryName = pantryItems.first(where: {
                        $0.name.localizedCaseInsensitiveContains(alt) ||
                        alt.localizedCaseInsensitiveContains($0.name)
                    })?.name {
                        swaps[ingredient] = pantryName
                        break
                    }
                }
                if swaps[ingredient] != nil { break }
            }
        }

        return swaps
    }

    /// Apply all swaps to a step array, returning adapted text.
    func rewriteSteps(_ steps: [String], swaps: [String: String]) async -> [String] {
        guard !swaps.isEmpty else { return steps }
        var result = steps
        for (original, substitute) in swaps {
            var updated: [String] = []
            for step in result {
                let s = await provider.rewrite(step: step, replacing: original, with: substitute)
                updated.append(s)
            }
            result = updated
        }
        return result
    }
}
