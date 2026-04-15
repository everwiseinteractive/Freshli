import SwiftUI

// Figma: WeeklyRecap — Hero-tier celebration, dark slate theme
// Layout: header → animated stat cards (2x2 grid) → impact message → CTA
// Motion: staggered card entrance, count-up numbers, gentle particle accent

struct WeeklyRecapView: View {
    let saved: Int
    let shared: Int
    let co2: Double
    let money: Double
    let onDismiss: () -> Void

    private let type: CelebrationType

    init(saved: Int, shared: Int, co2: Double, money: Double, onDismiss: @escaping () -> Void) {
        self.saved = saved
        self.shared = shared
        self.co2 = co2
        self.money = money
        self.onDismiss = onDismiss
        self.type = .weeklyRecap(saved: saved, shared: shared, co2: co2, money: money)
    }

    @State private var showHeader = false
    @State private var showCards = false
    @State private var showMessage = false
    @State private var showCTA = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CelebrationContainer(type: type, onDismiss: onDismiss) {
            VStack(spacing: 0) {
                // Figma: Top section with icon and title
                headerSection
                    .padding(.top, 80)
                    .padding(.bottom, 32)

                // Figma: 2x2 stat grid with count-up animations
                statsGrid
                    .adaptiveHPadding()
                    .padding(.bottom, 32)

                // Figma: Impact message
                if showMessage {
                    impactMessage
                        .padding(.horizontal, PSLayout.formHorizontalPadding)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .offset(y: 15)))
                }

                Spacer()

                // Figma: CTA
                CelebrationCTA(
                    label: type.ctaLabel,
                    textColor: Color(hex: 0x1E293B), // slate-800
                    shadowColor: Color(hex: 0x0F172A).opacity(0.2),
                    animate: showCTA,
                    action: onDismiss
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            triggerAnimations()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Figma: Chart icon in container
            ZStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                // Subtle particle accent
                CelebrationParticleLayer(
                    count: 4,
                    trigger: showHeader,
                    accentColor: Color(hex: 0x4ADE80)
                )
            }
            .scaleEffect(showHeader ? 1 : 0.6)
            .opacity(showHeader ? 1 : 0)

            Text(String(localized: "Your Week in Review"))
                .font(.system(size: 30, weight: .black))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 15)

            Text(String(localized: "Here's the impact you made"))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: 0x94A3B8)) // slate-400
                .opacity(showHeader ? 1 : 0)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Food Saved
                recapStatCard(
                    icon: "leaf.fill",
                    value: "\(saved)",
                    label: String(localized: "Food Saved"),
                    iconColor: Color(hex: 0x4ADE80),
                    index: 0
                )

                // Items Shared
                recapStatCard(
                    icon: "hand.raised.fill",
                    value: "\(shared)",
                    label: String(localized: "Items Shared"),
                    iconColor: Color(hex: 0x60A5FA),
                    index: 1
                )
            }

            HStack(spacing: 12) {
                // CO2 Avoided
                recapStatCard(
                    icon: "cloud.fill",
                    value: String(format: "%.1fkg", co2),
                    label: String(localized: "CO\u{2082} Avoided"),
                    iconColor: Color(hex: 0x2DD4BF),
                    index: 2
                )

                // Money Saved
                recapStatCard(
                    icon: "dollarsign.circle.fill",
                    value: String(format: "$%.0f", money),
                    label: String(localized: "Money Saved"),
                    iconColor: Color(hex: 0xFBBF24),
                    index: 3
                )
            }
        }
    }

    private func recapStatCard(icon: String, value: String, label: String, iconColor: Color, index: Int) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSLayout.cardPadding)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(showCards ? 1 : 0.8)
        .opacity(showCards ? 1 : 0)
        .animation(
            reduceMotion ? .none : PSMotion.springBouncy.delay(0.3 + Double(index) * 0.08),
            value: showCards
        )
    }

    // MARK: - Impact Message

    private var impactMessage: some View {
        VStack(spacing: 8) {
            Text(String(localized: "You're making a real difference"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text(String(localized: "Every item saved reduces waste and helps your community"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: 0x94A3B8))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    // MARK: - Animation Sequence

    private func triggerAnimations() {
        if reduceMotion {
            showHeader = true
            showCards = true
            showMessage = true
            showCTA = true
        } else {
            withAnimation(PSMotion.springBouncy.delay(0.1)) {
                showHeader = true
            }
            withAnimation(PSMotion.springDefault.delay(0.3)) {
                showCards = true
            }
            withAnimation(PSMotion.springDefault.delay(0.8)) {
                showMessage = true
            }
            withAnimation(PSMotion.springDefault.delay(1.0)) {
                showCTA = true
            }
        }
    }
}
