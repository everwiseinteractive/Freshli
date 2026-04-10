import Foundation
import Observation

// MARK: - Localization Enums

enum MeasurementSystem: String, Codable, CaseIterable {
    case metric
    case imperial

    var displayName: String {
        switch self {
        case .metric: return String(localized: "Metric (kg, L, °C)")
        case .imperial: return String(localized: "Imperial (lb, fl oz, °F)")
        }
    }
}

enum DateFormatStyle: String, Codable, CaseIterable {
    case dayMonthYear
    case monthDayYear
    case yearMonthDay

    var displayName: String {
        switch self {
        case .dayMonthYear: return String(localized: "DD/MM/YYYY")
        case .monthDayYear: return String(localized: "MM/DD/YYYY")
        case .yearMonthDay: return String(localized: "YYYY/MM/DD")
        }
    }

    func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        switch self {
        case .dayMonthYear:
            formatter.dateFormat = "dd/MM/yyyy"
        case .monthDayYear:
            formatter.dateFormat = "MM/dd/yyyy"
        case .yearMonthDay:
            formatter.dateFormat = "yyyy/MM/dd"
        }

        return formatter.string(from: date)
    }
}

enum TemperatureUnit: String, Codable, CaseIterable {
    case celsius
    case fahrenheit

    var displayName: String {
        switch self {
        case .celsius: return String(localized: "Celsius (°C)")
        case .fahrenheit: return String(localized: "Fahrenheit (°F)")
        }
    }

    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
}

// MARK: - Localization Service

@Observable @MainActor
final class LocalizationService {
    static let shared = LocalizationService()

    private let userDefaults = UserDefaults.standard
    private let measurementSystemKey = "localization_measurementSystem"
    private let dateFormatKey = "localization_dateFormat"
    private let temperatureUnitKey = "localization_temperatureUnit"
    private let localeOverrideKey = "localization_localeOverride"

    // MARK: - Properties

    var currentMeasurementSystem: MeasurementSystem {
        didSet {
            userDefaults.set(currentMeasurementSystem.rawValue, forKey: measurementSystemKey)
        }
    }

    var currentDateFormat: DateFormatStyle {
        didSet {
            userDefaults.set(currentDateFormat.rawValue, forKey: dateFormatKey)
        }
    }

    var currentTemperatureUnit: TemperatureUnit {
        didSet {
            userDefaults.set(currentTemperatureUnit.rawValue, forKey: temperatureUnitKey)
        }
    }

    var currentLocale: Locale {
        didSet {
            userDefaults.set(currentLocale.identifier, forKey: localeOverrideKey)
        }
    }

    var availableCurrencyCodes: [String] = {
        Locale.isoCurrencyCodes
    }()

    var currentCurrencyCode: String {
        currentLocale.currencyCode ?? "USD"
    }

    // MARK: - Initialization

    init() {
        // Load measurement system
        if let saved = userDefaults.string(forKey: measurementSystemKey),
           let system = MeasurementSystem(rawValue: saved) {
            currentMeasurementSystem = system
        } else {
            currentMeasurementSystem = Self.defaultMeasurementSystem()
        }

        // Load date format
        if let saved = userDefaults.string(forKey: dateFormatKey),
           let format = DateFormatStyle(rawValue: saved) {
            currentDateFormat = format
        } else {
            currentDateFormat = Self.defaultDateFormat()
        }

        // Load temperature unit
        if let saved = userDefaults.string(forKey: temperatureUnitKey),
           let unit = TemperatureUnit(rawValue: saved) {
            currentTemperatureUnit = unit
        } else {
            currentTemperatureUnit = Self.defaultTemperatureUnit()
        }

        // Load locale
        if let savedIdentifier = userDefaults.string(forKey: localeOverrideKey) {
            currentLocale = Locale(identifier: savedIdentifier)
        } else {
            currentLocale = Locale.current
        }
    }

    // MARK: - Auto-Detection Helpers

    private static func defaultMeasurementSystem() -> MeasurementSystem {
        let locale = Locale.current
        // US, UK, Liberia, Myanmar use imperial
        let imperialCountries = ["US", "GB", "LR", "MM"]
        if let countryCode = locale.region?.identifier,
           imperialCountries.contains(countryCode) {
            return .imperial
        }
        return .metric
    }

    private static func defaultDateFormat() -> DateFormatStyle {
        let locale = Locale.current
        // US uses month/day/year
        if let countryCode = locale.region?.identifier, countryCode == "US" {
            return .monthDayYear
        }
        // Most of world uses day/month/year
        return .dayMonthYear
    }

    private static func defaultTemperatureUnit() -> TemperatureUnit {
        let locale = Locale.current
        // US, Cayman Islands, Palau, Bahamas, Belize use Fahrenheit
        let fahrenheitCountries = ["US", "KY", "PW", "BS", "BZ"]
        if let countryCode = locale.region?.identifier,
           fahrenheitCountries.contains(countryCode) {
            return .fahrenheit
        }
        return .celsius
    }

    // MARK: - Formatting Methods

    /// Format weight in grams to user's preferred measurement system
    func formatWeight(_ grams: Double) -> String {
        switch currentMeasurementSystem {
        case .metric:
            if grams >= 1000 {
                let kilograms = grams / 1000
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                let formatted = formatter.string(from: NSNumber(value: kilograms)) ?? String(format: "%.2f", kilograms)
                return String(localized: "\(formatted) kg")
            } else {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
                let formatted = formatter.string(from: NSNumber(value: grams)) ?? String(format: "%.0f", grams)
                return String(localized: "\(formatted) g")
            }

        case .imperial:
            // 1 lb = 453.592 grams
            let pounds = grams / 453.592
            if pounds >= 1 {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                let formatted = formatter.string(from: NSNumber(value: pounds)) ?? String(format: "%.2f", pounds)
                return String(localized: "\(formatted) lb")
            } else {
                // Convert to ounces: 1 oz = 28.3495 grams
                let ounces = grams / 28.3495
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 1
                let formatted = formatter.string(from: NSNumber(value: ounces)) ?? String(format: "%.1f", ounces)
                return String(localized: "\(formatted) oz")
            }
        }
    }

    /// Format volume in milliliters to user's preferred measurement system
    func formatVolume(_ milliliters: Double) -> String {
        switch currentMeasurementSystem {
        case .metric:
            if milliliters >= 1000 {
                let liters = milliliters / 1000
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                let formatted = formatter.string(from: NSNumber(value: liters)) ?? String(format: "%.2f", liters)
                return String(localized: "\(formatted) L")
            } else {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 0
                let formatted = formatter.string(from: NSNumber(value: milliliters)) ?? String(format: "%.0f", milliliters)
                return String(localized: "\(formatted) mL")
            }

        case .imperial:
            // 1 fl oz = 29.5735 mL
            let fluidOunces = milliliters / 29.5735
            if fluidOunces >= 16 {
                // Convert to cups: 1 cup = 8 fl oz
                let cups = fluidOunces / 8
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 2
                let formatted = formatter.string(from: NSNumber(value: cups)) ?? String(format: "%.2f", cups)
                return String(localized: "\(formatted) cup")
            } else {
                let formatter = NumberFormatter()
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 1
                let formatted = formatter.string(from: NSNumber(value: fluidOunces)) ?? String(format: "%.1f", fluidOunces)
                return String(localized: "\(formatted) fl oz")
            }
        }
    }

    /// Format temperature from Celsius to user's preferred unit
    func formatTemperature(_ celsius: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1

        switch currentTemperatureUnit {
        case .celsius:
            let formatted = formatter.string(from: NSNumber(value: celsius)) ?? String(format: "%.1f", celsius)
            return String(localized: "\(formatted)°C")

        case .fahrenheit:
            let fahrenheit = (celsius * 9 / 5) + 32
            let formatted = formatter.string(from: NSNumber(value: fahrenheit)) ?? String(format: "%.1f", fahrenheit)
            return String(localized: "\(formatted)°F")
        }
    }

    /// Format date using user's preferred format style
    func formatDate(_ date: Date) -> String {
        currentDateFormat.format(date: date)
    }

    /// Format date as relative (e.g., "2 days ago", "in 3 days")
    func formatRelativeDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: now)
        let daysDifference = components.day ?? 0

        if daysDifference == 0 {
            return String(localized: "Today")
        } else if daysDifference == 1 {
            return String(localized: "Yesterday")
        } else if daysDifference == -1 {
            return String(localized: "Tomorrow")
        } else if daysDifference > 0 {
            return String(localized: "\(daysDifference) days ago")
        } else {
            let futureDays = abs(daysDifference)
            return String(localized: "in \(futureDays) days")
        }
    }

    /// Format currency amount with localized formatting
    func formatCurrency(_ amount: Double, currencyCode: String = "") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = currentLocale

        if !currencyCode.isEmpty {
            formatter.currencyCode = currencyCode
        }

        let formatted = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return formatted
    }

    // MARK: - Locale Management

    /// Reset all localization settings to auto-detected defaults
    func resetToDefaults() {
        currentMeasurementSystem = Self.defaultMeasurementSystem()
        currentDateFormat = Self.defaultDateFormat()
        currentTemperatureUnit = Self.defaultTemperatureUnit()
        currentLocale = Locale.current

        userDefaults.removeObject(forKey: measurementSystemKey)
        userDefaults.removeObject(forKey: dateFormatKey)
        userDefaults.removeObject(forKey: temperatureUnitKey)
        userDefaults.removeObject(forKey: localeOverrideKey)
    }

    /// Get example date formatted in given style
    func getExampleDate(for style: DateFormatStyle) -> String {
        let now = Date()
        return style.format(date: now)
    }

    /// Get example measurements for preview
    func getExampleWeight() -> (metric: String, imperial: String) {
        let grams = 500.0
        let metricFormatter = { self.currentMeasurementSystem = .metric; return self.formatWeight(grams) }()
        let imperialFormatter = { self.currentMeasurementSystem = .imperial; return self.formatWeight(grams) }()
        return (metricFormatter, imperialFormatter)
    }

    func getExampleTemperature() -> (celsius: String, fahrenheit: String) {
        let temp = 20.0 // 20°C
        let celsiusFormatter = { self.currentTemperatureUnit = .celsius; return self.formatTemperature(temp) }()
        let fahrenheitFormatter = { self.currentTemperatureUnit = .fahrenheit; return self.formatTemperature(temp) }()
        return (celsiusFormatter, fahrenheitFormatter)
    }
}
