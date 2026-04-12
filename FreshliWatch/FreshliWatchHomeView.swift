import SwiftUI

/// Main watch face — shows a glanceable summary of the user's pantry
/// health and this week's rescue impact. Designed for quick wrist-up
/// moments at the fridge: "What's expiring? How am I doing?"
struct FreshliWatchHomeView: View {
    @AppStorage("watchItemsSaved", store: UserDefaults(suiteName: "group.everwise.interactive.Freshli"))
    private var itemsSaved: Int = 0

    @AppStorage("watchExpiringCount", store: UserDefaults(suiteName: "group.everwise.interactive.Freshli"))
    private var expiringCount: Int = 0

    @AppStorage("watchCO2Avoided", store: UserDefaults(suiteName: "group.everwise.interactive.Freshli"))
    private var co2Avoided: Double = 0

    @AppStorage("watchStreakDays", store: UserDefaults(suiteName: "group.everwise.interactive.Freshli"))
    private var streakDays: Int = 0

    @AppStorage("watchExpiringNames", store: UserDefaults(suiteName: "group.everwise.interactive.Freshli"))
    private var expiringNamesRaw: String = ""

    private var expiringNames: [String] {
        expiringNamesRaw.isEmpty ? [] : expiringNamesRaw.components(separatedBy: "|")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Hero stat — items saved this week
                    heroCard

                    // Expiring soon alert
                    if expiringCount > 0 {
                        expiringCard
                    }

                    // Impact row
                    impactRow

                    // Streak
                    if streakDays > 0 {
                        streakCard
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Freshli")
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)

            Text("\(itemsSaved)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text("items saved")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.77, blue: 0.37),
                         Color(red: 0.08, green: 0.64, blue: 0.27)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Expiring Card

    private var expiringCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                Text("\(expiringCount) expiring soon")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            if !expiringNames.isEmpty {
                ForEach(expiringNames.prefix(3), id: \.self) { name in
                    Text("• \(name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Impact Row

    private var impactRow: some View {
        HStack(spacing: 8) {
            impactTile(
                icon: "cloud.fill",
                value: String(format: "%.1fkg", co2Avoided),
                label: "CO₂",
                color: .teal
            )
            impactTile(
                icon: "dollarsign.circle.fill",
                value: "$\(Int(Double(itemsSaved) * 3.5))",
                label: "Saved",
                color: .orange
            )
        }
    }

    private func impactTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.98, green: 0.75, blue: 0.15),
                                 Color(red: 0.98, green: 0.45, blue: 0.09)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            Text("\(streakDays)-day streak")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            // Mini day dots
            HStack(spacing: 2) {
                ForEach(0..<min(streakDays, 7), id: \.self) { _ in
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    FreshliWatchHomeView()
}
