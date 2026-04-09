import SwiftUI

// MARK: - Freshness Ring View
// A reusable, animated circular progress ring for tracking weekly freshness score.
// Similar to Apple Activity Rings with gradient fill.

struct FreshnessRingView<Content: View>: View {
    let progress: Double // 0.0 to 1.0
    let ringThickness: CGFloat
    let size: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        progress: Double,
        ringThickness: CGFloat = 8,
        size: CGFloat = 100,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.progress = progress
        self.ringThickness = ringThickness
        self.size = size
        self.content = content
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(PSColors.primaryGreen.opacity(0.15), lineWidth: ringThickness)

            // Gradient fill ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            PSColors.accentTeal,
                            PSColors.primaryGreen
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringThickness, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(PSMotion.springDefault, value: animatedProgress)

            // Inner content
            content()
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = min(progress, 1.0)
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = min(newValue, 1.0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(animatedProgress * 100))%")
    }
}

// MARK: - Freshness Ring with Label

struct FreshnessRingLabeled: View {
    let progress: Double
    let percentage: String
    let label: String
    let streakDays: Int?
    let size: CGFloat

    init(
        progress: Double,
        percentage: String,
        label: String,
        streakDays: Int? = nil,
        size: CGFloat = 120
    ) {
        self.progress = progress
        self.percentage = percentage
        self.label = label
        self.streakDays = streakDays
        self.size = size
    }

    var body: some View {
        VStack(spacing: PSSpacing.md) {
            FreshnessRingView(progress: progress, ringThickness: 6, size: size) {
                VStack(spacing: 2) {
                    Text(percentage)
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.textPrimary)

                    if let streakDays = streakDays {
                        Text("\(streakDays)d 🔥")
                            .font(.system(size: size * 0.12, weight: .semibold))
                            .foregroundStyle(PSColors.warningAmber)
                    }
                }
            }

            Text(label)
                .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                .foregroundStyle(PSColors.textPrimary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue("\(percentage), \(streakDays.map { String($0) } ?? "")d streak")
    }
}

// MARK: - Compact Freshness Ring (for Lock Screen)

struct CompactFreshnessRing: View {
    let progress: Double
    let size: CGFloat

    init(progress: Double, size: CGFloat = 48) {
        self.progress = progress
        self.size = size
    }

    var body: some View {
        FreshnessRingView(progress: progress, ringThickness: 4, size: size) {
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.35))
                .foregroundStyle(ringColor)
        }
    }

    private var ringColor: Color {
        switch progress {
        case 0.8...1.0: return PSColors.primaryGreen
        case 0.5..<0.8: return PSColors.warningAmber
        default: return PSColors.expiredRed
        }
    }
}

// MARK: - Previews

#Preview("Freshness Ring - Full") {
    VStack(spacing: 40) {
        FreshnessRingLabeled(progress: 0.85, percentage: "85%", label: "Freshness Score", streakDays: 7, size: 120)

        FreshnessRingLabeled(progress: 0.65, percentage: "65%", label: "Freshness Score", streakDays: 3, size: 120)

        FreshnessRingLabeled(progress: 0.35, percentage: "35%", label: "Freshness Score", streakDays: 0, size: 120)
    }
    .padding()
}

#Preview("Compact Ring") {
    VStack(spacing: 40) {
        CompactFreshnessRing(progress: 0.9)
        CompactFreshnessRing(progress: 0.65)
        CompactFreshnessRing(progress: 0.3)
    }
    .padding()
}
