import SwiftUI

// Figma: MilestoneCelebration — Hero-tier celebration for achievements/milestones
// Layout: radial pulses → badge with unlock pulse → title → stat → CTA
// Motion: badge scales from 0→1 with ring pulse, title reveals, stat count-up

struct MilestoneCelebrationView: View {
    let type: CelebrationType
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showBadge = false
    @State private var showStat = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CelebrationContainer(type: type, onDismiss: onDismiss) {
            VStack(spacing: 0) {
                Spacer()

                // Figma: Achievement badge with unlock pulse animation
                ZStack {
                    CelebrationBadge(
                        icon: badgeIcon,
                        color: type.iconBackgroundColor,
                        animate: showBadge
                    )

                    // Confetti burst around badge
                    CelebrationParticleLayer(
                        count: type.confettiCount,
                        trigger: showContent,
                        accentColor: type.pulseColor
                    )
                }
                .padding(.bottom, 40)

                // Figma: "Achievement Unlocked" label
                if showContent {
                    Text(String(localized: "ACHIEVEMENT UNLOCKED"))
                        .font(.system(size: 12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .offset(y: 10)))
                }

                // Figma: Title
                CelebrationHeadline(text: type.title, animate: showContent)
                    .padding(.bottom, 16)

                // Figma: Subtitle
                CelebrationSubtitle(
                    text: type.subtitle,
                    color: descriptionColor,
                    animate: showContent
                )

                // Figma: Stat display for impact milestones
                if let statDisplay = milestoneStatDisplay, showStat {
                    statDisplay
                        .padding(.top, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                Spacer()

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
                showBadge = true
                showStat = true
            } else {
                withAnimation(PSMotion.springBouncy.delay(0.15)) {
                    showContent = true
                }
                withAnimation(PSMotion.springBouncy.delay(0.3)) {
                    showBadge = true
                }
                withAnimation(PSMotion.springDefault.delay(0.7)) {
                    showStat = true
                }
            }
            // Strong haptic for milestone
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
    }

    private var badgeIcon: String {
        switch type {
        case .achievementUnlock(_, let icon): return icon
        case .impactMilestone: return "star.fill"
        case .communityImpact: return "person.3.fill"
        default: return "trophy.fill"
        }
    }

    private var descriptionColor: Color {
        switch type {
        case .impactMilestone: return Color(hex: 0xA7F3D0) // emerald-200
        case .achievementUnlock: return Color(hex: 0xFDE68A) // amber-200
        case .communityImpact: return Color(hex: 0x99F6E4) // teal-200
        default: return .white.opacity(0.7)
        }
    }

    @ViewBuilder
    private var milestoneStatDisplay: (some View)? {
        switch type {
        case .impactMilestone(_, let stat):
            VStack(spacing: 8) {
                Text(stat)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(String(localized: "and counting"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        case .communityImpact(let items, let neighbors):
            HStack(spacing: 12) {
                CelebrationStatBlock(
                    icon: "shippingbox.fill",
                    value: "\(items)",
                    label: "Items",
                    animate: true,
                    delay: 0.1
                )
                CelebrationStatBlock(
                    icon: "person.2.fill",
                    value: "\(neighbors)",
                    label: "Neighbors",
                    animate: true,
                    delay: 0.2
                )
            }
        default:
            EmptyView()
        }
    }
}
