import Foundation
import os

@Observable @MainActor
final class RecipeService {
    private(set) var recipes: [Recipe] = []
    private let logger = PSLogger(category: .recipe)

    // Singleton instance with cached recipe database
    static let shared = RecipeService()
    static let cachedRecipes = RecipeService.buildRecipeDatabase()

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
                imageSystemName: recipe.imageSystemName,
                isLeftoverHero: recipe.isLeftoverHero,
                substitutions: recipe.substitutions
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

    // MARK: - Shelf-Life Prioritisation

    /// Returns matching recipes sorted by expiry urgency of the pantry items they use.
    /// Items expiring in <24h boost a recipe's score dramatically, ensuring the app
    /// always surfaces "rescue recipes" before food is wasted.
    func urgencyPrioritisedRecipes(items: [FreshliItem]) -> [Recipe] {
        guard !items.isEmpty else { return [] }

        let now = Date()
        let day: TimeInterval = 86_400

        // Build name → urgency multiplier
        var urgencyMap: [String: Double] = [:]
        for item in items {
            let secs = item.expiryDate.timeIntervalSince(now)
            let multiplier: Double
            if secs < 0          { multiplier = 200 }   // already expired
            else if secs < day   { multiplier = 100 }   // < 24 h
            else if secs < 3*day { multiplier = 20  }   // 1-3 days
            else if secs < 7*day { multiplier = 4   }   // 3-7 days
            else                 { multiplier = 1   }
            urgencyMap[item.name.lowercased()] = multiplier
        }

        let matched = recipesForFreshli(items: items)

        let scored: [(Recipe, Double)] = matched.map { recipe in
            var score: Double = 0
            for ingredient in recipe.ingredients {
                let lower = ingredient.lowercased()
                if let multiplier = urgencyMap.first(where: {
                    lower.localizedCaseInsensitiveContains($0.key) ||
                    $0.key.localizedCaseInsensitiveContains(lower)
                })?.value {
                    score += multiplier
                }
            }
            return (recipe, score)
        }

        return scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// The pantry item expiring soonest that is used in this recipe.
    func mostUrgentIngredient(for recipe: Recipe, items: [FreshliItem]) -> FreshliItem? {
        items
            .filter { item in
                recipe.ingredients.contains(where: {
                    $0.localizedCaseInsensitiveContains(item.name) ||
                    item.name.localizedCaseInsensitiveContains($0)
                })
            }
            .min(by: { $0.expiryDate < $1.expiryDate })
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

            // MARK: — Leftover Hero Recipes
            // Curated specifically for reinventing common leftovers.
            // Each includes substitutions so users can always find a swap.

            Recipe(
                title: "Chicken Tortilla Soup",
                summary: "One-pot hero that transforms leftover chicken into a bold, smoky Mexican soup ready in 20 minutes",
                ingredients: ["Cooked Chicken", "Black Beans", "Canned Tomatoes", "Chicken Broth", "Onion", "Garlic", "Tortilla Strips", "Cumin"],
                steps: [
                    "Shred leftover cooked chicken into bite-sized pieces",
                    "Sauté diced onion and garlic in oil for 3 minutes until soft",
                    "Add cumin, stir for 30 seconds until fragrant",
                    "Pour in canned tomatoes, broth, and drained black beans",
                    "Simmer 10 minutes, then stir in shredded chicken",
                    "Serve topped with crispy tortilla strips, lime juice, and sour cream"
                ],
                prepTimeMinutes: 22,
                difficulty: .easy,
                matchingIngredientCount: 0,
                totalIngredientCount: 8,
                imageSystemName: "fork.knife",
                isLeftoverHero: true,
                substitutions: [
                    "Cooked Chicken": ["Rotisserie Chicken", "Canned Tuna", "Chickpeas", "Tofu", "Cooked Turkey"],
                    "Black Beans": ["Kidney Beans", "Pinto Beans", "Lentils", "Cannellini Beans"],
                    "Tortilla Strips": ["Corn Chips", "Croutons", "Pita Chips", "Crackers"],
                    "Canned Tomatoes": ["Fresh Tomatoes", "Salsa", "Tomato Passata", "Diced Tinned Tomatoes"],
                    "Chicken Broth": ["Vegetable Stock", "Water + Bouillon Cube", "Beef Broth"]
                ]
            ),

            Recipe(
                title: "Leftover Fried Rice",
                summary: "The ultimate leftover transformer — cold rice, odds-and-ends veggies, and eggs become a restaurant-quality stir-fry",
                ingredients: ["Cooked Rice", "Eggs", "Mixed Vegetables", "Soy Sauce", "Sesame Oil", "Garlic", "Green Onions"],
                steps: [
                    "Use day-old cold rice — fresh rice makes it soggy",
                    "Beat eggs and scramble in a very hot wok until just set, push to sides",
                    "Add minced garlic, stir 30 seconds",
                    "Add cold rice and press flat — let it fry undisturbed for 2 minutes to get crispy bits",
                    "Toss everything together with any leftover vegetables",
                    "Season with soy sauce, finish with sesame oil and sliced green onions"
                ],
                prepTimeMinutes: 15,
                difficulty: .easy,
                matchingIngredientCount: 0,
                totalIngredientCount: 7,
                imageSystemName: "frying.pan.fill",
                isLeftoverHero: true,
                substitutions: [
                    "Cooked Rice": ["Cauliflower Rice", "Quinoa", "Leftover Noodles", "Leftover Couscous"],
                    "Mixed Vegetables": ["Frozen Peas", "Corn", "Carrot", "Broccoli", "Bell Pepper", "Spinach"],
                    "Soy Sauce": ["Tamari", "Coconut Aminos", "Fish Sauce", "Worcestershire Sauce"],
                    "Sesame Oil": ["Olive Oil", "Chilli Oil", "Any Neutral Oil"],
                    "Green Onions": ["Chives", "Parsley", "Leek", "Any Fresh Herb"]
                ]
            ),

            Recipe(
                title: "Hearty Vegetable Soup",
                summary: "Clear the fridge in one pot — any combination of vegetables becomes a nourishing, deeply flavoured soup",
                ingredients: ["Mixed Vegetables", "Vegetable Broth", "Canned Tomatoes", "Onion", "Garlic", "Pasta", "Olive Oil", "Herbs"],
                steps: [
                    "Dice onion and any firm vegetables (carrot, potato, celery) into similar-sized pieces",
                    "Sauté onion and garlic in olive oil for 4 minutes",
                    "Add all firm vegetables and cook 3 minutes more",
                    "Pour in broth and canned tomatoes, bring to a boil",
                    "Add pasta or grains if using, simmer until tender (8-10 min)",
                    "Stir in any leafy greens in the last 2 minutes, season well and serve"
                ],
                prepTimeMinutes: 30,
                difficulty: .easy,
                matchingIngredientCount: 0,
                totalIngredientCount: 8,
                imageSystemName: "drop.fill",
                isLeftoverHero: true,
                substitutions: [
                    "Mixed Vegetables": ["Carrot", "Celery", "Zucchini", "Potato", "Sweet Potato", "Pumpkin", "Broccoli"],
                    "Vegetable Broth": ["Chicken Stock", "Beef Stock", "Water + Stock Cube"],
                    "Pasta": ["Rice", "Barley", "Lentils", "Chickpeas", "Any Grains"],
                    "Herbs": ["Thyme", "Rosemary", "Parsley", "Basil", "Bay Leaf", "Mixed Italian Herbs"],
                    "Canned Tomatoes": ["Fresh Tomatoes", "Tomato Paste + Water", "Salsa"]
                ]
            ),

            Recipe(
                title: "Pasta Frittata",
                summary: "Italian street food classic that turns leftover pasta into a golden, crispy-edged egg cake — incredible hot or cold",
                ingredients: ["Cooked Pasta", "Eggs", "Parmesan Cheese", "Garlic", "Olive Oil", "Parsley", "Salt", "Pepper"],
                steps: [
                    "Beat 4-5 eggs with grated parmesan, salt, pepper, and chopped parsley",
                    "Fold in leftover cooked pasta — any shape works",
                    "Heat olive oil with garlic in a 22cm oven-safe skillet",
                    "Pour in pasta-egg mixture and press flat with a spatula",
                    "Cook over medium-low for 8-10 minutes until edges are set",
                    "Finish under the grill for 3-4 minutes until top is golden, slice like a pizza"
                ],
                prepTimeMinutes: 18,
                difficulty: .easy,
                matchingIngredientCount: 0,
                totalIngredientCount: 8,
                imageSystemName: "frying.pan.fill",
                isLeftoverHero: true,
                substitutions: [
                    "Cooked Pasta": ["Leftover Rice", "Leftover Noodles", "Leftover Gnocchi", "Leftover Couscous"],
                    "Parmesan Cheese": ["Pecorino", "Cheddar", "Gruyère", "Any Hard Cheese", "Nutritional Yeast"],
                    "Parsley": ["Basil", "Chives", "Spinach", "Rocket", "Any Fresh Herb"],
                    "Garlic": ["Garlic Powder", "Onion", "Shallots"]
                ]
            ),

            Recipe(
                title: "Classic Bread Pudding",
                summary: "Give stale bread a second life — this custardy, vanilla-scented pudding is pure comfort and takes just minutes to prepare",
                ingredients: ["Stale Bread", "Eggs", "Milk", "Sugar", "Butter", "Vanilla Extract", "Cinnamon", "Raisins"],
                steps: [
                    "Preheat oven to 350°F. Cube stale bread into rough 2cm pieces",
                    "Whisk eggs, milk, sugar, vanilla, and cinnamon together",
                    "Grease a baking dish with butter and layer in bread pieces",
                    "Pour custard evenly over bread, press down gently and let soak 10 minutes",
                    "Scatter raisins over the top, dot with small pieces of butter",
                    "Bake 35-40 minutes until golden and set, serve warm with cream"
                ],
                prepTimeMinutes: 55,
                difficulty: .easy,
                matchingIngredientCount: 0,
                totalIngredientCount: 8,
                imageSystemName: "oven.fill",
                isLeftoverHero: true,
                substitutions: [
                    "Stale Bread": ["Brioche", "Croissants", "Bagels", "Hot Cross Buns", "Panettone", "Any Bread"],
                    "Raisins": ["Chocolate Chips", "Dried Cranberries", "Sultanas", "Chopped Dried Apricots"],
                    "Milk": ["Cream", "Plant-Based Milk", "Half-and-Half", "Oat Milk"],
                    "Vanilla Extract": ["Vanilla Paste", "Almond Extract", "Orange Zest", "Cinnamon"]
                ]
            ),

            Recipe(
                title: "Potato & Veggie Hash",
                summary: "The ultimate leftover breakfast hash — crispy golden potatoes with any leftover vegetables, topped with fried eggs",
                ingredients: ["Cooked Potatoes", "Mixed Vegetables", "Eggs", "Onion", "Garlic", "Olive Oil", "Paprika", "Herbs"],
                steps: [
                    "Dice cooked potatoes into 2cm cubes — they fry best when already cooked",
                    "Heat oil in a large cast-iron skillet over medium-high heat",
                    "Add diced onion, cook 3 minutes, then add garlic and paprika",
                    "Add potatoes and press down, let them fry undisturbed 4 minutes for a golden crust",
                    "Fold in any leftover vegetables, season generously",
                    "Make wells in the hash, crack in eggs, cover and cook until whites are set but yolks still runny"
                ],
                prepTimeMinutes: 20,
                difficulty: .easy,
                matchingIngredientCount: 0,
                totalIngredientCount: 8,
                imageSystemName: "frying.pan.fill",
                isLeftoverHero: true,
                substitutions: [
                    "Cooked Potatoes": ["Sweet Potato", "Leftover Roasted Vegetables", "Canned Chickpeas", "Butternut Squash"],
                    "Mixed Vegetables": ["Bell Pepper", "Mushrooms", "Zucchini", "Spinach", "Kale", "Corn", "Peas"],
                    "Paprika": ["Smoked Paprika", "Cumin", "Chilli Flakes", "Cajun Seasoning", "Mixed Spice"],
                    "Eggs": ["Tofu Scramble", "Extra Vegetables Only"],
                    "Herbs": ["Parsley", "Chives", "Thyme", "Rosemary", "Mixed Herbs"]
                ]
            ),
        ]
    }

    // MARK: - Leftover Heroes

    /// All built-in leftover hero recipes (unfiltered, regardless of pantry).
    var leftoverHeroes: [Recipe] {
        Self.cachedRecipes.filter { $0.isLeftoverHero }
    }
}
