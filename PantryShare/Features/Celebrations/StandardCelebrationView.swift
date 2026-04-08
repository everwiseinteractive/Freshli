import SwiftUI

// Figma: StandardCelebration — Full-screen celebration matching SuccessCelebration.tsx
// Used for: First Item Added, First Food Saved, Recipe Match, Share, Donate
// Layout: radial pulses → hero graphic → title → description → CTA
// Motion: springBouncy entrance, staggered reveals, confetti burst

struct StandardCelebrationView: View {
    let type: CelebrationType
    let onDismiss: () -> Void

    @State private var showContent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CelebrationContainer(type: type, onDismiss: onDismiss) {
            VStack(spacing: 0) {
                Spacer()

                // Figma: Hero graphic with confetti
                CelebrationHeroGraphic(type: type, animate: showContent)
                    .padding(.bottom, 40)

                // Figma: text-4xl font-black text-white tracking-tight
                CelebrationHeadline(text: type.title, animate: showContent)
                    .padding(.bottom, 16)

                // Figma: text-green-100 text-lg font-medium
                CelebrationSubtitle(
                    text: type.subtitle,
                    color: descriptionColor,
                    animate: showContent
                )

                Spacer()

                // Figma: CTA — only for medium/hero intensity
                if type.intensity != .small {
                    CelebrationCTA(
                        label: type.ctaLabel,
                        textColor: type.ctaTextColor,
                        shadowColor: type.ctaShadowColor,
                        animate: showContent,
                        action: onDismiss
                    )
                    .padding(.bottom, 40)
                }
            }
            .adaptiveHPadding()
        }
        .onAppear {
            if reduceMotion {
                showContent = true
            } else {
                withAnimation(PSMotion.springBouncy.delay(0.15)) {
                    showContent = true
                }
            }
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        .onDisappear { showContent = false }
    }

    private var descriptionColor: Color {
        switch type {
        case .firstItemAdded, .firstFoodSaved:
            return Color(hex: 0xDCFCE7) // green-100
        case .recipeMatchSuccess:
            return Color(hex: 0xEDE9FE) // violet-100
        case .shareCompleted:
            return Color(hex: 0xDBEAFE) // blue-100
        case .donationCompleted:
            return Color(hex: 0xCCFBF1) // teal-100
        default:
            return .white.opacity(0.8)
        }
    }
}

// MARK: - Small Toast Celebration
// Figma: Quick overlay for recipe match — no CTA, auto-dismiss

struct ToastCelebrationView: View {
    let type: CelebrationType
    let onDismiss: () -> Void

    @State private var showContent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 16) {
                // Figma: Smaller icon container — 56x56
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(type.iconBackgroundColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: type.backgroundColor.opacity(0.3), radius: 12, y: 4)

                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(type.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .background(type.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .shadow(color: type.backgroundColor.opacity(0.3), radius: 24, y: 12)
            .padding(.horizontal, 16)
            .padding(.bottom, PSLayout.tabBarContentPadding + PSSpacing.xl) // Above tab bar
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 60)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            if reduceMotion {
                showContent = true
            } else {
                withAnimation(PSMotion.springBouncy) {
                    showContent = true
                }
            }
            // Haptic
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .onTapGesture { onDismiss() }
    }
}
