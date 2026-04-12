import SwiftUI

// MARK: - Animation Choreography
//
// Each slide is built around a single `Task` that sequences its entrance
// animations with `Task.sleep`. Counters rely on `withAnimation` +
// `.contentTransition(.numericText())` for smooth digit interpolation.
// Haptic ticks are driven by a parallel `Task` during count-up.
//
// Visual revamp adds: SymbolEffect(.breathe, .wiggle, .bounce) on
// SF Symbols, streak/WoW data overlays, and category mini-bars.
// All gated on accessibilityReduceMotion.

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

            // Streak flame badge — only if the user has an active streak
            if viewModel.hasStreak && showSubtitle {
                HStack(spacing: PSSpacing.xxs) {
                    Image(systemName: "flame.fill")
                        .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion && showSubtitle)
                        .font(.system(size: 16))
                        .foregroundColor(PSColors.secondaryAmber)

                    Text("\(viewModel.wrapData.currentStreak)-day streak")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .transition(PSMotion.fadeSlide)
            }

            // Week label
            Text("THIS WEEK")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(3)
                .opacity(showSubtitle ? 1 : 0)

            // The Big Number — keyframe-driven bounce pop at the end
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

            // Week-over-week comparison
            if showSubtitle && viewModel.wrapData.weekOverWeekChange != 0 {
                HStack(spacing: PSSpacing.xs) {
                    Image(systemName: viewModel.weekOverWeekArrow)
                        .symbolEffect(.wiggle, value: countFinished)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(viewModel.weekOverWeekIsPositive
                                         ? PSColors.primaryGreen
                                         : PSColors.expiredRed)

                    Text(viewModel.wrapData.weekOverWeekLabel)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
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

        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(PSMotion.springGentle) { showSubtitle = true }

        guard target > 0 else {
            countFinished = true
            return
        }

        async let _: Void = tickHaptics(duration: countDuration)
        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 1.8)) {
            displayedCount = target
        }

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

private struct NumberPopState {
    var scale: CGFloat = 1.0
    var glow: Double = 0.0
}

// MARK: - Slide 2: Community Hero

struct CommunityHeroSlide: View {
    let viewModel: WeeklyWrapViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showContent = false
    @State private var showInsight = false
    @State private var displayedPeople: Int = 0
    @State private var heartAppeared = false
    @State private var ringsExpanded = false

    private var peopleHelped: Int {
        viewModel.wrapData.itemsShared + viewModel.wrapData.itemsDonated
    }

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Heart icon with expanding rings
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
                    .scaleEffect(heartAppeared ? 1.0 : 0.3)
                    .opacity(heartAppeared ? 1.0 : 0.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: heartAppeared)
                    // Native SymbolEffect breathing replaces the manual PhaseAnimator
                    .symbolEffect(.breathe, options: .repeating, isActive: !reduceMotion && heartAppeared)
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

            // Best day insight
            if showInsight {
                HStack(spacing: PSSpacing.sm) {
                    Image(systemName: "calendar.badge.checkmark")
                        .symbolEffect(.bounce, value: showInsight)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(PSColors.secondaryAmber)

                    Text("Your best day: \(viewModel.wrapData.bestDayOfWeek)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, PSSpacing.lg)
                .padding(.vertical, PSSpacing.sm)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .transition(PSMotion.fadeSlide)
            }

            Spacer()
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .task { await runEntrance() }
    }

    @MainActor
    private func runEntrance() async {
        heartAppeared = true
        ringsExpanded = true

        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(PSMotion.springGentle) { showContent = true }

        try? await Task.sleep(for: .milliseconds(100))

        guard peopleHelped > 0 else { return }

        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 1.5)) {
            displayedPeople = peopleHelped
        }

        try? await Task.sleep(for: .milliseconds(1_500))
        PSHaptics.shared.success()

        // Stagger the insight pill after the count lands
        try? await Task.sleep(for: .milliseconds(300))
        withAnimation(PSMotion.springGentle) { showInsight = true }
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
    private var growthFactor: CGFloat { min(CGFloat(co2Saved) / 50.0, 1.0) }

    var body: some View {
        VStack(spacing: PSSpacing.xl) {
            Spacer()

            // 3D Tree
            treeView
                .frame(height: PSLayout.scaled(260))

            // CO2 stat + money + categories
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
                    .padding(.top, PSSpacing.xxs)

                    // Money saved callout
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "dollarsign.circle.fill")
                            .symbolEffect(.bounce, value: showStats)
                            .foregroundColor(PSColors.secondaryAmber)
                        Text("\(viewModel.wrapData.moneySavedDisplay) saved this week")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Category breakdown mini-bars
                    categoryBreakdown
                }
                .transition(PSMotion.fadeSlide)
            }

            Spacer()

            // Share + Done — pinned above the floating tab bar
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

            // Clear the floating tab bar pill (~60pt) + home indicator (14pt)
            // + visual breathing room so the Share button sits comfortably
            // above the tab bar on all device sizes.
            Spacer()
                .frame(height: PSLayout.scaled(120))
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
        .task { await runEntrance() }
    }

    // MARK: - Category Breakdown Mini-Bars

    private var categoryBreakdown: some View {
        VStack(spacing: PSSpacing.xs) {
            ForEach(Array(viewModel.categoryBreakdownTop3.enumerated()), id: \.offset) { index, item in
                HStack(spacing: PSSpacing.sm) {
                    Text(item.category.emoji)
                        .font(.system(size: 14))
                        .frame(width: 20)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(PSColors.categoryColor(for: item.category))
                            .frame(
                                width: showStats
                                    ? geo.size.width * CGFloat(item.count) / CGFloat(max(viewModel.wrapData.topCategoryCount, 1))
                                    : 0
                            )
                            .animation(
                                reduceMotion
                                    ? .linear(duration: 0.2)
                                    : .spring(response: 0.8, dampingFraction: 0.7).delay(Double(index) * 0.15),
                                value: showStats
                            )
                    }
                    .frame(height: 6)

                    Text("\(item.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, PSSpacing.xxxl)
        .padding(.top, PSSpacing.md)
    }

    // MARK: - 3D Tree (unchanged structure, SymbolEffect on leaves)

    private var treeView: some View {
        ZStack {
            Ellipse()
                .fill(Color.white.opacity(0.08))
                .frame(width: 120 * treeGrowth, height: 20 * treeGrowth)
                .offset(y: 120)

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

            // Floating leaves with native SymbolEffect rotation
            if treeGrowth > 0.8 {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: "leaf.fill")
                        .font(.system(size: CGFloat.random(in: 8...14)))
                        .foregroundColor(leafColor(for: i).opacity(0.6))
                        .symbolEffect(.rotate, options: .repeating, isActive: !reduceMotion)
                        .offset(
                            x: CGFloat.random(in: -60...60),
                            y: CGFloat.random(in: -100...40)
                        )
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
                CubicKeyframe(1.08, duration: 0.18)
                CubicKeyframe(0.96, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.squashY) {
                CubicKeyframe(1.0, duration: 0.0)
                CubicKeyframe(0.94, duration: 0.18)
                CubicKeyframe(1.04, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
        }
    }

    private func canopyLayer(size: CGFloat, layerIndex: Int) -> some View {
        ZStack {
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
        [Color(hex: 0x22C55E), Color(hex: 0x16A34A), Color(hex: 0x15803D)][min(layer, 2)]
    }

    private func leafColor(for index: Int) -> Color {
        [PSColors.primaryGreen, Color(hex: 0x4ADE80), PSColors.accentTeal,
         Color(hex: 0x86EFAC), Color(hex: 0xFBBF24)][index % 5]
    }

    // MARK: - Animation

    @MainActor
    private func runEntrance() async {
        withAnimation(reduceMotion ? .linear(duration: 0.3) : .spring(response: 1.8, dampingFraction: 0.65)) {
            treeGrowth = max(0.3, growthFactor)
        }

        if !reduceMotion {
            withAnimation(
                .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
            ) {
                leafSway = 8
            }
        }

        try? await Task.sleep(for: .milliseconds(1_200))
        treeBounce.toggle()
        PSHaptics.shared.mediumTap()

        withAnimation(PSMotion.springGentle) { showStats = true }

        try? await Task.sleep(for: .milliseconds(600))
        withAnimation(PSMotion.springDefault) { showActions = true }
    }
}

private struct TreePopState {
    var squashX: CGFloat = 1.0
    var squashY: CGFloat = 1.0
}

// MARK: - Previews

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
