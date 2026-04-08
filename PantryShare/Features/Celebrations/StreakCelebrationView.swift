import SwiftUI

// Figma: StreakCelebration — Full-screen amber theme with animated streak counter
// Layout: radial pulses → flame icon + count-up number → streak bar → description → CTA
// Motion: springBouncy entrance, count-up from 0→N, fire particle burst

struct StreakCelebrationView: View {
    let streakCount: Int
    let onDismiss: () -> Void

    private let type: CelebrationType

    init(streakCount: Int, onDismiss: @escaping () -> Void) {
        self.streakCount = streakCount
        self.onDismiss = onDismiss
        self.type = .expiryRescueStreak(count: streakCount)
    }

    @State private var showContent = false
    @State private var showStreak = false
    @State private var showStats = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CelebrationContainer(type: type, onDismiss: onDismiss) {
            VStack(spacing: 0) {
                Spacer()

                // Figma: Streak fire icon with confetti burst
                ZStack {
                    CelebrationHeroGraphic(type: type, animate: showContent)

                    // Figma: Streak count overlay — large number below icon
                    if showStreak {
                        CelebrationCountUpText.integer(
                            streakCount,
                            font: .system(size: 20, weight: .black, design: .rounded),
                            color: .white,
                            delay: 0.3
                        )
                        .offset(y: 80)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 32)

                // Figma: Title
                CelebrationHeadline(text: type.title, animate: showContent)
                    .padding(.bottom, 12)

                // Figma: Streak progress bar
                if showStreak {
                    streakProgressBar
                        .padding(.horizontal, 48)
                        .padding(.bottom, PSLayout.cardPadding)
                        .transition(.opacity.combined(with: .offset(y: 10)))
                }

                // Figma: Subtitle
                CelebrationSubtitle(
                    text: type.subtitle,
                    color: Color(hex: 0xFEF3C7), // amber-100
                    animate: showContent
                )

                Spacer()

                // Figma: Stats row for 7+ day streaks
                if streakCount >= 7 && showStats {
                    statsRow
                        .padding(.bottom, 32)
                        .transition(.opacity.combined(with: .offset(y: 20)))
                }

                CelebrationCTA(
                    label: type.ctaLabel,
                    textColor: type.ctaTextColor,
                    shadowColor: type.ctaShadowColor,
                    animate: showContent,
                    action: onDismiss
                )
                .padding(.bottom, 40)
            }
            .adaptiveHPadding()
        }
        .onAppear {
            if reduceMotion {
                showContent = true
                showStreak = true
                showStats = true
            } else {
                withAnimation(PSMotion.springBouncy.delay(0.15)) {
                    showContent = true
                }
                withAnimation(PSMotion.springDefault.delay(0.5)) {
                    showStreak = true
                }
                withAnimation(PSMotion.springDefault.delay(0.8)) {
                    showStats = true
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // Figma: Streak dots — filled for completed days, outline for remaining
    private var streakProgressBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<min(streakCount, 7), id: \.self) { i in
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .scaleEffect(showStreak ? 1 : 0)
                    .animation(
                        PSMotion.springBouncy.delay(0.6 + Double(i) * 0.06),
                        value: showStreak
                    )
            }

            if streakCount < 7 {
                ForEach(0..<(7 - streakCount), id: \.self) { _ in
                    Circle()
                        .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    // Figma: Stats row for hero-tier streak celebrations
    private var statsRow: some View {
        HStack(spacing: 12) {
            CelebrationStatBlock(
                icon: "flame.fill",
                value: "\(streakCount)",
                label: "Day Streak",
                iconColor: Color(hex: 0xFBBF24),
                animate: showStats,
                delay: 0.1
            )

            CelebrationStatBlock(
                icon: "leaf.fill",
                value: "\(streakCount * 2)",
                label: "Items Saved",
                iconColor: Color(hex: 0x4ADE80),
                animate: showStats,
                delay: 0.2
            )
        }
    }
}
