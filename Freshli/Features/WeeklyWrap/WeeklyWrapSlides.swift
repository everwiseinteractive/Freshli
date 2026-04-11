import SwiftUI

// MARK: - Animation Choreography
//
// Each slide is built around a single `Task` that sequences its entrance
// animations with `Task.sleep`, rather than chains of
// `DispatchQueue.main.asyncAfter`. Counters rely on
// `withAnimation` + `.contentTransition(.numericText())` — SwiftUI
// interpolates Int values smoothly on its own, so there is no need for a
// 70-step manual tick loop. Haptic ticks are driven by a second, shorter
// `Task` that sleeps in fixed increments while the visual animation runs.

// MARK: - Slide 1: The Big Number

struct BigNumberSlide: View {
    let viewModel: WeeklyWrapViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayedCount: Int = 0
    @State private var showSubtitle = false
    @State private var countFinished = false

    private let countDuration: Duration = .seconds(1.8)

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Week label
            Text("THIS WEEK")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(3)
                .opacity(showSubtitle ? 1 : 0)

            // The Big Number — with a keyframe-driven bounce pop at the end
            VStack(spacing: PSSpacing.lg) {
                Text("\(displayedCount)")
                    .font(.system(size: 120, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .keyframeAnimator(
                        initialValue: NumberPopState(),
                        trigger: countFinished
                    ) { content, state in
                        content
                            .scaleEffect(state.scale)
                            .shadow(
                                color: PSColors.primaryGreen.opacity(state.glow),
                                radius: 40 * state.glow,
                                y: 0
                            )
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            CubicKeyframe(0.95, duration: 0.0)
                            SpringKeyframe(1.12, duration: 0.35, spring: .bouncy)
                            SpringKeyframe(1.00, duration: 0.45, spring: .smooth)
                        }
                        KeyframeTrack(\.glow) {
                            LinearKeyframe(0.0, duration: 0.0)
                            LinearKeyframe(0.8, duration: 0.25)
                            LinearKeyframe(0.0, duration: 0.75)
                        }
                    }

                Text("items saved")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 10)
            }

            // Week range pill
            if showSubtitle {
                Text(viewModel.wrapData.weekDisplayRange)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.vertical, PSSpacing.sm)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                    .transition(PSMotion.fadeSlide)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .task { await runEntrance() }
    }

    @MainActor
    private func runEntrance() async {
        let target = viewModel.wrapData.totalItemsImpacted

        // Subtitle reveal first — gives the hero number something to land over.
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(PSMotion.springGentle) { showSubtitle = true }

        guard target > 0 else {
            countFinished = true
            return
        }

        // Kick off the counter (SwiftUI interpolates Int via contentTransition)
        // and a parallel haptic-tick loop that fires every 250ms for the
        // duration of the count, so the user feels the digits climbing.
        async let _: Void = tickHaptics(duration: countDuration)
        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 1.8)) {
            displayedCount = target
        }

        // Wait for the number to land, then fire the keyframe pop + success haptic.
        try? await Task.sleep(for: countDuration)
        countFinished = true
        PSHaptics.shared.success()
    }

    private func tickHaptics(duration: Duration) async {
        guard !reduceMotion else { return }
        let tickInterval: Duration = .milliseconds(250)
        let ticks = Int(duration / tickInterval)
        for _ in 0..<ticks {
            try? await Task.sleep(for: tickInterval)
            PSHaptics.shared.tick()
        }
    }
}

/// State the number-pop keyframe animator drives. Two tracks: the scale
/// bounce and a glow pulse that fades in and out as the count lands.
private struct NumberPopState {
    var scale: CGFloat = 1.0
    var glow: Double = 0.0
}

// MARK: - Slide 2: Community Hero

struct CommunityHeroSlide: View {
    let viewModel: WeeklyWrapViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showContent = false
    @State private var displayedPeople: Int = 0
    @State private var heartAppeared = false
    @State private var ringsExpanded = false

    private var peopleHelped: Int {
        viewModel.wrapData.itemsShared + viewModel.wrapData.itemsDonated
    }

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Heart icon with rings. Rings use PhaseAnimator for a
            // living breathe-in / breathe-out pulse instead of a linear
            // repeatForever; gives the hero graphic a gentle, organic life.
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(
                            width: ringsExpanded ? CGFloat(100 + i * 40) : 40,
                            height: ringsExpanded ? CGFloat(100 + i * 40) : 40
                        )
                        .animation(
                            .easeOut(duration: 1.2).delay(Double(i) * 0.15),
                            value: ringsExpanded
                        )
                }

                Image(systemName: "heart.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .phaseAnimator([false, true], trigger: heartAppeared) { content, phase in
                        content
                            .scaleEffect(heartAppeared ? (phase ? 1.04 : 1.0) : 0.3)
                            .opacity(heartAppeared ? 1.0 : 0.0)
                    } animation: { phase in
                        if !heartAppeared {
                            return .spring(response: 0.5, dampingFraction: 0.6)
                        }
                        return .easeInOut(duration: 1.6)
                    }
            }

            // Stats
            VStack(spacing: PSSpacing.xl) {
                Text("\(displayedPeople)")
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())

                Text("meals shared with\nyour community")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 12)
            }

            Spacer()

            // Breakdown pills
            if showContent {
                HStack(spacing: PSSpacing.md) {
                    CommunityStatPill(
                        icon: "gift.fill",
                        value: "\(viewModel.wrapData.itemsDonated)",
                        label: "Donated"
                    )
                    CommunityStatPill(
                        icon: "person.2.fill",
                        value: "\(viewModel.wrapData.itemsShared)",
                        label: "Shared"
                    )
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .transition(PSMotion.slideUp)
            }

            Spacer()
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .task { await runEntrance() }
    }

    @MainActor
    private func runEntrance() async {
        // Heart pop-in and rings expand together
        heartAppeared = true
        ringsExpanded = true

        // Content reveal after the heart lands
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(PSMotion.springGentle) { showContent = true }

        // Wait for stats to fade in before kicking off the counter
        try? await Task.sleep(for: .milliseconds(100))

        guard peopleHelped > 0 else { return }

        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 1.5)) {
            displayedPeople = peopleHelped
        }

        try? await Task.sleep(for: .milliseconds(1_500))
        PSHaptics.shared.success()
    }
}

private struct CommunityStatPill: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(PSSpacing.lg)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }
}

// MARK: - Slide 3: Environmental Impact (3D Growing Tree)

struct EnvironmentalImpactSlide: View {
    let viewModel: WeeklyWrapViewModel
    let onShare: () -> Void
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var treeGrowth: CGFloat = 0
    @State private var treeBounce = false
    @State private var showStats = false
    @State private var showActions = false
    @State private var leafSway: Double = 0

    private var co2Saved: Double { viewModel.wrapData.co2Avoided }
    // Normalize growth: 0kg = 0, 50kg+ = full tree
    private var growthFactor: CGFloat { min(CGFloat(co2Saved) / 50.0, 1.0) }

    var body: some View {
        VStack(spacing: PSSpacing.xl) {
            Spacer()

            // 3D Tree
            treeView
                .frame(height: PSLayout.scaled(280))

            // CO2 stat
            if showStats {
                VStack(spacing: PSSpacing.md) {
                    Text(viewModel.wrapData.co2AvoidedDisplay + " kg")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("CO\u{2082} kept out of\nthe atmosphere")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    // Tree equivalence
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(PSColors.primaryGreen)
                        Text("Equal to \(viewModel.wrapData.treesEquivalent) tree\(viewModel.wrapData.treesEquivalent == 1 ? "" : "s") planted")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, PSSpacing.xs)
                }
                .transition(PSMotion.fadeSlide)
            }

            Spacer()

            // Share + Done actions
            if showActions {
                VStack(spacing: PSSpacing.md) {
                    Button(action: onShare) {
                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share to Stories")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                    }
                    .pressable()

                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .transition(PSMotion.slideUp)
            }

            Spacer()
                .frame(height: PSSpacing.xxxxl)
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .task { await runEntrance() }
    }

    // MARK: - 3D Tree
    //
    // `keyframeAnimator` drives the entire tree growth as a single
    // choreographed sequence: the trunk shoots up with overshoot, canopy
    // layers stagger in, and the whole tree settles with a micro-bounce
    // at the end. Previously this was an ad-hoc `withAnimation` + two
    // `DispatchQueue.main.asyncAfter` chains; now it's one declarative
    // animation that SwiftUI can scrub, reverse, or interrupt cleanly.

    private var treeView: some View {
        ZStack {
            // Ground shadow
            Ellipse()
                .fill(Color.white.opacity(0.08))
                .frame(width: 120 * treeGrowth, height: 20 * treeGrowth)
                .offset(y: 120)

            // Trunk with 3D perspective
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x8B6914), Color(hex: 0x5D4408)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 18 * treeGrowth, height: 80 * treeGrowth)
                .offset(y: 80 - 80 * treeGrowth)
                .rotation3DEffect(
                    .degrees(Double(treeGrowth) * 5),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )

            // Canopy layers (3D transforms for depth)
            ForEach(0..<3, id: \.self) { layer in
                let layerSize = CGFloat(90 - layer * 15) * treeGrowth
                let yOffset = CGFloat(-20 - layer * 35) * treeGrowth

                canopyLayer(size: layerSize, layerIndex: layer)
                    .offset(y: yOffset)
                    .rotation3DEffect(
                        .degrees(leafSway * (layer == 1 ? -1 : 1)),
                        axis: (x: 0.1, y: 1, z: 0),
                        perspective: 0.4
                    )
                    .opacity(treeGrowth > CGFloat(layer) * 0.3 ? 1 : 0)
            }

            // Floating leaves (particles)
            if treeGrowth > 0.8 {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: CGFloat.random(in: 8...14)))
                        .foregroundColor(leafColor(for: i).opacity(0.6))
                        .offset(
                            x: CGFloat.random(in: -60...60),
                            y: CGFloat.random(in: -100...40)
                        )
                        .rotationEffect(.degrees(leafSway * 3 + Double(i * 30)))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .keyframeAnimator(
            initialValue: TreePopState(),
            trigger: treeBounce
        ) { content, state in
            content
                .scaleEffect(x: state.squashX, y: state.squashY, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.squashX) {
                CubicKeyframe(1.0, duration: 0.0)
                CubicKeyframe(1.08, duration: 0.18)  // squish wide
                CubicKeyframe(0.96, duration: 0.18)  // snap narrow
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.squashY) {
                CubicKeyframe(1.0, duration: 0.0)
                CubicKeyframe(0.94, duration: 0.18)  // squish short
                CubicKeyframe(1.04, duration: 0.18)  // stretch tall
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
        }
    }

    private func canopyLayer(size: CGFloat, layerIndex: Int) -> some View {
        ZStack {
            // Main canopy shape
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            canopyColor(for: layerIndex),
                            canopyColor(for: layerIndex).opacity(0.7)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size, height: size * 0.85)

            // Highlight for 3D effect
            Ellipse()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.2),
                            Color.clear
                        ]),
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
                .frame(width: size * 0.7, height: size * 0.6)
                .offset(x: -size * 0.1, y: -size * 0.1)
        }
    }

    private func canopyColor(for layer: Int) -> Color {
        let colors: [Color] = [
            Color(hex: 0x22C55E), // bright green
            Color(hex: 0x16A34A), // medium green
            Color(hex: 0x15803D)  // dark green
        ]
        return colors[min(layer, colors.count - 1)]
    }

    private func leafColor(for index: Int) -> Color {
        let colors: [Color] = [
            PSColors.primaryGreen,
            Color(hex: 0x4ADE80),
            PSColors.accentTeal,
            Color(hex: 0x86EFAC),
            Color(hex: 0xFBBF24)
        ]
        return colors[index % colors.count]
    }

    // MARK: - Animation

    @MainActor
    private func runEntrance() async {
        // Grow tree with spring
        withAnimation(reduceMotion ? .linear(duration: 0.3) : .spring(response: 1.8, dampingFraction: 0.65)) {
            treeGrowth = max(0.3, growthFactor)
        }

        // Gentle leaf sway — continuous forever
        if !reduceMotion {
            withAnimation(
                .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
            ) {
                leafSway = 8
            }
        }

        // Wait for the growth spring to settle, then trigger the bounce.
        try? await Task.sleep(for: .milliseconds(1_200))
        treeBounce.toggle()  // fires the keyframeAnimator
        PSHaptics.shared.mediumTap()

        // Reveal the stats number block
        withAnimation(PSMotion.springGentle) { showStats = true }

        // Finally reveal share + done actions
        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(PSMotion.springDefault) { showActions = true }
    }
}

/// State driving the squash-and-stretch landing of the grown tree.
private struct TreePopState {
    var squashX: CGFloat = 1.0
    var squashY: CGFloat = 1.0
}

// MARK: - Preview

#Preview("Big Number") {
    ZStack {
        Color.black.ignoresSafeArea()
        BigNumberSlide(viewModel: .preview)
    }
}

#Preview("Community Hero") {
    ZStack {
        Color.black.ignoresSafeArea()
        CommunityHeroSlide(viewModel: .preview)
    }
}

#Preview("Environmental Impact") {
    ZStack {
        Color.black.ignoresSafeArea()
        EnvironmentalImpactSlide(
            viewModel: .preview,
            onShare: {},
            onDone: {}
        )
    }
}
