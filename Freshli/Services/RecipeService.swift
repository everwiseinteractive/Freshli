import Foundation
import os

@Observable @MainActor
final class RecipeService {
    private(set) var recipes: [Recipe] = []
    private let logger = PSLogger(category: .recipe)

    // Singleton instance with cached recipe database
    static let shared = RecipeService()
    private static let cachedRecipes = RecipeService.buildRecipeDatabase()

    private init() {
        loadRecipes()
    }

    // MARK: - Singleton Access

    static func getInstance() -> RecipeService {
        return shared
    }

    func loadRecipes() {
        recipes = Self.cachedRecipes
        logger.debug("Loaded \(recipes.count) recipes from cache")
    }

    /// Find recipes that match pantry items with a minimum threshold.
    /// Returns recipes sorted by match percentage (highest first).
    /// Recipes with at least 1 matching ingredient are included.
    func recipesForFreshli(items: [FreshliItem]) -> [Recipe] {
        // Handle empty pantry gracefully
        guard !items.isEmpty else {
            logger.debug("Empty pantry, returning no recipes")
            return [] // Return empty list, not all recipes
        }

        let pantryNames = Set(items.map { $0.name.lowercased() })

        let recipesWithMatches = Self.cachedRecipes.map { recipe in
            let matching = recipe.ingredients.filter { ingredient in
                pantryNames.contains { pantryName in
                    pantryName.localizedCaseInsensitiveContains(ingredient) ||
                    ingredient.localizedCaseInsensitiveContains(pantryName)
                }
            }
            return Recipe(
                title: recipe.title,
                summary: recipe.summary,
                ingredients: recipe.ingredients,
                steps: recipe.steps,
                prepTimeMinutes: recipe.prepTimeMinutes,
                difficulty: recipe.difficulty,
                matchingIngredientCount: matching.count,
                totalIngredientCount: recipe.totalIngredientCount,
                imageSystemName: recipe.imageSystemName
            )
        }

        // Apply minimum match threshold: at least 1 matching ingredient
        let minThreshold = 1
        let result = recipesWithMatches
            .filter { $0.matchingIngredientCount >= minThreshold }
            .sorted { $0.matchPercentage > $1.matchPercentage }
        logger.info("Found \(result.count) matching recipes for \(items.count) items")
        return result
    }

    func filteredRecipes(difficulty: RecipeDifficulty? = nil, maxTime: Int? = nil) -> [Recipe] {
        var result = recipes
        if let difficulty {
            result = result.filter { $0.difficulty == difficulty }
        }
        if let maxTime {
            result = result.filter { $0.prepTimeMinutes <= maxTime }
        }
        logger.debug("Filtered recipes: \(result.count) results")
        return result
    }

    // MARK: - Recipe Database

    private static func buildRecipeDatabase() -> [Recipe] {
        [
            Recipe(title: "Banana Smoothie Bowl", summary: "A quick, healthy breakfast with ripe bananas and yogurt", ingredients: ["Bananas", "Greek Yogurt", "Honey", "Granola"], steps: ["Blend bananas and yogurt until smooth", "Pour into bowl", "Top with granola and honey"], prepTimeMinutes: 10, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 4, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Chicken Stir-Fry", summary: "Quick weeknight stir-fry with whatever veggies you have", ingredients: ["Chicken Breast", "Frozen Peas", "Soy Sauce", "Rice", "Garlic"], steps: ["Slice chicken thinly", "Heat oil in wok over high heat", "Cook chicken until golden", "Add peas and garlic", "Season with soy sauce and serve over rice"], prepTimeMinutes: 25, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "frying.pan.fill"),

            Recipe(title: "Simple Pasta Pomodoro", summary: "Classic Italian pasta with tomato sauce", ingredients: ["Pasta", "Canned Tomatoes", "Garlic", "Basil", "Olive Oil"], steps: ["Boil pasta in salted water", "Sauté garlic in olive oil", "Add tomatoes, simmer 15 min", "Toss with pasta", "Garnish with fresh basil"], prepTimeMinutes: 20, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "fork.knife"),

            Recipe(title: "Salmon Avocado Bowl", summary: "Fresh bowl with pan-seared salmon and creamy avocado", ingredients: ["Fresh Salmon", "Avocados", "Rice", "Soy Sauce", "Sesame Seeds"], steps: ["Cook rice", "Season and pan-sear salmon 4 min per side", "Slice avocado", "Assemble bowl", "Drizzle with soy sauce and sesame"], prepTimeMinutes: 30, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "fish.fill"),

            Recipe(title: "Yogurt Parfait", summary: "Layered yogurt with fruit and crunchy toppings", ingredients: ["Greek Yogurt", "Bananas", "Honey", "Granola", "Berries"], steps: ["Layer yogurt in glass", "Add sliced bananas", "Drizzle honey", "Top with granola and berries"], prepTimeMinutes: 5, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Grilled Cheese & Tomato Soup", summary: "Comfort food classic with melted cheese and warm soup", ingredients: ["Sourdough Bread", "Cheddar Cheese", "Canned Tomatoes", "Butter", "Cream"], steps: ["Make tomato soup from canned tomatoes and cream", "Butter bread slices", "Layer cheese between bread", "Grill until golden and melted", "Serve with soup"], prepTimeMinutes: 20, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "flame.fill"),

            Recipe(title: "Fried Rice", summary: "Use up leftover rice and veggies in one pan", ingredients: ["Rice", "Frozen Peas", "Eggs", "Soy Sauce", "Sesame Oil"], steps: ["Beat eggs and scramble in hot wok", "Add cold rice and break up clumps", "Add peas and soy sauce", "Stir-fry 3-4 minutes", "Finish with sesame oil"], prepTimeMinutes: 15, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "frying.pan.fill"),

            Recipe(title: "Mediterranean Salad", summary: "Fresh salad with vegetables and feta cheese", ingredients: ["Vegetables", "Feta Cheese", "Olive Oil", "Lemon", "Olives"], steps: ["Chop vegetables into bite pieces", "Crumble feta over top", "Add olives", "Dress with olive oil and lemon juice", "Toss and serve"], prepTimeMinutes: 10, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "leaf.fill"),

            Recipe(title: "Breakfast Tacos", summary: "Scrambled eggs and cheese in warm tortillas with salsa", ingredients: ["Eggs", "Tortillas", "Cheddar Cheese", "Salsa", "Butter"], steps: ["Melt butter in a skillet over medium heat", "Scramble eggs until just set", "Warm tortillas in a dry pan for 30 seconds each side", "Fill tortillas with eggs and shredded cheese", "Top with salsa and serve immediately"], prepTimeMinutes: 10, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "flame.fill"),

            Recipe(title: "Chicken Tikka Masala", summary: "Tender chicken in a rich, spiced tomato-cream sauce", ingredients: ["Chicken Breast", "Canned Tomatoes", "Greek Yogurt", "Cream", "Garlic", "Onion", "Curry Powder"], steps: ["Cut chicken into bite-sized pieces and marinate in yogurt and curry powder for 10 minutes", "Sauté diced onion and garlic until softened", "Add chicken pieces and brown on all sides", "Pour in canned tomatoes and simmer for 15 minutes", "Stir in cream, season to taste, and cook 5 more minutes", "Serve over rice"], prepTimeMinutes: 40, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "fork.knife"),

            Recipe(title: "Black Bean Quesadillas", summary: "Crispy tortillas stuffed with beans, cheese, and peppers", ingredients: ["Tortillas", "Black Beans", "Cheddar Cheese", "Bell Pepper", "Cumin"], steps: ["Drain and rinse black beans, then mash half of them lightly", "Dice bell pepper and mix with beans and a pinch of cumin", "Place a tortilla in a dry skillet over medium heat", "Spread bean mixture on half, top with shredded cheese, fold over", "Cook 3 minutes per side until golden and cheese melts", "Slice into wedges and serve with salsa or sour cream"], prepTimeMinutes: 15, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "flame.fill"),

            Recipe(title: "Peanut Butter Banana Toast", summary: "A quick high-energy snack or light breakfast", ingredients: ["Sourdough Bread", "Peanut Butter", "Bananas", "Honey"], steps: ["Toast bread until golden and crisp", "Spread a generous layer of peanut butter on each slice", "Slice banana and arrange on top", "Drizzle with honey and serve"], prepTimeMinutes: 5, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 4, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Shrimp Garlic Pasta", summary: "Succulent shrimp tossed with garlic butter and linguine", ingredients: ["Pasta", "Shrimp", "Garlic", "Butter", "Lemon", "Parsley"], steps: ["Boil pasta in well-salted water until al dente", "Melt butter in a large skillet and sauté minced garlic for 1 minute", "Add shrimp and cook 2 minutes per side until pink", "Squeeze lemon juice over shrimp", "Toss drained pasta into the skillet with chopped parsley", "Plate and serve with extra lemon wedges"], prepTimeMinutes: 20, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "fish.fill"),

            Recipe(title: "Veggie Curry", summary: "A warming one-pot curry loaded with hearty vegetables", ingredients: ["Potatoes", "Canned Tomatoes", "Coconut Milk", "Curry Powder", "Onion", "Frozen Peas"], steps: ["Dice potatoes and onion into small cubes", "Sauté onion in oil until translucent", "Add curry powder and stir for 30 seconds until fragrant", "Pour in canned tomatoes and coconut milk, add potatoes", "Simmer covered for 20 minutes until potatoes are tender", "Stir in peas, cook 3 more minutes, and serve over rice"], prepTimeMinutes: 35, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "leaf.fill"),

            Recipe(title: "French Toast", summary: "Golden custard-soaked bread, a brunch favorite", ingredients: ["Sourdough Bread", "Eggs", "Milk", "Butter", "Cinnamon", "Maple Syrup"], steps: ["Whisk eggs, milk, and cinnamon together in a shallow dish", "Dip each bread slice, soaking both sides evenly", "Melt butter in a skillet over medium heat", "Cook slices 3 minutes per side until golden brown", "Serve stacked with maple syrup and fresh fruit"], prepTimeMinutes: 15, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "frying.pan.fill"),

            Recipe(title: "Beef Tacos", summary: "Seasoned ground beef in crunchy shells with fresh toppings", ingredients: ["Ground Beef", "Tortillas", "Cheddar Cheese", "Lettuce", "Salsa", "Cumin", "Garlic"], steps: ["Brown ground beef in a skillet, breaking it into crumbles", "Add minced garlic and cumin, cook 2 more minutes", "Warm tortillas in the oven or a dry pan", "Spoon beef into tortillas", "Top with shredded cheese, lettuce, and salsa", "Serve with lime wedges on the side"], prepTimeMinutes: 20, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "flame.fill"),

            Recipe(title: "Homemade Pad Thai", summary: "Sweet, sour, and savory rice noodles with crunchy peanuts", ingredients: ["Rice Noodles", "Eggs", "Peanut Butter", "Soy Sauce", "Lemon", "Garlic", "Green Onions"], steps: ["Soak rice noodles in hot water for 8 minutes, then drain", "Whisk peanut butter, soy sauce, and lemon juice into a sauce", "Scramble eggs in a hot wok, then set aside", "Stir-fry garlic for 30 seconds, add noodles and sauce", "Toss noodles until evenly coated and heated through", "Top with scrambled egg, sliced green onions, and crushed peanuts"], prepTimeMinutes: 25, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "frying.pan.fill"),

            Recipe(title: "Mug Brownie", summary: "A rich chocolate dessert ready in minutes using a microwave", ingredients: ["Flour", "Sugar", "Cocoa Powder", "Butter", "Eggs"], steps: ["Mix flour, sugar, and cocoa powder in a microwave-safe mug", "Add melted butter and a beaten egg, stir until smooth", "Microwave on high for 90 seconds", "Let cool for 1 minute before eating", "Top with a scoop of ice cream if desired"], prepTimeMinutes: 5, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Stuffed Bell Peppers", summary: "Baked peppers filled with seasoned rice, beef, and melted cheese", ingredients: ["Bell Pepper", "Ground Beef", "Rice", "Canned Tomatoes", "Cheddar Cheese", "Onion", "Garlic"], steps: ["Preheat oven to 375F and cut tops off peppers, removing seeds", "Cook rice according to package directions", "Brown ground beef with diced onion and garlic", "Mix beef, rice, and half the canned tomatoes together", "Stuff peppers with mixture and place in a baking dish", "Spoon remaining tomatoes around peppers and top with cheese", "Bake for 30 minutes until peppers are tender and cheese is bubbly"], prepTimeMinutes: 45, difficulty: .hard, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "fork.knife"),

            Recipe(title: "Honey Garlic Salmon", summary: "Glazed salmon fillets with a sweet and savory crust", ingredients: ["Fresh Salmon", "Honey", "Garlic", "Soy Sauce", "Butter", "Lemon"], steps: ["Preheat oven to 400F and line a baking sheet with foil", "Whisk honey, soy sauce, minced garlic, and lemon juice together", "Place salmon fillets on the baking sheet and brush with glaze", "Dot each fillet with a small piece of butter", "Bake for 12-15 minutes, brushing with more glaze halfway through", "Broil for 2 minutes at the end for a caramelized finish"], prepTimeMinutes: 25, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "fish.fill"),
        ]
    }
}
