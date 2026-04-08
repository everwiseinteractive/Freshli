import WidgetKit
import AppIntents

// MARK: - Widget Configuration Intent
// Allows users to configure which view the widget shows.

struct PantryWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Pantry Widget" }
    static var description: IntentDescription { "Configure your PantryShare widget." }

    @Parameter(title: "Show Category", default: .all)
    var category: WidgetCategoryFilter
}

enum WidgetCategoryFilter: String, AppEnum {
    case all
    case expiringSoon
    case fridge
    case pantry

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var caseDisplayRepresentations: [WidgetCategoryFilter: DisplayRepresentation] = [
        .all: "All Items",
        .expiringSoon: "Expiring Soon",
        .fridge: "Fridge Only",
        .pantry: "Pantry Only"
    ]
}
