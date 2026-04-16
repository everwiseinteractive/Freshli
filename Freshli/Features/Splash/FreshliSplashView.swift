import SwiftUI
import CoreHaptics

// MARK: - Freshli Splash Screen
// ════════════════════════════════════════════════════════════════
// Apple Design Award — Visuals & Graphics · Innovation · Inclusivity
//
// Architecture (ZStack overlay model):
//   The main app renders BEHIND this view from launch. When all
//   loading gates pass the splash dissolves to reveal the already-
//   interactive home screen — zero view swaps, zero jarring cuts.
//
// Visual layers:
//   1. Living ambient gradient (breathing emerald on near-black)
//   2. Luminous halo that breathes behind the icon
//   3. Freshli icon crystallising from soft blur
//   4. Orbital progress ring (fills as services initialise)
//   5. "Freshli" wordmark + tagline
//
// Exit:
//   Progress ring completes → brief settle → icon exhales outward
//   while the entire splash fades to transparent, lifting a veil
//   off the home screen that was loading underneath all along.
//
// Accessibility:
//   - Reduce Motion: static MeshGradient, no animations, instant
//   - VoiceOver: "Freshli is loading" announcement
//   - Dynamic Type: all text uses PSLayout.scaledFont
//   - Haptic-visual sync for every entrance phase
// ════════════════════════════════════════════════════════════════

@MainActor
struct FreshliSplashView: View {

    // MARK: - API

    /// Loading progress (0…1) driven by FreshliApp's pipeline.
    let progress: CGFloat

    /// When true, begins the exit dissolve animation.
    let shouldExit: Bool

    /// Fires after the exit animation completes; FreshliApp removes the splash.
    let onExitComplete: () -> Void

    // MARK: - Entrance Animation State

    @State private var startDate = Date.now
    @State private var showBackground  = false
    @State private var showIcon        = false
    @State private var iconBlur: CGFloat = 24
    @State private var showRing        = false
    @State private var showWordmark    = false
    @State private var showTagline     = false

    // MARK: - Exit Animation State

    @State private var exitActive      = false
    @State private var exitScale: CGFloat  = 1.0
    @State private var exitOpacity: CGFloat = 1.0

    // MARK: - Continuous Animations

    @State private var shimmerPhase: CGFloat = -0.3
    @State private var haloBreathScale: CGFloat = 1.0

    // MARK: - Progress Display

    /// Smoothed value — only moves forward, never snaps backward.
    @State private var displayProgress: CGFloat = 0

    // MARK: - Haptics

    @State private var hapticEngine: CHHapticEngine?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: Ambient gradient
                if reduceMotion {
                    reducedMotionBackground
                        .ignoresSafeArea()
                } else {
                    ambientBackground
                        .ignoresSafeArea()
                        .opacity(showBackground ? 1 : 0)
                }

                // Layer 2: Content stack
                VStack(spacing: 0) {
                    Spacer()
                    Spacer()

                    iconCluster(screenSize: geo.size)

                    Spacer().frame(height: PSLayout.scaled(32))

                    wordmarkLabel

                    Spacer()
                    Spacer()

                    taglineLabel
                        .padding(.bottom, PSLayout.scaled(64))
                }
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .opacity(exitOpacity)
        .scaleEffect(exitScale)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Freshli is loading"))
        .onAppear {
            prepareHaptics()
            if reduceMotion {
                setInstantState()
            } else {
                startEntranceSequence()
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.4)) {
                displayProgress = max(displayProgress, newValue)
            }
        }
        .onChange(of: shouldExit) { _, exit in
            guard exit, !exitActive else { return }
            beginExitSequence()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Ambient Background
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var ambientBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            let breathe = sin(t * 0.4) * 0.5 + 0.5

            ZStack {
                // Near-black with emerald undertones
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.02, green: 0.04, blue: 0.03), location: 0),
                        .init(color: Color(red: 0.03, green: 0.08 + breathe * 0.02, blue: 0.06), location: 0.5),
                        .init(color: Color(red: 0.01, green: 0.03, blue: 0.02), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle centre glow — makes the background feel alive
                RadialGradient(
                    colors: [
                        PSColors.primaryGreen.opacity(0.06 + breathe * 0.03),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 400
                )
            }
        }
    }

    /// Reduce Motion: high-contrast static MeshGradient (Inclusivity).
    private var reducedMotionBackground: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                .init(0.0, 0.0), .init(0.5, 0.0), .init(1.0, 0.0),
                .init(0.0, 0.5), .init(0.5, 0.5), .init(1.0, 0.5),
                .init(0.0, 1.0), .init(0.5, 1.0), .init(1.0, 1.0)
            ],
            colors: [
                .black,               Color(red: 0.04, green: 0.08, blue: 0.05), .black,
                Color(red: 0.04, green: 0.08, blue: 0.05), Color(red: 0.06, green: 0.14, blue: 0.08), Color(red: 0.04, green: 0.08, blue: 0.05),
                .black,               Color(red: 0.04, green: 0.08, blue: 0.05), .black
            ]
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Icon Cluster (Halo + Ring + Icon)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func iconCluster(screenSize: CGSize) -> some View {
        let iconSize  = PSLayout.scaled(120)
        let ringSize  = iconSize + PSLayout.scaled(48)

        return ZStack {
            // ── Glow halo ──
            if showIcon {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PSColors.primaryGreen.opacity(0.18),
                                PSColors.primaryGreen.opacity(0.05),
                                .clear
                            ],
                            center: .center,
                            startRadius: iconSize * 0.3,
                            endRadius: iconSize * 1.2
                        )
                    )
                    .frame(width: iconSize * 2.4, height: iconSize * 2.4)
                    .scaleEffect(haloBreathScale)
            }

            // ── Progress ring ──
            if showRing {
                progressRingLayers(ringSize: ringSize)
            }

            // ── App icon ──
            if showIcon {
                Image("FreshliIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
                    .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 40, y: 0)
                    .blur(radius: iconBlur)
                    .modifier(SplashShimmerModifier(reduceMotion: reduceMotion, shimmerProgress: shimmerPhase))
            }
        }
    }

    @ViewBuilder
    private func progressRingLayers(ringSize: CGFloat) -> some View {
        ZStack {
            // Track (dim)
            Circle()
                .stroke(
                    .white.opacity(0.06),
                    style: StrokeStyle(lineWidth: PSLayout.scaled(3), lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)

            // Fill arc
            Circle()
                .trim(from: 0, to: displayProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            PSColors.primaryGreen.opacity(0.9),
                            PSColors.accentTeal.opacity(0.7),
                            PSColors.primaryGreen.opacity(0.9)
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: PSLayout.scaled(3), lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            // Glowing dot at the tip of the arc
            if displayProgress > 0.05 {
                Circle()
                    .fill(PSColors.primaryGreen)
                    .frame(width: PSLayout.scaled(7), height: PSLayout.scaled(7))
                    .shadow(color: PSColors.primaryGreen.opacity(0.6), radius: 8)
                    .offset(y: -ringSize / 2)
                    .rotationEffect(.degrees(360 * displayProgress - 90))
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Typography
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private var wordmarkLabel: some View {
        Text("Freshli")
            .font(.system(size: PSLayout.scaledFont(38), weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, Color(red: 0.73, green: 0.97, blue: 0.83)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(showWordmark ? 1 : 0)
            .offset(y: showWordmark ? 0 : 20)
    }

    private var taglineLabel: some View {
        Text(String(localized: "Rescue food. Save the planet."))
            .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.4))
            .opacity(showTagline ? 1 : 0)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Entrance Choreography
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func startEntranceSequence() {
        // Phase 0: Background sweeps in
        withAnimation(.easeOut(duration: 0.5)) {
            showBackground = true
        }

        // Phase 1: Icon crystallises from blur (0.15 s)
        withAnimation(.spring(duration: 0.8, bounce: 0.15).delay(0.15)) {
            showIcon = true
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
            iconBlur = 0
        }

        // Phase 2: Progress ring appears (0.4 s)
        withAnimation(.spring(duration: 0.5, bounce: 0.2).delay(0.4)) {
            showRing = true
        }

        // Phase 3: Wordmark slides up (0.5 s)
        withAnimation(.spring(duration: 0.55, bounce: 0.18).delay(0.5)) {
            showWordmark = true
        }

        // Phase 4: Tagline fades in (0.8 s)
        withAnimation(.easeInOut(duration: 0.4).delay(0.8)) {
            showTagline = true
        }

        // Continuous: halo breathing
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            haloBreathScale = 1.06
        }

        // Continuous: shimmer sweep loop
        startShimmerLoop()

        // Choreographed haptics
        playSplashHaptics()
    }

    private func startShimmerLoop() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            while !Task.isCancelled && !exitActive {
                shimmerPhase = -0.3
                withAnimation(.easeInOut(duration: 1.0)) {
                    shimmerPhase = 1.3
                }
                try? await Task.sleep(for: .seconds(3.0))
            }
        }
    }

    /// Reduce Motion: everything at final state instantly.
    private func setInstantState() {
        showBackground = true
        showIcon       = true
        iconBlur       = 0
        showRing       = true
        showWordmark   = true
        showTagline    = true
        shimmerPhase   = 1.3
        displayProgress = progress
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Exit Sequence (Veil-Lift Dissolve)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func beginExitSequence() {
        exitActive = true

        // Completion haptic
        PSHaptics.shared.lightTap()

        // Fill the ring to 100 % first
        withAnimation(.easeInOut(duration: 0.25)) {
            displayProgress = 1.0
        }

        Task { @MainActor in
            // Brief settle so the "complete" state registers visually
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 50 : 300))

            if reduceMotion {
                onExitComplete()
            } else {
                // Icon exhales outward as the whole splash dissolves
                withAnimation(.spring(duration: 0.65, bounce: 0.0)) {
                    exitScale   = 1.08
                    exitOpacity = 0
                }
                try? await Task.sleep(for: .milliseconds(650))
                onExitComplete()
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Core Haptics
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            try engine.start()
            hapticEngine = engine
        } catch { /* graceful degradation */ }
    }

    private func playSplashHaptics() {
        guard let engine = hapticEngine else { return }

        do {
            let pattern = try CHHapticPattern(events: [
                // Icon crystallisation — soft ascending transients
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
                ], relativeTime: 0.15),

                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.40),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30)
                ], relativeTime: 0.28),

                // Ring bloom — smooth continuous pulse
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.30),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.50)
                ], relativeTime: 0.40, duration: 0.20),

                // Wordmark snap — crisp transient
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.80)
                ], relativeTime: 0.50),

                // Tagline — gentle fade
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                ], relativeTime: 0.80),
            ], parameters: [])

            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch { /* silent degradation */ }
    }
}


// MARK: - Splash Shimmer Modifier
// Diagonal light sweep across the icon — gated on Reduce Motion.

private struct SplashShimmerModifier: ViewModifier {
    let reduceMotion: Bool
    let shimmerProgress: Double

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: max(0, shimmerProgress - 0.15)),
                            .init(color: .white.opacity(0.18), location: shimmerProgress),
                            .init(color: .clear, location: min(1, shimmerProgress + 0.15))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.overlay)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
        }
    }
}


// MARK: - Freshli Leaf Shape (Retained for Compatibility)

struct FreshliLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w  = rect.width
        let h  = rect.height
        let cx = rect.midX
        let cy = rect.midY

        path.move(to: CGPoint(x: cx, y: cy - h * 0.45))
        path.addCurve(
            to:       CGPoint(x: cx + w * 0.35, y: cy + h * 0.05),
            control1: CGPoint(x: cx + w * 0.38, y: cy - h * 0.35),
            control2: CGPoint(x: cx + w * 0.42, y: cy - h * 0.10)
        )
        path.addCurve(
            to:       CGPoint(x: cx,             y: cy + h * 0.45),
            control1: CGPoint(x: cx + w * 0.30,  y: cy + h * 0.25),
            control2: CGPoint(x: cx + w * 0.15,  y: cy + h * 0.42)
        )
        path.addCurve(
            to:       CGPoint(x: cx - w * 0.35, y: cy + h * 0.05),
            control1: CGPoint(x: cx - w * 0.15,  y: cy + h * 0.42),
            control2: CGPoint(x: cx - w * 0.30,  y: cy + h * 0.25)
        )
        path.addCurve(
            to:       CGPoint(x: cx,             y: cy - h * 0.45),
            control1: CGPoint(x: cx - w * 0.42,  y: cy - h * 0.10),
            control2: CGPoint(x: cx - w * 0.38,  y: cy - h * 0.35)
        )
        path.closeSubpath()

        path.move(to: CGPoint(x: cx, y: cy - h * 0.35))
        path.addLine(to: CGPoint(x: cx, y: cy + h * 0.35))

        path.move(to: CGPoint(x: cx, y: cy - h * 0.10))
        path.addQuadCurve(
            to:      CGPoint(x: cx - w * 0.20, y: cy + h * 0.10),
            control: CGPoint(x: cx - w * 0.15, y: cy - h * 0.05)
        )

        path.move(to: CGPoint(x: cx, y: cy + h * 0.05))
        path.addQuadCurve(
            to:      CGPoint(x: cx + w * 0.20, y: cy + h * 0.22),
            control: CGPoint(x: cx + w * 0.15, y: cy + h * 0.08)
        )

        return path
    }
}
