import Foundation

// MARK: - Cultural Region Enum

enum CulturalRegion: String, Codable, CaseIterable, Identifiable {
    case northAmerica = "North America"
    case europe = "Europe"
    case eastAsia = "East Asia"
    case southAsia = "South Asia"
    case middleEast = "Middle East"
    case latinAmerica = "Latin America"
    case africa = "Africa"
    case southeastAsia = "Southeast Asia"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .northAmerica: return String(localized: "North America")
        case .europe: return String(localized: "Europe")
        case .eastAsia: return String(localized: "East Asia")
        case .southAsia: return String(localized: "South Asia")
        case .middleEast: return String(localized: "Middle East")
        case .latinAmerica: return String(localized: "Latin America")
        case .africa: return String(localized: "Africa")
        case .southeastAsia: return String(localized: "Southeast Asia")
        }
    }

    var flagEmoji: String {
        switch self {
        case .northAmerica: return "🇺🇸"
        case .europe: return "🇪🇺"
        case .eastAsia: return "🇯🇵"
        case .southAsia: return "🇮🇳"
        case .middleEast: return "🇸🇦"
        case .latinAmerica: return "🇲🇽"
        case .africa: return "🇿🇦"
        case .southeastAsia: return "🇹🇭"
        }
    }
}

// MARK: - Cultural Food Item

struct CulturalFoodItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let localNames: [String: String] // locale -> local name
    let category: String
    let region: CulturalRegion
    let defaultShelfLifeDays: Int
    let storageAdvice: String
    let culturalNote: String

    init(
        name: String,
        localNames: [String: String] = [:],
        category: String,
        region: CulturalRegion,
        defaultShelfLifeDays: Int,
        storageAdvice: String,
        culturalNote: String
    ) {
        self.id = UUID()
        self.name = name
        self.localNames = localNames
        self.category = category
        self.region = region
        self.defaultShelfLifeDays = defaultShelfLifeDays
        self.storageAdvice = storageAdvice
        self.culturalNote = culturalNote
    }
}

// MARK: - Cultural Food Database

final class CulturalFoodDatabase {
    static let shared = CulturalFoodDatabase()

    private let items: [CulturalFoodItem]

    init() {
        items = CulturalFoodDatabase.buildDatabase()
    }

    // MARK: - Database Builder

    private static func buildDatabase() -> [CulturalFoodItem] {
        var database: [CulturalFoodItem] = []

        // MARK: - East Asia

        database.append(CulturalFoodItem(
            name: "Kimchi",
            localNames: ["ko": "김치"],
            category: "Fermented",
            region: .eastAsia,
            defaultShelfLifeDays: 180,
            storageAdvice: "Refrigerate in airtight container. Best consumed within 3-6 months, but keeps for up to 12 months.",
            culturalNote: "Essential Korean fermented dish. Longer storage develops deeper flavor."
        ))

        database.append(CulturalFoodItem(
            name: "Tofu",
            localNames: ["zh": "豆腐", "ja": "豆腐"],
            category: "Protein",
            region: .eastAsia,
            defaultShelfLifeDays: 5,
            storageAdvice: "Refrigerate in water, change water daily. Use within 3-5 days of opening.",
            culturalNote: "Versatile staple in East Asian cuisine. Fresh tofu is best within 2-3 days."
        ))

        database.append(CulturalFoodItem(
            name: "Miso Paste",
            localNames: ["ja": "味噌"],
            category: "Condiment",
            region: .eastAsia,
            defaultShelfLifeDays: 365,
            storageAdvice: "Store in cool, dark place or refrigerate. Sealed containers last 1+ years.",
            culturalNote: "Fermented paste foundational to Japanese cooking. Improves with age in sealed containers."
        ))

        database.append(CulturalFoodItem(
            name: "Natto",
            localNames: ["ja": "納豆"],
            category: "Fermented",
            region: .eastAsia,
            defaultShelfLifeDays: 30,
            storageAdvice: "Keep frozen or refrigerated. Use within 2-4 weeks.",
            culturalNote: "Japanese fermented soybeans with distinctive pungent smell and sticky texture."
        ))

        database.append(CulturalFoodItem(
            name: "Cooked Rice",
            localNames: ["ja": "ご飯", "zh": "米饭"],
            category: "Grain",
            region: .eastAsia,
            defaultShelfLifeDays: 4,
            storageAdvice: "Refrigerate in covered container. Use within 3-4 days.",
            culturalNote: "Staple grain in East Asian diets. Should be properly stored to prevent bacterial growth."
        ))

        // MARK: - South Asia

        database.append(CulturalFoodItem(
            name: "Ghee",
            localNames: ["hi": "घी", "ur": "گھی"],
            category: "Fat/Oil",
            region: .southAsia,
            defaultShelfLifeDays: 270,
            storageAdvice: "Store in cool, dark place. Keeps for 8-9 months due to low moisture content.",
            culturalNote: "Clarified butter essential to Indian cooking. Long shelf life when properly stored."
        ))

        database.append(CulturalFoodItem(
            name: "Paneer",
            localNames: ["hi": "पनीर"],
            category: "Dairy",
            region: .southAsia,
            defaultShelfLifeDays: 7,
            storageAdvice: "Refrigerate in airtight container with water. Use within 5-7 days.",
            culturalNote: "Fresh cheese used in countless South Asian dishes. Quality deteriorates quickly after opening."
        ))

        database.append(CulturalFoodItem(
            name: "Dosa Batter",
            localNames: ["ta": "தோசை"],
            category: "Prepared",
            region: .southAsia,
            defaultShelfLifeDays: 3,
            storageAdvice: "Refrigerate in sealed container. Use within 2-3 days.",
            culturalNote: "Fermented rice and lentil batter for South Indian crepes. Best when fresh."
        ))

        database.append(CulturalFoodItem(
            name: "Pickle/Achaar",
            localNames: ["hi": "अचार", "ta": "உள்ளாடு"],
            category: "Preserved",
            region: .southAsia,
            defaultShelfLifeDays: 365,
            storageAdvice: "Store in cool, dark place in sealed jar. Lasts 1+ years if properly preserved.",
            culturalNote: "Spiced preserved vegetables integral to Indian meals. Improves with age."
        ))

        database.append(CulturalFoodItem(
            name: "Roti/Flatbread",
            localNames: ["hi": "रोटी", "ur": "روٹی"],
            category: "Bread",
            region: .southAsia,
            defaultShelfLifeDays: 3,
            storageAdvice: "Store in sealed container or wrap. Refrigerate for extended freshness, use within 3-4 days.",
            culturalNote: "Daily staple bread in South Asia. Best consumed fresh but can be refrigerated."
        ))

        // MARK: - Middle East

        database.append(CulturalFoodItem(
            name: "Hummus",
            localNames: ["ar": "حمص"],
            category: "Dip",
            region: .middleEast,
            defaultShelfLifeDays: 6,
            storageAdvice: "Refrigerate in sealed container. Drizzle olive oil on top. Use within 4-6 days.",
            culturalNote: "Chickpea-based dip popular across Middle East. Best consumed fresh."
        ))

        database.append(CulturalFoodItem(
            name: "Tahini",
            localNames: ["ar": "طحينة"],
            category: "Condiment",
            region: .middleEast,
            defaultShelfLifeDays: 180,
            storageAdvice: "Store in cool, dark place. Sealed jar keeps for 6+ months.",
            culturalNote: "Sesame seed paste. Oil separation is normal; stir before use."
        ))

        database.append(CulturalFoodItem(
            name: "Labneh",
            localNames: ["ar": "لبنة"],
            category: "Dairy",
            region: .middleEast,
            defaultShelfLifeDays: 14,
            storageAdvice: "Refrigerate in airtight container, preferably in olive oil. Use within 2 weeks.",
            culturalNote: "Strained yogurt cheese. Oil preservation extends shelf life."
        ))

        database.append(CulturalFoodItem(
            name: "Pita Bread",
            localNames: ["ar": "خبز بيتا"],
            category: "Bread",
            region: .middleEast,
            defaultShelfLifeDays: 7,
            storageAdvice: "Store in sealed bag at room temperature or refrigerate. Freezes well.",
            culturalNote: "Pocket bread staple. Dries out quickly; proper storage maintains freshness."
        ))

        database.append(CulturalFoodItem(
            name: "Halloumi",
            localNames: ["el": "Χαλλούμι"],
            category: "Cheese",
            region: .middleEast,
            defaultShelfLifeDays: 14,
            storageAdvice: "Refrigerate in original brine. Use within 2 weeks of opening.",
            culturalNote: "Cheese with high melting point, perfect for grilling. Keeps well in brine."
        ))

        // MARK: - Latin America

        database.append(CulturalFoodItem(
            name: "Tortillas",
            localNames: ["es": "Tortillas"],
            category: "Bread",
            region: .latinAmerica,
            defaultShelfLifeDays: 7,
            storageAdvice: "Store in sealed bag at room temperature or refrigerate. Freezes well for months.",
            culturalNote: "Daily staple in Latin America. Proper storage prevents drying out."
        ))

        database.append(CulturalFoodItem(
            name: "Salsa Fresca",
            localNames: ["es": "Salsa fresca"],
            category: "Sauce",
            region: .latinAmerica,
            defaultShelfLifeDays: 7,
            storageAdvice: "Refrigerate in sealed container. Best consumed within 5-7 days.",
            culturalNote: "Fresh tomato-based sauce. Best made fresh but keeps several days refrigerated."
        ))

        database.append(CulturalFoodItem(
            name: "Queso Fresco",
            localNames: ["es": "Queso fresco"],
            category: "Cheese",
            region: .latinAmerica,
            defaultShelfLifeDays: 14,
            storageAdvice: "Refrigerate in sealed container with brine. Use within 2 weeks.",
            culturalNote: "Fresh crumbly cheese. Loses quality quickly after opening."
        ))

        database.append(CulturalFoodItem(
            name: "Plantains",
            localNames: ["es": "Plátanos"],
            category: "Produce",
            region: .latinAmerica,
            defaultShelfLifeDays: 7,
            storageAdvice: "Store at room temperature. Ripe plantains last about 1 week; refrigerate to extend.",
            culturalNote: "Staple starch. Ripeness determines use: green for savory, yellow for sweet preparations."
        ))

        // MARK: - Europe

        database.append(CulturalFoodItem(
            name: "Sauerkraut",
            localNames: ["de": "Sauerkraut"],
            category: "Fermented",
            region: .europe,
            defaultShelfLifeDays: 180,
            storageAdvice: "Refrigerate in sealed jar. Keeps for 4-6 months when properly fermented.",
            culturalNote: "Fermented cabbage staple in German cuisine. Benefits from long storage."
        ))

        database.append(CulturalFoodItem(
            name: "Prosciutto",
            localNames: ["it": "Prosciutto"],
            category: "Meat",
            region: .europe,
            defaultShelfLifeDays: 90,
            storageAdvice: "Refrigerate wrapped. Use within 2-3 months. Freezes well.",
            culturalNote: "Dry-cured ham. Longer storage develops more complex flavors."
        ))

        database.append(CulturalFoodItem(
            name: "Brie/Camembert",
            localNames: ["fr": "Brie/Camembert"],
            category: "Cheese",
            region: .europe,
            defaultShelfLifeDays: 14,
            storageAdvice: "Refrigerate in sealed container. Use within 1-2 weeks. Bring to room temperature before serving.",
            culturalNote: "Soft-ripened French cheeses. Quality varies with ripeness; best consumed fresh."
        ))

        database.append(CulturalFoodItem(
            name: "Sourdough Starter",
            localNames: ["de": "Sauerteig"],
            category: "Prepared",
            region: .europe,
            defaultShelfLifeDays: 36500,
            storageAdvice: "Refrigerate and feed weekly. Can last indefinitely with proper maintenance.",
            culturalNote: "Living culture for bread-making. Improves flavor over years."
        ))

        database.append(CulturalFoodItem(
            name: "Parmigiano-Reggiano",
            localNames: ["it": "Parmigiano-Reggiano"],
            category: "Cheese",
            region: .europe,
            defaultShelfLifeDays: 180,
            storageAdvice: "Wrap in cheese paper or parchment. Refrigerate. Keeps for months.",
            culturalNote: "Italian hard cheese. Long aging develops complex flavors."
        ))

        // MARK: - Africa

        database.append(CulturalFoodItem(
            name: "Injera",
            localNames: ["am": "ኢንጄራ"],
            category: "Bread",
            region: .africa,
            defaultShelfLifeDays: 4,
            storageAdvice: "Store in sealed bag at room temperature. Refrigerate to extend to 4 days.",
            culturalNote: "Spongy Ethiopian/Eritrean fermented flatbread. Best consumed fresh."
        ))

        database.append(CulturalFoodItem(
            name: "Fufu",
            localNames: ["yo": "Fufu"],
            category: "Starch",
            region: .africa,
            defaultShelfLifeDays: 2,
            storageAdvice: "Refrigerate in sealed container. Best eaten fresh; lasts 1-2 days.",
            culturalNote: "Pounded yam/plantain staple. Texture deteriorates quickly."
        ))

        database.append(CulturalFoodItem(
            name: "Berbere Spice",
            localNames: ["am": "በርበሬ"],
            category: "Spice",
            region: .africa,
            defaultShelfLifeDays: 180,
            storageAdvice: "Store in airtight container in cool, dark place. Lasts 6+ months.",
            culturalNote: "Complex Ethiopian spice blend. Flavor intensity improves with proper storage."
        ))

        database.append(CulturalFoodItem(
            name: "Palm Oil",
            localNames: ["yo": "Epo"],
            category: "Oil",
            region: .africa,
            defaultShelfLifeDays: 730,
            storageAdvice: "Store in cool place. Can solidify; reheat gently if needed. Keeps for years.",
            culturalNote: "Essential cooking oil in West African cuisine. Excellent shelf life."
        ))

        // MARK: - Southeast Asia

        database.append(CulturalFoodItem(
            name: "Fish Sauce",
            localNames: ["vi": "Nước mắm", "th": "น้ำปลา"],
            category: "Condiment",
            region: .southeastAsia,
            defaultShelfLifeDays: 365,
            storageAdvice: "Store in sealed bottle at room temperature. Keeps for 1+ years.",
            culturalNote: "Pungent fermented condiment essential to Southeast Asian cuisine. Improves with age."
        ))

        database.append(CulturalFoodItem(
            name: "Coconut Milk",
            localNames: ["th": "น้ำกะทิ", "id": "Santan"],
            category: "Liquid",
            region: .southeastAsia,
            defaultShelfLifeDays: 7,
            storageAdvice: "Refrigerate after opening. Use within 5-7 days or freeze in ice cube trays.",
            culturalNote: "Rich ingredient in curries and desserts. Separates naturally; stir before use."
        ))

        database.append(CulturalFoodItem(
            name: "Soy Sauce",
            localNames: ["th": "ซีอิ๊ว", "id": "Kecap manis"],
            category: "Condiment",
            region: .southeastAsia,
            defaultShelfLifeDays: 365,
            storageAdvice: "Store in sealed bottle. Keeps for 1+ years at room temperature.",
            culturalNote: "Fundamental seasoning. Flavor develops over time in sealed containers."
        ))

        database.append(CulturalFoodItem(
            name: "Tamarind Paste",
            localNames: ["th": "มะขาม", "id": "Asam"],
            category: "Condiment",
            region: .southeastAsia,
            defaultShelfLifeDays: 180,
            storageAdvice: "Store in sealed container in cool place. Lasts 6+ months.",
            culturalNote: "Sour ingredient from fruit. Essential to many Southeast Asian dishes."
        ))

        // MARK: - North America / General

        database.append(CulturalFoodItem(
            name: "Peanut Butter",
            localNames: ["en": "Peanut Butter"],
            category: "Condiment",
            region: .northAmerica,
            defaultShelfLifeDays: 90,
            storageAdvice: "Store in cool place or refrigerate after opening. Use within 3 months.",
            culturalNote: "American staple. Natural versions may have oil separation."
        ))

        database.append(CulturalFoodItem(
            name: "Maple Syrup",
            localNames: ["fr": "Sirop d'érable"],
            category: "Condiment",
            region: .northAmerica,
            defaultShelfLifeDays: 365,
            storageAdvice: "Store in sealed container at room temperature or refrigerate. Keeps for 1+ years.",
            culturalNote: "Canadian/North American classic. Crystallization is normal; warm gently to liquify."
        ))

        database.append(CulturalFoodItem(
            name: "Hot Sauce",
            localNames: ["es": "Salsa picante"],
            category: "Condiment",
            region: .northAmerica,
            defaultShelfLifeDays: 180,
            storageAdvice: "Store in sealed bottle. Keeps for 6+ months at room temperature.",
            culturalNote: "Shelf-stable condiment. Flavor can develop over time."
        ))

        return database
    }

    // MARK: - Query Methods

    func itemsForRegion(_ region: CulturalRegion) -> [CulturalFoodItem] {
        items.filter { $0.region == region }.sorted { $0.name < $1.name }
    }

    func searchItems(query: String) -> [CulturalFoodItem] {
        let lowercaseQuery = query.lowercased()
        return items.filter { item in
            item.name.lowercased().contains(lowercaseQuery) ||
            item.localNames.values.contains { $0.lowercased().contains(lowercaseQuery) }
        }.sorted { $0.name < $1.name }
    }

    func estimateShelfLife(for itemName: String, storage: String) -> Int {
        let searchResults = searchItems(query: itemName)

        if let foundItem = searchResults.first {
            // Adjust based on storage advice if applicable
            var days = foundItem.defaultShelfLifeDays

            // Example adjustments based on storage
            if storage.lowercased().contains("freezer") {
                days = min(Int(Double(days) * 2.5), 1095) // Up to 3x longer, capped at 3 years
            } else if storage.lowercased().contains("room temperature") {
                days = max(Int(Double(days) * 0.7), 1) // Slightly shorter
            }

            return days
        }

        // Default generic estimates
        return 7 // Conservative default
    }

    func getStorageAdvice(for itemName: String) -> String? {
        let searchResults = searchItems(query: itemName)
        return searchResults.first?.storageAdvice
    }

    func getCulturalNote(for itemName: String) -> String? {
        let searchResults = searchItems(query: itemName)
        return searchResults.first?.culturalNote
    }

    // MARK: - Helper Methods

    func allRegions() -> [CulturalRegion] {
        CulturalRegion.allCases
    }

    func itemCount(for region: CulturalRegion) -> Int {
        itemsForRegion(region).count
    }
}
