import SwiftUI
import os

// MARK: - Freshli Signature Loading Experience
// Immersive dark-forest splash with an animated leaf logo, floating food
// decorations, sparkle particles, and a fluid progress bar.
// Guaranteed minimum display time is enforced in FreshliApp — this view
// only handles its own visuals and animation sequencing.

@MainActor
struct FreshliSplashView: View {

    // MARK: - Namespace for matched geometry morph
    let splashNamespace: Namespace.ID

    // MARK: - Callbacks (unused for transition logic, kept for API compat)
    let onSessionValidated: () -> Void
    let onDataPrefetched: () -> Void

    // MARK: - Animation State

    // Leaf
    @State private var leafTrimEnd: CGFloat = 0
    @State private var leafScale: CGFloat = 0.25
    @State private var leafOpacity: CGFloat = 0
    @State private var leafGlowPhase: CGFloat = 0

    // Wordmark
    @State private var textTracking: CGFloat = 18
    @State private var textOpacity: CGFloat = 0

    // Tagline
    @State private var taglineOpacity: CGFloat = 0

    // Progress
    @State private var loadingProgress: CGFloat = 0
    @State private var dropletPhase: CGFloat = 0
    @State private var showWarmTip: Bool = false

    // Ambient decorations
    @State private var floatPhase: CGFloat = 0
    @State private var circleScale1: CGFloat = 0
    @State private var circleScale2: CGFloat = 0
    @State private var circleOpacity1: CGFloat = 0
    @State private var circleOpacity2: CGFloat = 0

    // Timing
    @State private var loadStartTime: Date = .now

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let logger = Logger(subsystem: "com.freshli.app", category: "Splash")

    // MARK: - Floating food decorations (positioned as fraction of half-screen)
    // (emoji, xFrac, yFrac, fontSize, floatDelay)
    private let foodItems: [(String, CGFloat, CGFloat, CGFloat, Double)] = [
        ("🥦", -0.38, -0.31, 42, 0.0),
        ("🍎", 0.40, -0.36, 36, 0.4),
        ("🥕", -0.43,  0.06, 34, 0.8),
        ("🥑",  0.42,  0.10, 38, 0.2),
        ("🍋", -0.32,  0.34, 32, 0.6),
        ("🫐",  0.36,  0.32, 34, 1.0),
    ]

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1 — Immersive dark-forest gradient background
                splashBackground
                    .ignoresSafeArea()

                // 2 — Large ambient blurred circles (depth & atmosphere)
                ambientCircles(in: geo)

                // 3 — Floating food emojis around the edges
                if !reduceMotion {
                    floatingEmojis(in: geo)
                }

                // 4 — Central content column
                VStack(spacing: 0) {
                    Spacer()

                    // Logo + wordmark + tagline
                    VStack(spacing: PSSpacing.xxl) {
                        logoSection
                        wordmarkSection
                    }

                    Spacer()

                    // Loading section (progress bar + warm tip)
                    loadingSection
                        .padding(.bottom, PSLayout.scaled(60))
                }
            }
        }
        // Force dark environment so PSColors and FluidLoadingBar read dark tokens
        .environment(\.colorScheme, .dark)
        .onAppear {
            loadStartTime = .now
            if reduceMotion {
                leafScale    = 1.0
                leafOpacity  = 1.0
                leafTrimEnd  = 1.0
                textTracking = 0
                textOpacity  = 1.0
                taglineOpacity = 1.0
                loadingProgress = 0.35
                circleScale1 = 1; circleOpacity1 = 1
                circleScale2 = 1; circleOpacity2 = 1
            } else {
                startAnimationSequence()
            }
            startWarmTipTimer()
        }
    }

    // MARK: - Background

    private var splashBackground: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x051A0D), location: 0.00),
                .init(color: Color(hex: 0x0D3320), location: 0.55),
                .init(color: Color(hex: 0x073528), location: 1.00),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Ambient Circles

    private func ambientCircles(in geo: GeometryProxy) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x22C55E).opacity(0.10))
                .frame(width: PSLayout.scaled(320))
                .blur(radius: 60)
                .offset(x: geo.size.width * 0.30, y: -geo.size.height * 0.28)
                .scaleEffect(circleScale1)
                .opacity(circleOpacity1)

            Circle()
                .fill(Color(hex: 0x14B8A6).opacity(0.08))
                .frame(width: PSLayout.scaled(280))
                .blur(radius: 50)
                .offset(x: -geo.size.width * 0.28, y: geo.size.height * 0.25)
                .scaleEffect(circleScale2)
                .opacity(circleOpacity2)
        }
    }

    // MARK: - Floating Emojis

    private func floatingEmojis(in geo: GeometryProxy) -> some View {
        let hw = geo.size.width  / 2
        let hh = geo.size.height / 2
        return ZStack {
            ForEach(Array(foodItems.enumerated()), id: \.offset) { idx, item in
                Text(item.0)
                    .font(.system(size: item.2))
                    .opacity(0.22 + sin(floatPhase * .pi * 2 + Double(idx) * 1.1) * 0.08)
                    .offset(
                        x: item.1 * hw + sin(floatPhase * .pi + Double(idx) * 0.7) * 9,
                        y: item.2 * hh * 0.01 + item.3 * hh + cos(floatPhase * .pi * 1.2 + Double(idx) * 0.5) * 13
                    )
                    .rotationEffect(.degrees(sin(floatPhase * .pi + Double(idx)) * 9))
            }
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        ZStack {
            // Outermost breathing glow
            if !reduceMotion {
                Circle()
                    .fill(Color(hex: 0x22C55E).opacity(0.10 + leafGlowPhase * 0.08))
                    .frame(width: PSLayout.scaled(200))
                    .blur(radius: 40 + leafGlowPhase * 10)
            }

            // Frosted inner backdrop circle
            Circle()
                .fill(.white.opacity(0.06 + leafGlowPhase * 0.02))
                .frame(width: PSLayout.scaled(150))

            // The animated leaf
            ZStack {
                // Glow halo
                if !reduceMotion {
                    leafShape
                        .fill(.white.opacity(0.18 + leafGlowPhase * 0.10))
                        .blur(radius: 22 + leafGlowPhase * 8)
                        .scaleEffect(1.25 + leafGlowPhase * 0.12)
                }

                // Outline + filled overlay
                leafShape
                    .trim(from: 0, to: reduceMotion ? 1 : leafTrimEnd)
                    .stroke(
                        .white,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .overlay {
                        leafShape
                            .trim(from: 0, to: reduceMotion ? 1 : leafTrimEnd)
                            .fill(.white.opacity(leafTrimEnd > 0.75 ? (leafTrimEnd - 0.75) * 3.5 : 0))
                    }
            }
            .frame(width: PSLayout.scaled(96), height: PSLayout.scaled(96))
            .scaleEffect(leafScale)
            .opacity(leafOpacity)
            .matchedGeometryEffect(id: "freshliLogo", in: splashNamespace)
        }
    }

    // MARK: - Wordmark + Tagline

    private var wordmarkSection: some View {
        VStack(spacing: PSSpacing.sm) {
            Text("Freshli")
                .font(.system(size: PSLayout.scaledFont(46), weight: .bold, design: .rounded))
                .tracking(reduceMotion ? 0 : textTracking)
                .foregroundStyle(.white)
                .opacity(textOpacity)
                .matchedGeometryEffect(id: "freshliTitle", in: splashNamespace)

            Text("Never waste. Always fresh.")
                .font(.system(size: PSLayout.scaledFont(15), weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
                .opacity(taglineOpacity)
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: PSSpacing.md) {
            if showWarmTip {
                Text("Gathering your freshest data...")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            }

            // Progress bar — light green on dark background
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(height: PSLayout.scaled(5))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x4ADE80), Color(hex: 0x22C55E)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: PSLayout.scaled(5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: loadingProgress, anchor: .leading)
            }
            .padding(.horizontal, PSSpacing.xxxxl)
        }
    }

    // MARK: - Leaf Shape (reuse existing)

    private var leafShape: some Shape { FreshliLeafShape() }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Phase 1: Ambient circles bloom in (0s)
        withAnimation(.easeOut(duration: 1.0)) {
            circleScale1  = 1.0
            circleOpacity1 = 1.0
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            circleScale2  = 1.0
            circleOpacity2 = 1.0
        }

        // Phase 2: Leaf scales in + fades (0–0.6s)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) {
            leafScale   = 1.0
            leafOpacity = 1.0
        }

        // Phase 3: Trim path draws the leaf outline (0.25–1.1s)
        withAnimation(.easeInOut(duration: 0.85).delay(0.25)) {
            leafTrimEnd = 1.0
        }

        // Phase 4: Wordmark tracking collapses in (0.45–1.15s)
        withAnimation(FLMotion.freshliCurve.delay(0.45)) {
            textTracking = 0
            textOpacity  = 1.0
        }

        // Phase 5: Tagline fades in (0.85s)
        withAnimation(.easeInOut(duration: 0.7).delay(0.85)) {
            taglineOpacity = 1.0
        }

        // Phase 6: Progress bar starts moving (0.6s)
        withAnimation(.easeInOut(duration: 1.2).delay(0.6)) {
            loadingProgress = 0.40
        }

        // Phase 7: Breathing glow loop
        withAnimation(
            .easeInOut(duration: 1.8)
            .repeatForever(autoreverses: true)
        ) {
            leafGlowPhase = 1.0
        }

        // Phase 8: Droplet animation loop (not used in simplified bar but kept)
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            dropletPhase = 1.0
        }

        // Phase 9: Float loop for food emojis
        withAnimation(
            .easeInOut(duration: 5.0)
            .repeatForever(autoreverses: true)
        ) {
            floatPhase = 1.0
        }
    }

    private func startWarmTipTimer() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            let elapsed = Date.now.timeIntervalSince(loadStartTime)
            if elapsed >= 1.8 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showWarmTip = true
                }
            }
        }
    }
}

// MARK: - Freshli Leaf Shape (Custom Path)
// Kept here alongside the splash so both compile in the same module unit.

struct FreshliLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w  = rect.width
        let h  = rect.height
        let cx = rect.midX
        let cy = rect.midY

        // Outer organic leaf — pointed tip at top, rounded at bottom
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

        // Centre vein
        path.move(to: CGPoint(x: cx, y: cy - h * 0.35))
        path.addLine(to: CGPoint(x: cx, y: cy + h * 0.35))

        // Left side vein
        path.move(to: CGPoint(x: cx, y: cy - h * 0.10))
        path.addQuadCurve(
            to:      CGPoint(x: cx - w * 0.20, y: cy + h * 0.10),
            control: CGPoint(x: cx - w * 0.15, y: cy - h * 0.05)
        )

        // Right side vein
        path.move(to: CGPoint(x: cx, y: cy + h * 0.05))
        path.addQuadCurve(
            to:      CGPoint(x: cx + w * 0.20, y: cy + h * 0.22),
            control: CGPoint(x: cx + w * 0.15, y: cy + h * 0.08)
        )

        return path
    }
}

// MARK: - Splash Transition Modifier

struct SplashTransitionModifier: ViewModifier {
    let isTransitioning: Bool
    let splashNamespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .scaleEffect(isTransitioning ? 0.93 : 1.0)
            .opacity(isTransitioning ? 0 : 1)
            .animation(
                .spring(Spring(mass: 1.0, stiffness: 120, damping: 20)),
                value: isTransitioning
            )
    }
}

extension View {
    func splashTransition(isTransitioning: Bool, namespace: Namespace.ID) -> some View {
        modifier(SplashTransitionModifier(isTransitioning: isTransitioning, splashNamespace: namespace))
    }
}
