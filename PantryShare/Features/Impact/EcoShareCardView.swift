import SwiftUI
import SwiftData

/// Instagram Story-ready shareable cards for sustainability impact
/// 9:16 aspect ratio (1080x1920 logical points)
struct EcoShareCard: View {
    enum CardStyle {
        case weeklyRecap
        case milestone
        case streak
    }

    let stats: ImpactService.ImpactStats
    let style: CardStyle
    let userName: String?
    let showExactNumbers: Bool

    var body: some View {
        ZStack {
            // Background gradient with organic shapes
            backgroundGradient

            // Subtle grain texture overlay
            textureOverlay

            // Content based on style
            VStack {
                switch style {
                case .weeklyRecap:
                    weeklyRecapContent
                case .milestone:
                    milestoneContent
                case .streak:
                    streakContent
                }
            }
            .padding(32)
        }
        .frame(width: 1080 / 3, height: 1920 / 3) // 9:16 aspect ratio at 1/3 scale for preview
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 8)
    }

    // MARK: - Background & Texture

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                PSColors.primaryGreen,
                PSColors.accentTeal
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var textureOverlay: some View {
        Canvas { context, size in
            for y in stride(from: 0, through: size.height, by: 4) {
                for x in stride(from: 0, through: size.width, by: 4) {
                    let randomOpacity = Double.random(in: 0.01...0.04)
                    var rect = CGRect(x: x, y: y, width: 2, height: 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(.white.opacity(randomOpacity))
                    )
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Weekly Recap Card

    private var weeklyRecapContent: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("My Week of Impact")
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .foregroundColor(PSColors.textOnPrimary)
            }

            Spacer()

            // Hero stat: CO2 avoided
            VStack(spacing: 8) {
                Text(co2ForDisplay)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(PSColors.textOnPrimary)
                    .lineLimit(1)

                Text("kg CO₂ Avoided")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.9))
            }

            Spacer()

            // Supporting stats row
            HStack(alignment: .top, spacing: 16) {
                StatPill(
                    value: "\(stats.itemsSaved)",
                    label: "Items\nSaved"
                )

                StatPill(
                    value: "\(stats.itemsShared + stats.itemsDonated)",
                    label: "Meals\nShared"
                )

                StatPill(
                    value: moneySavedForDisplay,
                    label: "Money\nSaved"
                )
            }

            Spacer()

            // Context line
            Text("Equivalent to \(equivalentMiles) miles not driven")
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.85))
                .multilineTextAlignment(.center)

            Spacer()

            // Footer: Branding + CTA
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("PantryShare")
                        .font(.system(size: 14, weight: .bold, design: .default))
                }
                .foregroundColor(PSColors.textOnPrimary)

                Text("Join me in reducing food waste")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            if let userName {
                Text("Shared by \(userName)")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.7))
            }

            Spacer()
        }
    }

    // MARK: - Milestone Card

    private var milestoneContent: some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer()

            // Achievement badge
            ZStack {
                Circle()
                    .fill(PSColors.textOnPrimary.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "star.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(PSColors.textOnPrimary)
            }

            // Celebratory particles (static circles)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(PSColors.textOnPrimary.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            // Milestone text
            VStack(spacing: 12) {
                Text("I just hit")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.9))

                Text(milestoneName)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(PSColors.textOnPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            // Stat breakdown
            VStack(spacing: 12) {
                MilestoneStatRow(
                    label: "Items Saved",
                    value: "\(stats.itemsSaved)"
                )
                MilestoneStatRow(
                    label: "CO₂ Avoided",
                    value: co2ForDisplay
                )
                MilestoneStatRow(
                    label: "Money Saved",
                    value: moneySavedForDisplay
                )
            }
            .padding(16)
            .background(PSColors.textOnPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer()

            // Footer
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("PantryShare")
                        .font(.system(size: 12, weight: .bold, design: .default))
                }
                .foregroundColor(PSColors.textOnPrimary)

                if let userName {
                    Text("Shared by \(userName)")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(PSColors.textOnPrimary.opacity(0.7))
                }
            }

            Spacer()
        }
    }

    // MARK: - Streak Card

    private var streakContent: some View {
        VStack(alignment: .center, spacing: 20) {
            Spacer()

            // Large streak number with flame
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(PSColors.textOnPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("7")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(PSColors.textOnPrimary)

                        Text("Day Streak")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(PSColors.textOnPrimary.opacity(0.9))
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Calendar dot grid (last 30 days representation)
            VStack(spacing: 8) {
                Text("Keep it going!")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.8))

                // 5x6 grid of dots
                VStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<6, id: \.self) { col in
                                Circle()
                                    .fill(
                                        (row * 6 + col) < 28
                                            ? PSColors.textOnPrimary.opacity(0.85)
                                            : PSColors.textOnPrimary.opacity(0.2)
                                    )
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .padding(16)
                .background(PSColors.textOnPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()

            // Motivational tagline
            VStack(spacing: 8) {
                Text("Every day counts")
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(PSColors.textOnPrimary)

                Text("Keep reducing waste, one day at a time")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(PSColors.textOnPrimary.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Footer
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("PantryShare")
                        .font(.system(size: 12, weight: .bold, design: .default))
                }
                .foregroundColor(PSColors.textOnPrimary)

                if let userName {
                    Text("Shared by \(userName)")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(PSColors.textOnPrimary.opacity(0.7))
                }
            }

            Spacer()
        }
    }

    // MARK: - Helpers

    private var co2ForDisplay: String {
        if showExactNumbers {
            return stats.co2Display
        }
        let rounded = Int(stats.co2Avoided / 5) * 5
        return "~\(rounded)kg"
    }

    private var moneySavedForDisplay: String {
        if showExactNumbers {
            return stats.moneySavedDisplay
        }
        let rounded = Int(stats.moneySaved / 5) * 5
        return "~$\(rounded)"
    }

    private var equivalentMiles: String {
        // 1kg CO2 ≈ 2.4 miles driven (EPA avg)
        let miles = Int(stats.co2Avoided * 2.4)
        return "\(miles)"
    }

    private var milestoneName: String {
        // Simple milestone names based on stats
        if stats.itemsSaved >= 50 {
            return "Waste Warrior"
        } else if stats.itemsSaved >= 25 {
            return "Sustainability Champion"
        } else if stats.co2Avoided >= 100 {
            return "Climate Champion"
        } else {
            return "Milestone Achieved"
        }
    }
}

// MARK: - Subcomponents

private struct StatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(PSColors.textOnPrimary)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(PSColors.textOnPrimary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MilestoneStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(PSColors.textOnPrimary.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(PSColors.textOnPrimary)
        }
    }
}

// MARK: - Preview

#Preview("Weekly Recap") {
    let stats = ImpactService.ImpactStats(
        itemsSaved: 42,
        itemsShared: 8,
        itemsDonated: 5,
        mealsCreated: 12
    )

    EcoShareCard(
        stats: stats,
        style: .weeklyRecap,
        userName: "Sarah",
        showExactNumbers: true
    )
    .padding()
}

#Preview("Milestone") {
    let stats = ImpactService.ImpactStats(
        itemsSaved: 50,
        itemsShared: 12,
        itemsDonated: 10,
        mealsCreated: 15
    )

    EcoShareCard(
        stats: stats,
        style: .milestone,
        userName: "Marcus",
        showExactNumbers: false
    )
    .padding()
}

#Preview("Streak") {
    let stats = ImpactService.ImpactStats(
        itemsSaved: 28,
        itemsShared: 4,
        itemsDonated: 3,
        mealsCreated: 7
    )

    EcoShareCard(
        stats: stats,
        style: .streak,
        userName: nil,
        showExactNumbers: true
    )
    .padding()
}
