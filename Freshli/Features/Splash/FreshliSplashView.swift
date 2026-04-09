import SwiftUI
import os

// MARK: - Freshli Signature Loading Experience
// A premium splash screen with organic leaf animation, fluid loading bar,
// and matched geometry transition into the Home Dashboard.
// Designed for iOS 26.4, Swift 6.3, supporting iPhone SE → Pro Max.

@MainActor
struct FreshliSplashView: View {
    // MARK: - Namespace for matched geometry morph
    let splashNamespace: Namespace.ID

    // MARK: - Callbacks
    let onSessionValidated: () -> Void
    let onDataPrefetched: () -> Void

    // MARK: - Animation State
    @State private var leafTrimEnd: CGFloat = 0
    @State private var leafScale: CGFloat = 0.3
    @State private var leafOpacity: CGFloat = 0
    @State private var leafGlowPhase: CGFloat = 0
    @State private var textTracking: CGFloat = 12
    @State private var textOpacity: CGFloat = 0
    @State private var loadingProgress: CGFloat = 0
    @State private var showWarmTip: Bool = false
    @State private var dropletPhase: CGFloat = 0

    // MARK: - Timing
    @State private var loadStartTime: Date = .now

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let logger = Logger(subsystem: "com.freshli.app", category: "Splash")

    // MARK: - Colors

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(hex: 0x0A0A0A) // Deep-Pantry-Black
            : Color.white           // Apple-White
    }

    private var leafColor: Color {
        PSColors.primaryGreen
    }

    private var glowColor: Color {
        PSColors.primaryGreen.opacity(0.35)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // MARK: Logo + Text (centered)
                VStack(spacing: PSSpacing.lg) {
                    // Leaf logo with glow
                    ZStack {
                        // Breathing glow
                        if !reduceMotion {
                            leafShape
                                .fill(glowColor)
                                .blur(radius: 20 + leafGlowPhase * 8)
                                .scaleEffect(1.3 + leafGlowPhase * 0.15)
                                .opacity(0.6 + leafGlowPhase * 0.2)
                        }

                        // Main leaf
                        leafShape
                            .trim(from: 0, to: reduceMotion ? 1 : leafTrimEnd)
                            .stroke(
                                leafColor,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                            )
                            .overlay {
                                leafShape
                                    .trim(from: 0, to: reduceMotion ? 1 : leafTrimEnd)
                                    .fill(leafColor.opacity(leafTrimEnd > 0.8 ? (leafTrimEnd - 0.8) * 5 : 0))
                            }
                    }
                    .frame(width: PSLayout.scaled(72), height: PSLayout.scaled(72))
                    .scaleEffect(leafScale)
                    .opacity(leafOpacity)
                    .matchedGeometryEffect(id: "freshliLogo", in: splashNamespace)

                    // "Freshli" text with tracking animation
                    Text("Freshli")
                        .font(.system(size: PSLayout.scaledFont(34), weight: .bold, design: .rounded))
                        .tracking(reduceMotion ? 0 : textTracking)
                        .foregroundStyle(PSColors.textPrimary)
                        .opacity(textOpacity)
                        .matchedGeometryEffect(id: "freshliTitle", in: splashNamespace)
                }

                Spacer()

                // MARK: Fluid Loading Bar
                VStack(spacing: PSSpacing.md) {
                    // Warm tip (shown after 2s)
                    if showWarmTip {
                        Text("Gathering your freshest data...")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                            .foregroundStyle(PSColors.textSecondary)
                            .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                    }

                    // Fluid droplet loading bar
                    FluidLoadingBar(progress: loadingProgress, phase: dropletPhase)
                        .frame(height: PSLayout.scaled(6))
                        .padding(.horizontal, PSSpacing.xxxxl)
                }
                .padding(.bottom, PSLayout.scaled(60))
            }
        }
        .onAppear {
            loadStartTime = .now
            if reduceMotion {
                leafScale = 1.0
                leafOpacity = 1.0
                leafTrimEnd = 1.0
                textTracking = 0
                textOpacity = 1.0
                loadingProgress = 0.3
            } else {
                startAnimationSequence()
            }
            startWarmTipTimer()
        }
    }

    // MARK: - Leaf Shape

    private var leafShape: some Shape {
        FreshliLeafShape()
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Phase 1: Leaf grows in (0–0.6s)
        withAnimation(.easeOut(duration: 0.6)) {
            leafScale = 1.0
            leafOpacity = 1.0
        }

        // Phase 2: Trim path draws the leaf (0.2–1.0s)
        withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
            leafTrimEnd = 1.0
        }

        // Phase 3: Text tracking collapses (0.4–1.1s)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.4)) {
            textTracking = 0
            textOpacity = 1.0
        }

        // Phase 4: Loading bar begins (0.6s+)
        withAnimation(.easeInOut(duration: 1.0).delay(0.6)) {
            loadingProgress = 0.35
        }

        // Phase 5: Breathing glow loop
        startBreathingGlow()

        // Phase 6: Droplet morphing loop
        startDropletAnimation()
    }

    private func startBreathingGlow() {
        withAnimation(
            .easeInOut(duration: 1.8)
            .repeatForever(autoreverses: true)
        ) {
            leafGlowPhase = 1.0
        }
    }

    private func startDropletAnimation() {
        withAnimation(
            .easeInOut(duration: 2.0)
            .repeatForever(autoreverses: false)
        ) {
            dropletPhase = 1.0
        }
    }

    private func startWarmTipTimer() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            let elapsed = Date.now.timeIntervalSince(loadStartTime)
            if elapsed >= 2.0 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showWarmTip = true
                }
            }
        }
    }

    // MARK: - Progress Update (called externally)

    func updateProgress(to value: CGFloat) {
        withAnimation(.easeInOut(duration: 0.4)) {
            loadingProgress = min(value, 1.0)
        }
    }
}

// MARK: - Freshli Leaf Shape (Custom Path)

struct FreshliLeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = rect.midX
        let cy = rect.midY

        // Organic leaf shape — pointed tip at top, rounded at bottom
        path.move(to: CGPoint(x: cx, y: cy - h * 0.45))

        // Right curve
        path.addCurve(
            to: CGPoint(x: cx + w * 0.35, y: cy + h * 0.05),
            control1: CGPoint(x: cx + w * 0.38, y: cy - h * 0.35),
            control2: CGPoint(x: cx + w * 0.42, y: cy - h * 0.1)
        )

        // Bottom right
        path.addCurve(
            to: CGPoint(x: cx, y: cy + h * 0.45),
            control1: CGPoint(x: cx + w * 0.3, y: cy + h * 0.25),
            control2: CGPoint(x: cx + w * 0.15, y: cy + h * 0.42)
        )

        // Bottom left
        path.addCurve(
            to: CGPoint(x: cx - w * 0.35, y: cy + h * 0.05),
            control1: CGPoint(x: cx - w * 0.15, y: cy + h * 0.42),
            control2: CGPoint(x: cx - w * 0.3, y: cy + h * 0.25)
        )

        // Left curve back to top
        path.addCurve(
            to: CGPoint(x: cx, y: cy - h * 0.45),
            control1: CGPoint(x: cx - w * 0.42, y: cy - h * 0.1),
            control2: CGPoint(x: cx - w * 0.38, y: cy - h * 0.35)
        )

        path.closeSubpath()

        // Center vein
        path.move(to: CGPoint(x: cx, y: cy - h * 0.35))
        path.addLine(to: CGPoint(x: cx, y: cy + h * 0.35))

        // Left vein
        path.move(to: CGPoint(x: cx, y: cy - h * 0.1))
        path.addQuadCurve(
            to: CGPoint(x: cx - w * 0.2, y: cy + h * 0.1),
            control: CGPoint(x: cx - w * 0.15, y: cy - h * 0.05)
        )

        // Right vein
        path.move(to: CGPoint(x: cx, y: cy + h * 0.05))
        path.addQuadCurve(
            to: CGPoint(x: cx + w * 0.2, y: cy + h * 0.22),
            control: CGPoint(x: cx + w * 0.15, y: cy + h * 0.08)
        )

        return path
    }
}

// MARK: - Fluid Loading Bar (Morphing Droplets)

struct FluidLoadingBar: View {
    let progress: CGFloat
    let phase: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    private let dropletCount = 8

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let barHeight = geo.size.height

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(PSColors.backgroundSecondary)

                // Filled portion with droplet morphing
                Canvas { context, size in
                    let filledWidth = size.width * progress

                    for i in 0..<dropletCount {
                        let baseX = (CGFloat(i) + 0.5) / CGFloat(dropletCount) * totalWidth
                        let normalizedX = baseX / totalWidth

                        // Only show droplets up to current progress
                        guard normalizedX <= progress + 0.05 else { continue }

                        // Droplet merging: as progress approaches a droplet, it grows and merges
                        let distToEdge = progress - normalizedX
                        let mergeAmount = min(max(distToEdge / 0.15, 0), 1.0)

                        // Phase-based wobble
                        let wobble = sin(phase * .pi * 2 + CGFloat(i) * 0.8) * 0.15
                        let radius = (barHeight * 0.5) * (0.4 + mergeAmount * 0.6 + wobble * mergeAmount)

                        let center = CGPoint(x: baseX, y: size.height / 2)
                        let dropletRect = CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )

                        let dropletPath = Circle().path(in: dropletRect)

                        let opacity = min(mergeAmount * 1.5, 1.0)
                        context.opacity = opacity
                        context.fill(
                            dropletPath,
                            with: .color(PSColors.primaryGreen)
                        )
                    }

                    // Smooth fill overlay
                    if progress > 0.05 {
                        let fillRect = CGRect(x: 0, y: 0, width: filledWidth, height: size.height)
                        let fillPath = Capsule().path(in: fillRect)
                        context.opacity = 0.85
                        context.fill(fillPath, with: .color(PSColors.primaryGreen))
                    }
                }
                .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Splash Transition Modifier
// Applies the matched geometry + spring unfold from splash → dashboard

struct SplashTransitionModifier: ViewModifier {
    let isTransitioning: Bool
    let splashNamespace: Namespace.ID

    func body(content: Content) -> some View {
        content
            .scaleEffect(isTransitioning ? 0.92 : 1.0)
            .opacity(isTransitioning ? 0 : 1)
            .animation(
                .spring(
                    Spring(mass: 1.0, stiffness: 120, damping: 20)
                ),
                value: isTransitioning
            )
    }
}

extension View {
    func splashTransition(isTransitioning: Bool, namespace: Namespace.ID) -> some View {
        modifier(SplashTransitionModifier(isTransitioning: isTransitioning, splashNamespace: namespace))
    }
}
