import Foundation

// MARK: - RecipeService
/// Provides recipe suggestions based on pantry items

@MainActor
final class RecipeService {
    
    static let shared = RecipeService()
    
    private init() {}
    
    // MARK: - Recipe Model
    
    struct Recipe: Identifiable {
        let id: String
        let name: String
        let description: String
        let cookTime: String
        let servings: Int
        let difficulty: String
        let imageName: String
        let ingredients: [String]
        let instructions: [String]
        let matchedIngredients: [String]
        let matchPercentage: Int
        
        var matchBadgeText: String {
            "\(matchPercentage)% Match"
        }
    }
    
    // MARK: - Sample Recipes Database
    
    private let allRecipes: [Recipe] = [
        Recipe(
            id: "pasta-tomato",
            name: "Simple Tomato Pasta",
            description: "Classic comfort food using pantry staples",
            cookTime: "20 min",
            servings: 4,
            difficulty: "Easy",
            imageName: "pasta",
            ingredients: ["Pasta", "Tomatoes", "Garlic", "Olive Oil", "Basil"],
            instructions: [
                "Boil pasta according to package directions",
                "Sauté garlic in olive oil",
                "Add chopped tomatoes and simmer",
                "Toss with pasta and fresh basil"
            ],
            matchedIngredients: [],
            matchPercentage: 0
        ),
        Recipe(
            id: "veggie-stirfry",
            name: "Quick Veggie Stir-Fry",
            description: "Use up those vegetables before they expire",
            cookTime: "15 min",
            servings: 2,
            difficulty: "Easy",
            imageName: "stirfry",
            ingredients: ["Mixed Vegetables", "Soy Sauce", "Garlic", "Ginger", "Rice"],
            instructions: [
                "Heat oil in wok or large pan",
                "Stir-fry vegetables starting with harder ones",
                "Add garlic and ginger",
                "Season with soy sauce and serve over rice"
            ],
            matchedIngredients: [],
            matchPercentage: 0
        ),
        Recipe(
            id: "banana-bread",
            name: "Banana Bread",
            description: "Perfect for overripe bananas",
            cookTime: "60 min",
            servings: 8,
            difficulty: "Medium",
            imageName: "bread",
            ingredients: ["Bananas", "Flour", "Sugar", "Eggs", "Butter"],
            instructions: [
                "Mash overripe bananas",
                "Mix with melted butter and sugar",
                "Add eggs and flour",
                "Bake at 350°F for 60 minutes"
            ],
            matchedIngredients: [],
            matchPercentage: 0
        ),
        Recipe(
            id: "smoothie-bowl",
            name: "Berry Smoothie Bowl",
            description: "Healthy breakfast to use expiring fruits",
            cookTime: "5 min",
            servings: 1,
            difficulty: "Easy",
            imageName: "smoothie",
            ingredients: ["Mixed Berries", "Banana", "Yogurt", "Honey", "Granola"],
            instructions: [
                "Blend berries, banana, and yogurt until smooth",
                "Pour into bowl",
                "Top with granola and honey",
                "Add fresh fruit if desired"
            ],
            matchedIngredients: [],
            matchPercentage: 0
        ),
        Recipe(
            id: "chicken-soup",
            name: "Chicken Vegetable Soup",
            description: "Hearty soup using leftover chicken",
            cookTime: "45 min",
            servings: 6,
            difficulty: "Medium",
            imageName: "soup",
            ingredients: ["Chicken", "Carrots", "Celery", "Onion", "Chicken Broth"],
            instructions: [
                "Sauté onions, carrots, and celery",
                "Add chicken broth and bring to boil",
                "Add shredded chicken",
                "Simmer until vegetables are tender"
            ],
            matchedIngredients: [],
            matchPercentage: 0
        )
    ]
    
    // MARK: - Recipe Matching
    
    /// Find recipes that match items in user's pantry
    func recipesForFreshli(items: [FreshliItem]) -> [Recipe] {
        guard !items.isEmpty else { return [] }
        
        let pantryItemNames = Set(items.map { $0.name.lowercased() })
        
        var matchedRecipes: [Recipe] = []
        
        for var recipe in allRecipes {
            var matchedIngredients: [String] = []
            
            for ingredient in recipe.ingredients {
                // Simple keyword matching
                if pantryItemNames.contains(where: { ingredient.lowercased().contains($0) || $0.contains(ingredient.lowercased()) }) {
                    matchedIngredients.append(ingredient)
                }
            }
            
            if !matchedIngredients.isEmpty {
                let matchPercentage = Int((Double(matchedIngredients.count) / Double(recipe.ingredients.count)) * 100)
                
                var updatedRecipe = recipe
                updatedRecipe.matchedIngredients = matchedIngredients
                updatedRecipe.matchPercentage = matchPercentage
                
                matchedRecipes.append(updatedRecipe)
            }
        }
        
        // Sort by match percentage
        return matchedRecipes.sorted { $0.matchPercentage > $1.matchPercentage }
    }
    
    /// Get a specific recipe by ID
    func recipe(withId id: String) -> Recipe? {
        allRecipes.first { $0.id == id }
    }
    
    /// Get random recipe suggestion
    func randomRecipe() -> Recipe? {
        allRecipes.randomElement()
    }
}
