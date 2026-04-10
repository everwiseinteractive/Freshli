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
                Spacer(minLength: PSLayout.scaled(20))

                // Figma: Hero graphic with confetti - adaptive sizing
                CelebrationHeroGraphic(type: type, animate: showContent)
                    .padding(.bottom, PSLayout.scaled(40))
                    .frame(maxHeight: PSLayout.scaled(200))

                // Figma: text-4xl font-black text-white tracking-tight - adaptive
                CelebrationHeadline(text: type.title, animate: showContent)
                    .padding(.bottom, PSLayout.scaled(16))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                // Figma: text-green-100 text-lg font-medium - adaptive
                CelebrationSubtitle(
                    text: type.subtitle,
                    color: descriptionColor,
                    animate: showContent
                )
                .lineLimit(3)
                .minimumScaleFactor(0.9)

                Spacer(minLength: PSLayout.scaled(20))

                // Figma: CTA — only for medium/hero intensity
                if type.intensity != .small {
                    CelebrationCTA(
                        label: type.ctaLabel,
                        textColor: type.ctaTextColor,
                        shadowColor: type.ctaShadowColor,
                        animate: showContent,
                        action: onDismiss
                    )
                    .padding(.bottom, PSLayout.scaled(40))
                    .frame(maxHeight: PSLayout.scaled(60))
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
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: PSSpacing.lg) {
                // Figma: Smaller icon container — adaptive sizing
                ZStack {
                    RoundedRectangle(cornerRadius: PSLayout.scaled(18), style: .continuous)
                        .fill(type.iconBackgroundColor)
                        .frame(width: PSLayout.scaled(56), height: PSLayout.scaled(56))
                        .shadow(color: type.backgroundColor.opacity(0.3), radius: 12, y: 4)

                    Image(systemName: type.icon)
                        .font(.system(size: PSLayout.scaledFont(24), weight: .semibold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(type.subtitle)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                }

                Spacer(minLength: PSSpacing.sm)
            }
            .padding(PSLayout.scaled(16))
            .background(type.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .shadow(color: type.backgroundColor.opacity(0.3), radius: 24, y: 12)
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            // Position above tab bar safely on all devices
            .padding(.bottom, max(PSLayout.tabBarContentPadding + PSSpacing.xl, PSLayout.scaled(100)))
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : PSLayout.scaled(60))
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .ignoresSafeArea(.keyboard)
        .onAppear {
            if reduceMotion {
                showContent = true
            } else {
                withAnimation(PSMotion.springBouncy) {
                    showContent = true
                }
            }
            // Haptic with reduce motion awareness
            if !reduceMotion {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            // Auto-dismiss with appropriate timing
            let dismissDelayMs = reduceMotion ? 2500 : 3000
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(dismissDelayMs))
                withAnimation(reduceMotion ? .none : PSMotion.easeDefault) {
                    onDismiss()
                }
            }
        }
        .onTapGesture { onDismiss() }
    }
}
