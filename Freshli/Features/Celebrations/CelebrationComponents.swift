import SwiftUI

// MARK: - CelebrationContainer
// Figma: Full-screen bg with two radial pulse circles, overlay blend mode
// Entry: opacity 0→1, content scales from 0.9→1 with springBouncy

struct CelebrationContainer<Content: View>: View {
    let type: CelebrationType
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var showContent = false
    @State private var showPulse1 = false
    @State private var showPulse2 = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Figma: Full-screen background
            type.backgroundColor
                .ignoresSafeArea()

            // Figma: 120vw radial pulse — bg-[color]-400 opacity 30% mix-blend-overlay
            Circle()
                .fill(type.iconBackgroundColor.opacity(0.3))
                .frame(
                    width: UIScreen.main.bounds.width * 1.2,
                    height: UIScreen.main.bounds.width * 1.2
                )
                .scaleEffect(showPulse1 ? 1 : 0)
                .opacity(showPulse1 ? 1 : 0)
                .blendMode(.overlay)

            // Figma: 80vw radial pulse — bg-[color]-300 opacity 40% mix-blend-overlay
            Circle()
                .fill(type.pulseColor.opacity(0.4))
                .frame(
                    width: UIScreen.main.bounds.width * 0.8,
                    height: UIScreen.main.bounds.width * 0.8
                )
                .scaleEffect(showPulse2 ? 1 : 0)
                .opacity(showPulse2 ? 1 : 0)
                .blendMode(.overlay)

            // Content
            content()
                .scaleEffect(showContent ? 1 : 0.9)
                .opacity(showContent ? 1 : 0)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .onAppear {
            if reduceMotion {
                showContent = true
                showPulse1 = true
                showPulse2 = true
            } else {
                // Figma: springs.slow with staggered delays for pulses
                withAnimation(PSMotion.springGentle.delay(0.1)) {
                    showPulse1 = true
                }
                withAnimation(PSMotion.springGentle.delay(0.2)) {
                    showPulse2 = true
                }
                withAnimation(PSMotion.springBouncy.delay(0.1)) {
                    showContent = true
                }
            }
        }
        .onDisappear {
            showContent = false
            showPulse1 = false
            showPulse2 = false
        }
    }
}

// MARK: - CelebrationHeroGraphic
// Figma: w-32 h-32 bg-[color]-400 rounded-[2.5rem] shadow-2xl
// Icon: 64px white, scale 0.8→1 with springBouncy.delay(0.2)
// Confetti particles surround the icon container

struct CelebrationHeroGraphic: View {
    let type: CelebrationType
    let animate: Bool

    @State private var iconScale: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Figma: Icon container
            RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                .fill(type.iconBackgroundColor)
                .frame(width: 128, height: 128)
                .shadow(color: .black.opacity(0.25), radius: 25, y: 12)

            // Figma: Icon — 64px white
            Image(systemName: type.icon)
                .font(.system(size: 64, weight: .regular))
                .foregroundStyle(.white)
                .scaleEffect(iconScale)

            // Figma: Confetti particles
            CelebrationParticleLayer(
                count: type.confettiCount,
                trigger: animate,
                accentColor: type.pulseColor
            )
        }
        .scaleEffect(animate ? 1 : 0.5)
        .opacity(animate ? 1 : 0)
        .onChange(of: animate) { _, newValue in
            if newValue && !reduceMotion {
                withAnimation(PSMotion.springBouncy.delay(0.2)) {
                    iconScale = 1.0
                }
            } else if newValue {
                iconScale = 1.0
            }
        }
    }
}

// MARK: - CelebrationHeadline
// Figma: text-4xl font-black text-white tracking-tight mb-4

struct CelebrationHeadline: View {
    let text: String
    var color: Color = .white
    let animate: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .black))
            .tracking(-0.5)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
    }
}

// MARK: - CelebrationSubtitle
// Figma: text-green-100 text-lg font-medium leading-relaxed px-4

struct CelebrationSubtitle: View {
    let text: String
    var color: Color = Color(hex: 0xDCFCE7) // green-100 default
    let animate: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .opacity(animate ? 1 : 0)
            .offset(y: animate ? 0 : 20)
    }
}

// MARK: - CelebrationCTA
// Figma: w-full h-16 bg-white text-green-600 rounded-[1.25rem]
// shadow-xl shadow-green-900/20, font-bold text-lg
// Entry: y+30→0 with springs.medium.delay(0.3)

struct CelebrationCTA: View {
    let label: String
    var textColor: Color = Color(hex: 0x16A34A) // green-600
    var shadowColor: Color = Color(hex: 0x14532D).opacity(0.2) // green-900/20
    let animate: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .shadow(color: shadowColor, radius: 20, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .adaptiveHPadding()
        .opacity(animate ? 1 : 0)
        .offset(y: animate ? 0 : 30)
    }
}

// MARK: - CelebrationBadge
// Figma: Achievement badge with ring pulse animation
// Circle with icon, ring grows from 1→1.3 and fades

struct CelebrationBadge: View {
    let icon: String
    let color: Color
    let animate: Bool

    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Pulse ring
            Circle()
                .strokeBorder(color.opacity(ringOpacity), lineWidth: 4)
                .frame(width: 100, height: 100)
                .scaleEffect(ringScale)

            // Badge circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(color: color.opacity(0.3), radius: 16, y: 8)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
        }
        .scaleEffect(animate ? 1 : 0)
        .onChange(of: animate) { _, newValue in
            if newValue && !reduceMotion {
                // Pulse ring animation loop (3 pulses)
                for i in 0..<3 {
                    let delay = 0.3 + Double(i) * 0.8
                    withAnimation(.easeOut(duration: 0.6).delay(delay)) {
                        ringScale = 1.4
                        ringOpacity = 0
                    }
                    withAnimation(.easeOut(duration: 0.01).delay(delay + 0.6)) {
                        ringScale = 1.0
                        ringOpacity = 0.6
                    }
                }
            }
        }
    }
}

// MARK: - CelebrationStatBlock
// Figma: Stat tile with icon, count-up value, and label
// Used in weekly recap and milestone celebrations

struct CelebrationStatBlock: View {
    let icon: String
    let value: String
    let label: String
    var iconColor: Color = .white
    let animate: Bool
    var delay: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .opacity(animate ? 1 : 0)
        .scaleEffect(animate ? 1 : 0.8)
        .offset(y: animate ? 0 : 20)
    }
}
