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

            // MARK: — Extended Database (30+ built-in recipes)

            Recipe(title: "Creamy Avocado Pasta", summary: "Silky no-cook avocado sauce tossed with hot pasta", ingredients: ["Pasta", "Avocados", "Lemon", "Garlic", "Olive Oil", "Basil"], steps: ["Boil pasta in salted water until al dente", "Blend avocados, lemon juice, garlic, and olive oil into a smooth sauce", "Drain pasta and toss immediately with avocado sauce", "Season with salt, pepper, and fresh basil", "Serve with chilli flakes and extra lemon"], prepTimeMinutes: 18, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "fork.knife"),

            Recipe(title: "Overnight Oats", summary: "No-cook breakfast prepared the night before — grab and go", ingredients: ["Oats", "Milk", "Greek Yogurt", "Honey", "Bananas", "Berries"], steps: ["Combine oats, milk, and yogurt in a jar with a lid", "Stir in a drizzle of honey", "Refrigerate overnight or for at least 4 hours", "In the morning, top with sliced bananas and fresh berries", "Enjoy cold straight from the jar"], prepTimeMinutes: 5, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Classic Margherita Pizza", summary: "Crispy base with tomato sauce, mozzarella, and fresh basil", ingredients: ["Flour", "Canned Tomatoes", "Mozzarella Cheese", "Basil", "Olive Oil", "Yeast"], steps: ["Mix flour, yeast, salt, and olive oil with water into a smooth dough", "Let dough rise for 30 minutes in a warm place", "Preheat oven to 480°F with a baking sheet inside", "Stretch dough on a floured surface, spread tomato sauce", "Top with torn mozzarella and bake 12 minutes until bubbling", "Finish with fresh basil leaves and a drizzle of olive oil"], prepTimeMinutes: 50, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "flame.fill"),

            Recipe(title: "Lemon Garlic Chicken", summary: "Juicy pan-roasted chicken thighs with bright citrus flavours", ingredients: ["Chicken Thighs", "Lemon", "Garlic", "Butter", "Rosemary", "Olive Oil"], steps: ["Season chicken thighs generously with salt and pepper", "Heat olive oil in an oven-safe skillet over high heat", "Sear chicken skin-side down for 5 minutes until golden", "Flip, add butter, crushed garlic, and rosemary to the pan", "Squeeze lemon juice over chicken and roast at 400F for 18 minutes", "Rest 5 minutes before serving with pan juices drizzled over"], prepTimeMinutes: 35, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "fork.knife"),

            Recipe(title: "Mushroom Omelette", summary: "Fluffy three-egg omelette packed with sautéed mushrooms and cheese", ingredients: ["Eggs", "Mushrooms", "Cheddar Cheese", "Butter", "Parsley", "Garlic"], steps: ["Beat 3 eggs with a pinch of salt and pepper until frothy", "Sauté sliced mushrooms and garlic in butter until golden", "Pour egg mixture into the same pan over medium-low heat", "As edges set, gently pull them inward and tilt pan", "Add cheese and mushrooms to one half, fold the other half over", "Slide onto a plate and garnish with fresh parsley"], prepTimeMinutes: 10, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "frying.pan.fill"),

            Recipe(title: "Coconut Rice Pudding", summary: "Creamy, naturally sweet dessert made with coconut milk and vanilla", ingredients: ["Rice", "Coconut Milk", "Honey", "Vanilla Extract", "Cinnamon", "Milk"], steps: ["Combine rice, coconut milk, and regular milk in a saucepan", "Cook over medium heat, stirring often, for 20 minutes until thick", "Remove from heat and stir in honey and vanilla extract", "Spoon into bowls and dust generously with cinnamon", "Serve warm or cover and refrigerate for a cold dessert"], prepTimeMinutes: 25, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Spinach & Feta Omelette", summary: "Protein-packed breakfast with wilted spinach and creamy feta", ingredients: ["Eggs", "Vegetables", "Feta Cheese", "Butter", "Garlic", "Lemon"], steps: ["Wilt a handful of spinach in a dry pan for 1 minute, set aside", "Beat 3 eggs with salt, pepper, and a squeeze of lemon", "Melt butter in the pan over medium heat", "Pour in eggs and cook gently, pushing edges inward", "Add spinach and crumbled feta to one half, fold and plate", "Serve immediately with toast"], prepTimeMinutes: 8, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "frying.pan.fill"),

            Recipe(title: "Thai Green Curry", summary: "Aromatic coconut curry with tender chicken and vibrant vegetables", ingredients: ["Chicken Breast", "Coconut Milk", "Bell Pepper", "Frozen Peas", "Curry Powder", "Garlic", "Lemon"], steps: ["Slice chicken into strips and brown in a hot wok with oil", "Add garlic and curry paste (or powder), stir-fry 1 minute", "Pour in coconut milk and bring to a gentle simmer", "Add sliced bell pepper and cook 8 minutes", "Stir in peas and a squeeze of lime, cook 2 more minutes", "Serve over jasmine rice with fresh coriander"], prepTimeMinutes: 28, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "fork.knife"),

            Recipe(title: "Berry Smoothie", summary: "Thick, vibrant smoothie packed with antioxidants", ingredients: ["Berries", "Bananas", "Greek Yogurt", "Honey", "Milk"], steps: ["Add all ingredients to a blender", "Blend on high for 60 seconds until completely smooth", "Taste and add more honey if needed", "Pour into a tall glass and serve immediately", "Optional: top with granola for extra crunch"], prepTimeMinutes: 5, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Roasted Vegetable Tray", summary: "Hands-off sheet-pan dinner — oven does all the work", ingredients: ["Potatoes", "Bell Pepper", "Onion", "Vegetables", "Olive Oil", "Garlic", "Rosemary"], steps: ["Preheat oven to 425F and line a large tray with foil", "Cut all vegetables into similar-sized chunks", "Toss with olive oil, garlic, rosemary, salt, and pepper", "Spread in a single layer — don't crowd or they steam", "Roast 35 minutes, turning once halfway through", "Serve as a side or over rice with a fried egg on top"], prepTimeMinutes: 45, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "leaf.fill"),

            Recipe(title: "Banana Bread", summary: "Moist, golden loaf — the perfect use for over-ripe bananas", ingredients: ["Bananas", "Flour", "Sugar", "Eggs", "Butter", "Cinnamon", "Vanilla Extract"], steps: ["Preheat oven to 350F and grease a 9×5 loaf pan", "Mash 3 very ripe bananas with a fork until smooth", "Mix in melted butter, sugar, a beaten egg, and vanilla", "Stir in flour, cinnamon, and a pinch of salt — do not over-mix", "Pour batter into the pan and bake 55-60 minutes", "Cool on a wire rack for 10 minutes before slicing"], prepTimeMinutes: 70, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 7, imageSystemName: "cup.and.saucer.fill"),

            Recipe(title: "Spaghetti Carbonara", summary: "Roman classic — silky egg-and-cheese sauce with crispy pancetta", ingredients: ["Pasta", "Eggs", "Cheddar Cheese", "Garlic", "Olive Oil", "Butter"], steps: ["Boil spaghetti in well-salted water until al dente", "Whisk eggs with grated cheese and lots of black pepper", "Sauté garlic in olive oil until fragrant, remove from heat", "Drain pasta, reserving a cup of pasta water", "Working off the heat, toss pasta with egg mixture and garlic oil", "Add pasta water a splash at a time until silky — serve immediately"], prepTimeMinutes: 18, difficulty: .medium, matchingIngredientCount: 0, totalIngredientCount: 6, imageSystemName: "fork.knife"),

            Recipe(title: "Avocado Toast", summary: "Elevated toast with smashed avocado, chilli flakes, and a poached egg", ingredients: ["Sourdough Bread", "Avocados", "Eggs", "Lemon", "Olive Oil"], steps: ["Toast sourdough until golden and crisp", "Mash avocado with lemon juice, salt, and pepper", "Bring a pan of water to a gentle simmer, add a splash of vinegar", "Crack an egg into a cup, swirl the water, slide egg in", "Poach for 3-4 minutes for a runny yolk", "Pile avocado on toast, top with egg, chilli flakes, and olive oil"], prepTimeMinutes: 12, difficulty: .easy, matchingIngredientCount: 0, totalIngredientCount: 5, imageSystemName: "fork.knife"),
        ]
    }
}
