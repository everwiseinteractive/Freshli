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
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: self)
        }
    }

    var shortDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
}
