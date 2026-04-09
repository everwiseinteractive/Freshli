import SwiftUI

// MARK: - Freshli Live Activity Design Constants
// Shared colors, fonts, and styles for all Live Activity views.
// Mirrors PSColors/PSTypography but self-contained for the widget target.

enum FreshliLA {

    // MARK: - Colors (from PSColors, widget-safe)

    static let freshGreen = Color(red: 0.133, green: 0.773, blue: 0.369)   // #22C55E
    static let freshGreenDark = Color(red: 0.082, green: 0.502, blue: 0.243) // #15803D
    static let warningAmber = Color(red: 0.961, green: 0.620, blue: 0.043)  // #F59E0B
    static let expiredRed = Color(red: 0.831, green: 0.094, blue: 0.239)    // #D4183D
    static let accentTeal = Color(red: 0.078, green: 0.722, blue: 0.651)    // #14B8A6
    static let infoBlue = Color(red: 0.231, green: 0.510, blue: 0.965)      // #3B82F6

    static let glassBorder = Color.white.opacity(0.2)
    static let glassHighlight = Color.white.opacity(0.08)
    static let subtleText = Color.white.opacity(0.6)

    // MARK: - Fonts (SF Rounded)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Category Emoji

    static func emoji(for category: String) -> String {
        switch category {
        case "fruits": return "🍎"
        case "vegetables": return "🥬"
        case "dairy": return "🥛"
        case "meat": return "🥩"
        case "seafood": return "🐟"
        case "bakery": return "🍞"
        case "grains": return "🌾"
        case "frozen": return "🧊"
        case "canned": return "🥫"
        case "beverages": return "🥤"
        case "snacks": return "🍿"
        case "condiments": return "🧂"
        default: return "🍽️"
        }
    }

    // MARK: - Expiry Color Interpolation

    /// Interpolates from green (progress=1) to amber (progress=0).
    static func expiryProgressColor(_ progress: Double) -> Color {
        let clamped = max(0, min(1, progress))
        if clamped > 0.5 {
            return freshGreen
        } else if clamped > 0.2 {
            return warningAmber
        } else {
            return expiredRed
        }
    }

    // MARK: - Distance Formatting

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return "\(Int(meters))m"
        }
    }
}

// MARK: - Glass Pill (reusable action button for Live Activities)

struct FreshliLAPill: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Glass Progress Bar

struct FreshliLAProgressBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.1))

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * CGFloat(max(0, min(1, progress))), 4))
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
    }
}
