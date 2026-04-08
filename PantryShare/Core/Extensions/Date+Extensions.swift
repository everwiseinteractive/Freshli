import Foundation

extension Date {
    var daysUntilExpiry: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: now, to: target).day ?? 0
    }

    var expiryDisplayText: String {
        let days = daysUntilExpiry
        if days < 0 {
            return String(localized: "Expired \(abs(days))d ago")
        } else if days == 0 {
            return String(localized: "Expires today")
        } else if days == 1 {
            return String(localized: "Expires tomorrow")
        } else if days <= 7 {
            return String(localized: "Expires in \(days) days")
        } else {
            // Use locale-aware date formatting
            return self.formatted(date: .abbreviated, time: .omitted)
        }
    }

    var shortDisplay: String {
        // Use locale-aware formatting instead of hardcoded format
        return self.formatted(date: .abbreviated, time: .omitted)
    }

    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}

extension Double {
    /// Format weight in user's preferred system (metric or imperial)
    var localizedWeight: String {
        let measurement = Measurement(value: self, unit: UnitMass.kilograms)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.locale = Locale.current
        return formatter.string(from: measurement)
    }

    /// Format currency in user's locale
    var localizedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "$\(Int(self))"
    }
}
