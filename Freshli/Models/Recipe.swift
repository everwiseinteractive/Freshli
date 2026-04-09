import Foundation

enum RecipeDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return String(localized: "Easy")
        case .medium: return String(localized: "Medium")
        case .hard: return String(localized: "Hard")
        }
    }

    var icon: String {
        switch self {
        case .easy: return "leaf.fill"
        case .medium: return "flame.fill"
        case .hard: return "star.fill"
        }
    }
}

struct Recipe: Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let ingredients: [String]
    let steps: [String]
    let prepTimeMinutes: Int
    let difficulty: RecipeDifficulty
    let matchingIngredientCount: Int
    let totalIngredientCount: Int
    let imageSystemName: String

    var matchPercentage: Double {
        guard totalIngredientCount > 0 else { return 0 }
        return Double(matchingIngredientCount) / Double(totalIngredientCount)
    }

    var matchPercentageDisplay: String {
        "\(Int(matchPercentage * 100))%"
    }

    /// Stable seeded rating between 4.0 and 5.0 derived from the recipe title.
    var rating: Double {
        let seed = title.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        // Maps to range [4.0, 5.0] with one decimal place
        let step = seed % 11  // 0...10
        return 4.0 + Double(step) * 0.1
    }

    var ratingDisplay: String {
        String(format: "%.1f", rating)
    }

    var prepTimeDisplay: String {
        if prepTimeMinutes < 60 {
            return "\(prepTimeMinutes) min"
        }
        let hours = prepTimeMinutes / 60
        let mins = prepTimeMinutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }

    init(
        title: String,
        summary: String,
        ingredients: [String],
        steps: [String],
        prepTimeMinutes: Int,
        difficulty: RecipeDifficulty,
        matchingIngredientCount: Int,
        totalIngredientCount: Int,
        imageSystemName: String
    ) {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.ingredients = ingredients
        self.steps = steps
        self.prepTimeMinutes = prepTimeMinutes
        self.difficulty = difficulty
        self.matchingIngredientCount = matchingIngredientCount
        self.totalIngredientCount = totalIngredientCount
        self.imageSystemName = imageSystemName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Recipe, rhs: Recipe) -> Bool {
        lhs.id == rhs.id
    }
}
