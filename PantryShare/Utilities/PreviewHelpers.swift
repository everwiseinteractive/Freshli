import SwiftUI
import SwiftData

@Observable
final class PreviewSampleData {
    static let shared = PreviewSampleData()

    var samplePantryItems: [PantryItem] {
        [
            PantryItem(name: "Organic Milk", category: .dairy, storageLocation: .fridge, quantity: 1, unit: .liters, expiryDate: .daysFromNow(2), barcode: nil, notes: nil),
            PantryItem(name: "Sourdough Bread", category: .bakery, storageLocation: .counter, quantity: 1, unit: .pieces, expiryDate: .daysFromNow(1), barcode: nil, notes: nil),
            PantryItem(name: "Chicken Breast", category: .meat, storageLocation: .fridge, quantity: 500, unit: .grams, expiryDate: .daysFromNow(0), barcode: nil, notes: nil),
            PantryItem(name: "Greek Yogurt", category: .dairy, storageLocation: .fridge, quantity: 2, unit: .pieces, expiryDate: .daysFromNow(5), barcode: nil, notes: nil),
            PantryItem(name: "Bananas", category: .fruits, storageLocation: .counter, quantity: 6, unit: .pieces, expiryDate: .daysFromNow(3), barcode: nil, notes: nil),
            PantryItem(name: "Frozen Peas", category: .frozen, storageLocation: .freezer, quantity: 1, unit: .bags, expiryDate: .daysFromNow(60), barcode: nil, notes: nil),
            PantryItem(name: "Canned Tomatoes", category: .canned, storageLocation: .pantry, quantity: 3, unit: .cans, expiryDate: .daysFromNow(180), barcode: nil, notes: nil),
            PantryItem(name: "Pasta", category: .grains, storageLocation: .pantry, quantity: 2, unit: .packs, expiryDate: .daysFromNow(120), barcode: nil, notes: nil),
            PantryItem(name: "Fresh Salmon", category: .seafood, storageLocation: .fridge, quantity: 300, unit: .grams, expiryDate: .daysFromNow(-1), barcode: nil, notes: nil),
            PantryItem(name: "Avocados", category: .fruits, storageLocation: .counter, quantity: 3, unit: .pieces, expiryDate: .daysFromNow(2), barcode: nil, notes: nil),
        ]
    }

    var sampleRecipes: [Recipe] {
        [
            Recipe(
                title: "Banana Smoothie Bowl",
                summary: "A quick, healthy breakfast using ripe bananas and yogurt",
                ingredients: ["Bananas", "Greek Yogurt", "Honey", "Granola"],
                steps: ["Blend bananas and yogurt until smooth", "Pour into bowl", "Top with granola and honey"],
                prepTimeMinutes: 10,
                difficulty: .easy,
                matchingIngredientCount: 2,
                totalIngredientCount: 4,
                imageSystemName: "cup.and.saucer.fill"
            ),
            Recipe(
                title: "Chicken Stir-Fry",
                summary: "Use up chicken breast with quick stir-fry vegetables",
                ingredients: ["Chicken Breast", "Frozen Peas", "Soy Sauce", "Rice"],
                steps: ["Slice chicken", "Heat oil in wok", "Cook chicken until golden", "Add peas and sauce", "Serve over rice"],
                prepTimeMinutes: 25,
                difficulty: .medium,
                matchingIngredientCount: 2,
                totalIngredientCount: 4,
                imageSystemName: "frying.pan.fill"
            ),
            Recipe(
                title: "Simple Pasta Pomodoro",
                summary: "Classic Italian pasta with canned tomato sauce",
                ingredients: ["Pasta", "Canned Tomatoes", "Garlic", "Basil", "Olive Oil"],
                steps: ["Boil pasta", "Sauté garlic in olive oil", "Add tomatoes and simmer", "Toss with pasta", "Garnish with basil"],
                prepTimeMinutes: 20,
                difficulty: .easy,
                matchingIngredientCount: 2,
                totalIngredientCount: 5,
                imageSystemName: "fork.knife"
            ),
            Recipe(
                title: "Salmon & Avocado Bowl",
                summary: "Fresh bowl with pan-seared salmon and creamy avocado",
                ingredients: ["Fresh Salmon", "Avocados", "Rice", "Soy Sauce", "Sesame Seeds"],
                steps: ["Cook rice", "Pan-sear salmon", "Slice avocado", "Assemble bowl", "Drizzle with soy sauce"],
                prepTimeMinutes: 30,
                difficulty: .medium,
                matchingIngredientCount: 2,
                totalIngredientCount: 5,
                imageSystemName: "fish.fill"
            ),
        ]
    }
}
