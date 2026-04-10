import Foundation

// MARK: - Date Extensions

extension Date {
    
    /// Returns a date N days from now
    static func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }
    
    /// Returns a date N days ago
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
    
    /// Expiry display text for UI
    var expiryDisplayText: String {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: self)
        let days = calendar.dateComponents([.day], from: now, to: expiry).day ?? 0
        
        if days < 0 {
            let absDays = abs(days)
            if absDays == 1 {
                return String(localized: "Expired yesterday")
            } else {
                return String(localized: "Expired \(absDays) days ago")
            }
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
    
    /// Short expiry display (for compact views)
    var shortExpiryText: String {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let expiry = calendar.startOfDay(for: self)
        let days = calendar.dateComponents([.day], from: now, to: expiry).day ?? 0
        
        if days < 0 {
            return String(localized: "Expired")
        } else if days == 0 {
            return String(localized: "Today")
        } else if days == 1 {
            return String(localized: "Tomorrow")
        } else {
            return String(localized: "\(days)d")
        }
    }
    
    /// Relative time description
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is in the past
    var isPast: Bool {
        self < Date()
    }
    
    /// Days until this date
    var daysUntil: Int {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: now, to: target).day ?? 0
    }
}
