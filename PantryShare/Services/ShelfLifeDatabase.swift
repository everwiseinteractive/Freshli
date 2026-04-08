import Foundation

// MARK: - Produce Shelf Life Data Model

struct ProduceShelfLife {
    let name: String
    let category: FoodCategory
    let defaultStorage: StorageLocation
    let shelfLifeDays: [StorageLocation: Int]
    let defaultUnit: MeasurementUnit
    let ripenessTips: String?

    init(
        name: String,
        category: FoodCategory,
        defaultStorage: StorageLocation,
        shelfLifeDays: [StorageLocation: Int],
        defaultUnit: MeasurementUnit = .pieces,
        ripenessTips: String? = nil
    ) {
        self.name = name
        self.category = category
        self.defaultStorage = defaultStorage
        self.shelfLifeDays = shelfLifeDays
        self.defaultUnit = defaultUnit
        self.ripenessTips = ripenessTips
    }
}

// MARK: - Shelf Life Database

struct ShelfLifeDatabase {
    private static let database: [ProduceShelfLife] = [
        // FRUITS
        ProduceShelfLife(
            name: "banana",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 60
            ],
            ripenessTips: "Green banana: +3 days. Spotted banana: -2 days"
        ),
        ProduceShelfLife(
            name: "Granny Smith Apple",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 30,
                .freezer: 120
            ]
        ),
        ProduceShelfLife(
            name: "apple",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 30,
                .freezer: 120
            ]
        ),
        ProduceShelfLife(
            name: "orange",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 14,
                .fridge: 30,
                .freezer: 90
            ]
        ),
        ProduceShelfLife(
            name: "lemon",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 14,
                .fridge: 30,
                .freezer: 120
            ]
        ),
        ProduceShelfLife(
            name: "lime",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 14,
                .fridge: 30,
                .freezer: 90
            ]
        ),
        ProduceShelfLife(
            name: "strawberry",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 7,
                .freezer: 365
            ],
            ripenessTips: "Fully red, fragrant strawberries last longest"
        ),
        ProduceShelfLife(
            name: "blueberry",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 14,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "raspberry",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 5,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "grape",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 14,
                .freezer: 90
            ]
        ),
        ProduceShelfLife(
            name: "peach",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 7,
                .freezer: 180
            ],
            ripenessTips: "Should give slightly to gentle pressure when ripe"
        ),
        ProduceShelfLife(
            name: "pear",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 14,
                .freezer: 180
            ],
            ripenessTips: "Check ripeness near neck. Ripen at room temperature"
        ),
        ProduceShelfLife(
            name: "cherry",
            category: .fruits,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 7,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "kiwi",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 14,
                .freezer: 180
            ],
            ripenessTips: "Ripen at room temperature, then refrigerate"
        ),
        ProduceShelfLife(
            name: "mango",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 180
            ],
            ripenessTips: "Ripe mango yields slightly to pressure"
        ),
        ProduceShelfLife(
            name: "papaya",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 7,
                .freezer: 120
            ]
        ),
        ProduceShelfLife(
            name: "pineapple",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 7,
                .freezer: 180
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "watermelon",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 7,
                .fridge: 21,
                .freezer: 365
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "cantaloupe",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 180
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "avocado",
            category: .fruits,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 180
            ],
            ripenessTips: "Ripen at room temperature, refrigerate when soft"
        ),

        // VEGETABLES
        ProduceShelfLife(
            name: "broccoli",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 7,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "cabbage",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 30,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "carrot",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 30,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "celery",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 21,
                .freezer: 180
            ]
        ),
        ProduceShelfLife(
            name: "corn",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 5,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "cucumber",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 7,
                .freezer: 90
            ]
        ),
        ProduceShelfLife(
            name: "eggplant",
            category: .vegetables,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 7,
                .freezer: 180
            ]
        ),
        ProduceShelfLife(
            name: "garlic",
            category: .vegetables,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .counter: 30,
                .fridge: 60,
                .pantry: 180
            ]
        ),
        ProduceShelfLife(
            name: "ginger",
            category: .vegetables,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .counter: 14,
                .fridge: 30,
                .pantry: 180
            ]
        ),
        ProduceShelfLife(
            name: "green bean",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 7,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "kale",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 7,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "lettuce",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 10,
                .freezer: 60
            ]
        ),
        ProduceShelfLife(
            name: "mushroom",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 7,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "onion",
            category: .vegetables,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .counter: 14,
                .fridge: 60,
                .pantry: 180
            ]
        ),
        ProduceShelfLife(
            name: "pea",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 5,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "bell pepper",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 14,
                .freezer: 180
            ]
        ),
        ProduceShelfLife(
            name: "potato",
            category: .vegetables,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .counter: 7,
                .fridge: 30,
                .pantry: 60
            ]
        ),
        ProduceShelfLife(
            name: "pumpkin",
            category: .vegetables,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 30,
                .fridge: 60,
                .pantry: 90
            ]
        ),
        ProduceShelfLife(
            name: "radish",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 14,
                .freezer: 90
            ]
        ),
        ProduceShelfLife(
            name: "spinach",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 1,
                .fridge: 7,
                .freezer: 365
            ]
        ),
        ProduceShelfLife(
            name: "squash",
            category: .vegetables,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 14,
                .fridge: 30,
                .pantry: 60
            ]
        ),
        ProduceShelfLife(
            name: "sweet potato",
            category: .vegetables,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .counter: 7,
                .fridge: 21,
                .pantry: 60
            ]
        ),
        ProduceShelfLife(
            name: "tomato",
            category: .vegetables,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 180
            ],
            ripenessTips: "Refrigerate only when fully ripe"
        ),
        ProduceShelfLife(
            name: "zucchini",
            category: .vegetables,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 7,
                .freezer: 365
            ]
        ),

        // DAIRY
        ProduceShelfLife(
            name: "milk",
            category: .dairy,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 10,
                .freezer: 180
            ],
            defaultUnit: .milliliters
        ),
        ProduceShelfLife(
            name: "cheese",
            category: .dairy,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 30,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "yogurt",
            category: .dairy,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 14,
                .freezer: 90
            ],
            defaultUnit: .milliliters
        ),
        ProduceShelfLife(
            name: "butter",
            category: .dairy,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 60,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),

        // MEAT
        ProduceShelfLife(
            name: "beef",
            category: .meat,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 3,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "chicken",
            category: .meat,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 2,
                .freezer: 365
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "pork",
            category: .meat,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 3,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "lamb",
            category: .meat,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 3,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "bacon",
            category: .meat,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 7,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),

        // SEAFOOD
        ProduceShelfLife(
            name: "salmon",
            category: .seafood,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 1,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "tuna",
            category: .seafood,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 1,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "shrimp",
            category: .seafood,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 1,
                .freezer: 180
            ],
            defaultUnit: .grams
        ),

        // BAKERY
        ProduceShelfLife(
            name: "bread",
            category: .bakery,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 180
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "bagel",
            category: .bakery,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 5,
                .fridge: 10,
                .freezer: 180
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "croissant",
            category: .bakery,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 2,
                .fridge: 7,
                .freezer: 180
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "muffin",
            category: .bakery,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 3,
                .fridge: 7,
                .freezer: 180
            ],
            defaultUnit: .pieces
        ),

        // CANNED
        ProduceShelfLife(
            name: "canned beans",
            category: .canned,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .fridge: 365,
                .counter: 365
            ],
            defaultUnit: .cans
        ),
        ProduceShelfLife(
            name: "canned vegetables",
            category: .canned,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .fridge: 365,
                .counter: 365
            ],
            defaultUnit: .cans
        ),

        // GRAINS
        ProduceShelfLife(
            name: "rice",
            category: .grains,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .counter: 365
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "pasta",
            category: .grains,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .counter: 365
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "cereal",
            category: .grains,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 180,
                .counter: 180
            ],
            defaultUnit: .bags
        ),

        // BEVERAGES
        ProduceShelfLife(
            name: "milk",
            category: .beverages,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 10,
                .freezer: 180
            ],
            defaultUnit: .milliliters
        ),
        ProduceShelfLife(
            name: "juice",
            category: .beverages,
            defaultStorage: .fridge,
            shelfLifeDays: [
                .fridge: 14,
                .freezer: 365
            ],
            defaultUnit: .milliliters
        ),
        ProduceShelfLife(
            name: "coffee",
            category: .beverages,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 180,
                .fridge: 365,
                .counter: 30
            ],
            defaultUnit: .grams
        ),
        ProduceShelfLife(
            name: "tea",
            category: .beverages,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .counter: 180
            ],
            defaultUnit: .bags
        ),

        // CONDIMENTS
        ProduceShelfLife(
            name: "ketchup",
            category: .condiments,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 180,
                .fridge: 365,
                .counter: 180
            ],
            defaultUnit: .bottles
        ),
        ProduceShelfLife(
            name: "mustard",
            category: .condiments,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .fridge: 365,
                .counter: 180
            ],
            defaultUnit: .bottles
        ),
        ProduceShelfLife(
            name: "honey",
            category: .condiments,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 365,
                .counter: 365
            ],
            defaultUnit: .milliliters
        ),

        // SNACKS
        ProduceShelfLife(
            name: "chips",
            category: .snacks,
            defaultStorage: .pantry,
            shelfLifeDays: [
                .pantry: 180,
                .counter: 60
            ],
            defaultUnit: .bags
        ),
        ProduceShelfLife(
            name: "chocolate",
            category: .snacks,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 365,
                .fridge: 365,
                .pantry: 365
            ],
            defaultUnit: .pieces
        ),
        ProduceShelfLife(
            name: "cookie",
            category: .snacks,
            defaultStorage: .counter,
            shelfLifeDays: [
                .counter: 30,
                .fridge: 60,
                .pantry: 90
            ],
            defaultUnit: .pieces
        ),
    ]

    // MARK: - Public Methods

    /// Look up produce information by friendly name.
    /// - Parameter name: The friendly name of the produce item
    /// - Returns: ProduceShelfLife if found, nil otherwise
    static func lookup(by name: String) -> ProduceShelfLife? {
        let searchName = name.lowercased()

        // Exact match first
        if let match = database.first(where: { $0.name.lowercased() == searchName }) {
            return match
        }

        // Partial match
        if let match = database.first(where: { searchName.contains($0.name.lowercased()) || $0.name.lowercased().contains(searchName) }) {
            return match
        }

        return nil
    }

    /// Look up produce by food category.
    /// - Parameter category: The FoodCategory to filter by
    /// - Returns: Array of all ProduceShelfLife items in that category
    static func lookup(by category: FoodCategory) -> [ProduceShelfLife] {
        database.filter { $0.category == category }
    }

    /// Get all database entries.
    /// - Returns: All available ProduceShelfLife items
    static func all() -> [ProduceShelfLife] {
        database
    }
}
