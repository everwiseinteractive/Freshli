import SwiftUI

// MARK: - Duolingo-Style Celebration Overlay
// Full-screen celebration that sits above ALL content (navigation bars,
// tab bars, Dynamic Island). Every celebration type gets the same
// premium full-screen treatment — no small toasts.
// Dismissed ONLY by the user tapping the CTA button.

struct CelebrationOverlay: View {
    @Bindable var manager: CelebrationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let celebration = manager.activeCelebration {
                DuolingoCelebrationView(
                    type: celebration,
                    onDismiss: { manager.dismissCelebration() }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.08))
                    )
                )
                .zIndex(1000)
                .ignoresSafeArea(.all)
            }
        }
        .animation(
            reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.2),
            value: manager.activeCelebration?.id
        )
    }
}

// MARK: - Duolingo Celebration View
// The hero — a full-screen, vibrant, bouncy celebration card.

private struct DuolingoCelebrationView: View {
    let type: CelebrationType
    let onDismiss: () -> Void

    // MARK: - Staggered Animation State
    @State private var showBackground = false
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showCTA = false
    @State private var showConfetti = false
    @State private var iconBounce: CGFloat = 0
    @State private var pulseScale: CGFloat = 0.6
    @State private var pulseOpacity: CGFloat = 0.6
    @State private var pulse2Scale: CGFloat = 0.4
    @State private var pulse2Opacity: CGFloat = 0.5
    @State private var ctaScale: CGFloat = 1.0
    @State private var starRotation: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Layer 1: Vibrant solid background
            type.backgroundColor
                .ignoresSafeArea()
                .opacity(showBackground ? 1 : 0)

            // Layer 2: Animated radial pulse rings
            if showIcon && !reduceMotion {
                pulseRings
            }

            // Layer 3: Floating star particles
            if showConfetti && !reduceMotion {
                CelebrationConfettiCanvas(
                    count: type.confettiCount,
                    colors: [type.pulseColor, type.iconBackgroundColor, .white, .yellow]
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Layer 4: Content stack
            VStack(spacing: 0) {
                Spacer()

                // Icon section
                if showIcon {
                    iconSection
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }

                Spacer().frame(height: 32)

                // Title
                if showTitle {
                    Text(type.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.asymmetric(
                            insertion: .offset(y: 30).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                Spacer().frame(height: 14)

                // Subtitle
                if showSubtitle {
                    Text(type.subtitle)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineSpacing(4)
                        .transition(.offset(y: 20).combined(with: .opacity))
                }

                Spacer()

                // Weekly Recap stats (special layout)
                if case .weeklyRecap(let saved, let shared, let co2, let money) = type, showSubtitle {
                    weeklyRecapStats(saved: saved, shared: shared, co2: co2, money: money)
                        .transition(.offset(y: 20).combined(with: .opacity))
                    Spacer().frame(height: 24)
                }

                // Streak counter (special layout)
                if case .expiryRescueStreak(let count) = type, showSubtitle {
                    streakCounter(count: count)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    Spacer().frame(height: 24)
                }

                // CTA Button
                if showCTA {
                    ctaButton
                        .transition(.offset(y: 60).combined(with: .opacity))
                }

                // Enough clearance for the home indicator + safe area
                // so the CTA button is never obscured.
                Spacer().frame(height: 100)
            }
        }
        .onAppear {
            // Hide the floating tab bar so it doesn't overlap the CTA button
            TabBarVisibilityService.shared.hide()

            if reduceMotion {
                showBackground = true
                showIcon = true
                showTitle = true
                showSubtitle = true
                showCTA = true
                showConfetti = true
            } else {
                startAnimationCascade()
            }
            // Haptic
            PSHaptics.shared.success()
        }
        .onDisappear {
            // Restore the floating tab bar when the celebration is dismissed
            TabBarVisibilityService.shared.show()
        }
    }

    // MARK: - Icon Section

    private var iconSection: some View {
        ZStack {
            // Glow behind icon
            Circle()
                .fill(type.iconBackgroundColor.opacity(0.3))
                .frame(width: 160, height: 160)
                .blur(radius: 30)

            // Icon container
            Circle()
                .fill(type.iconBackgroundColor)
                .frame(width: 120, height: 120)
                .shadow(color: type.backgroundColor.opacity(0.5), radius: 20, y: 8)
                .overlay {
                    Image(systemName: type.icon)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: iconBounce)
                }
                .scaleEffect(showIcon ? 1.0 : 0.3)
                // Floating rotation for stars/trophies
                .rotationEffect(.degrees(starRotation))
        }
    }

    // MARK: - Pulse Rings

    private var pulseRings: some View {
        ZStack {
            Circle()
                .stroke(type.pulseColor.opacity(pulseOpacity * 0.3), lineWidth: 2)
                .frame(width: 200 * pulseScale, height: 200 * pulseScale)

            Circle()
                .stroke(type.pulseColor.opacity(pulse2Opacity * 0.2), lineWidth: 1.5)
                .frame(width: 280 * pulse2Scale, height: 280 * pulse2Scale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseScale = 2.0
                pulseOpacity = 0
            }
            withAnimation(.easeOut(duration: 2.0).delay(0.3).repeatForever(autoreverses: false)) {
                pulse2Scale = 2.5
                pulse2Opacity = 0
            }
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: {
            if !reduceMotion {
                withAnimation(.spring(duration: 0.15)) {
                    ctaScale = 0.92
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(.spring(duration: 0.15)) {
                        ctaScale = 1.0
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                    onDismiss()
                }
            } else {
                onDismiss()
            }
            PSHaptics.shared.lightTap()
        }) {
            Text(type.ctaLabel)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(type.ctaTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: type.ctaShadowColor.opacity(0.3), radius: 12, y: 6)
        }
        .scaleEffect(ctaScale)
        .padding(.horizontal, 32)
    }

    // MARK: - Weekly Recap Stats Grid

    private func weeklyRecapStats(saved: Int, shared: Int, co2: Double, money: Double) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(value: "\(saved)", label: "Food Saved", icon: "leaf.fill", color: .green)
            statCard(value: "\(shared)", label: "Items Shared", icon: "hand.raised.fill", color: .blue)
            statCard(value: String(format: "%.1fkg", co2), label: "CO\u{2082} Avoided", icon: "wind", color: .teal)
            statCard(value: String(format: "$%.0f", money), label: "Money Saved", icon: "dollarsign.circle.fill", color: .yellow)
        }
        .padding(.horizontal, 32)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Streak Counter

    private func streakCounter(count: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<min(count, 7), id: \.self) { i in
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(i < count ? .orange : .white.opacity(0.3))
                    Text("D\(i + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Animation Cascade

    private func startAnimationCascade() {
        // Phase 1: Background (instant)
        withAnimation(.easeOut(duration: 0.3)) {
            showBackground = true
        }

        // Phase 2: Icon bounces in (0.15s delay)
        withAnimation(.spring(duration: 0.6, bounce: 0.4).delay(0.15)) {
            showIcon = true
        }
        // Icon symbol bounce
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            iconBounce += 1
        }

        // Phase 3: Title slides up (0.35s delay)
        withAnimation(.spring(duration: 0.5, bounce: 0.25).delay(0.35)) {
            showTitle = true
        }

        // Phase 4: Subtitle fades in (0.55s delay)
        withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(0.55)) {
            showSubtitle = true
        }

        // Phase 5: Confetti burst (0.4s delay)
        withAnimation(.spring(duration: 0.4, bounce: 0.2).delay(0.4)) {
            showConfetti = true
        }

        // Phase 6: CTA button rises (0.75s delay)
        withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.75)) {
            showCTA = true
        }

        // Subtle floating rotation for icon (continuous)
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true).delay(1.0)) {
            starRotation = 5
        }
    }
}

// MARK: - Confetti Canvas

private struct CelebrationConfettiCanvas: View {
    let count: Int
    let colors: [Color]

    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let age = elapsed - particle.birth
                    guard age >= 0 && age < particle.lifetime else { continue }

                    let progress = age / particle.lifetime

                    // Physics: gravity + drag
                    let gravity: Double = 220
                    let draggedVX = particle.vx * pow(0.98, age * 60)
                    let draggedVY = particle.vy * pow(0.98, age * 60)

                    let x = particle.startX + draggedVX * age
                    let y = particle.startY + draggedVY * age + 0.5 * gravity * age * age

                    // Fade out in last 40%
                    let opacity = progress > 0.6 ? 1.0 - ((progress - 0.6) / 0.4) : 1.0

                    // Rotation
                    let angle = Angle.degrees(particle.rotationSpeed * age * 360)

                    // Scale down near end
                    let scale = progress > 0.7 ? 1.0 - ((progress - 0.7) / 0.3) * 0.5 : 1.0

                    let rect = CGRect(
                        x: x - particle.size * scale / 2,
                        y: y - particle.size * scale / 2,
                        width: particle.size * scale,
                        height: particle.size * scale
                    )

                    context.opacity = opacity
                    context.translateBy(x: x, y: y)
                    context.rotate(by: angle)
                    context.translateBy(x: -x, y: -y)

                    let resolved = context.resolve(particle.shape == .circle
                        ? Image(systemName: "circle.fill")
                        : particle.shape == .star
                        ? Image(systemName: "star.fill")
                        : Image(systemName: "sparkle"))

                    context.draw(resolved, in: rect)
                    // Reset transform
                    context.translateBy(x: x, y: y)
                    context.rotate(by: -angle)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .onAppear {
            spawnParticles()
        }
    }

    private func spawnParticles() {
        let now = Date.timeIntervalSinceReferenceDate
        let screenW: Double = 393
        let screenH: Double = 852
        let centerX = screenW / 2
        let centerY = screenH * 0.35

        particles = (0..<max(count * 4, 20)).map { _ in
            let angle = Double.random(in: 0..<(.pi * 2))
            let speed = Double.random(in: 150...450)
            return ConfettiParticle(
                startX: centerX + Double.random(in: -20...20),
                startY: centerY + Double.random(in: -20...20),
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - Double.random(in: 100...250),
                size: Double.random(in: 6...14),
                birth: now + Double.random(in: 0...0.3),
                lifetime: Double.random(in: 1.5...3.0),
                rotationSpeed: Double.random(in: 0.5...2.0),
                shape: [ConfettiShape.circle, .star, .sparkle].randomElement()!
            )
        }
    }
}

private struct ConfettiParticle {
    let startX: Double
    let startY: Double
    let vx: Double
    let vy: Double
    let size: Double
    let birth: Double
    let lifetime: Double
    let rotationSpeed: Double
    let shape: ConfettiShape
}

private enum ConfettiShape {
    case circle, star, sparkle
}

// MARK: - View Extension

extension View {
    func celebrationOverlay(manager: CelebrationManager) -> some View {
        ZStack {
            self
            CelebrationOverlay(manager: manager)
        }
    }
}
