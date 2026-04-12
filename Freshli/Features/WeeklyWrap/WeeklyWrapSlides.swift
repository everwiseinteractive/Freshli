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

    // MARK: - Realistic Animated Tree
    //
    // A Canvas-drawn tree with: curved tapered trunk, visible branches,
    // organic multi-blob canopy (overlapping circles in varying greens),
    // grass tufts at the base, floating/falling leaf particles, and
    // continuous wind-driven sway. Replaces the old geometric ellipse tree.
    //
    // The tree grows from 0 → growthFactor as the slide enters, then
    // lands with the KeyframeAnimator squash-stretch. After landing, the
    // canopy sways gently, leaves drift downward, and light bokeh circles
    // float through the canopy.

    private var treeView: some View {
        TimelineView(reduceMotion ? .animation(minimumInterval: 1.0) : .animation) { context in
            let t = context.date.timeIntervalSince1970
            Canvas { ctx, size in
                let cx = size.width / 2
                let ground = size.height * 0.82
                let g = treeGrowth // 0→1 growth factor
                let wind = reduceMotion ? 0.0 : sin(t * 1.2) * 3.0 // subtle trunk sway

                // ── Ground shadow ──────────────────────────────────
                let shadowW = 130.0 * g
                let shadowH = 16.0 * g
                let shadowRect = CGRect(
                    x: cx - shadowW / 2,
                    y: ground - shadowH / 2 + 8,
                    width: shadowW,
                    height: shadowH
                )
                ctx.fill(
                    Path(ellipseIn: shadowRect),
                    with: .color(.white.opacity(0.06 * g))
                )

                // ── Grass tufts ────────────────────────────────────
                drawGrass(ctx: &ctx, cx: cx, ground: ground, g: g, t: t)

                // ── Trunk (curved bezier, tapered) ─────────────────
                let trunkBase = CGPoint(x: cx, y: ground)
                let trunkTop = CGPoint(
                    x: cx + wind * g,
                    y: ground - 90 * g
                )
                drawTrunk(ctx: &ctx, base: trunkBase, top: trunkTop, g: g)

                // ── Branches ───────────────────────────────────────
                drawBranches(ctx: &ctx, trunkTop: trunkTop, g: g, wind: wind, t: t)

                // ── Canopy (organic multi-blob) ────────────────────
                drawCanopy(ctx: &ctx, cx: cx, trunkTopY: trunkTop.y, g: g, wind: wind, t: t)

                // ── Falling leaves ─────────────────────────────────
                if g > 0.7 && !reduceMotion {
                    drawFallingLeaves(ctx: &ctx, cx: cx, ground: ground, g: g, t: t)
                }

                // ── Light bokeh ────────────────────────────────────
                if g > 0.8 && !reduceMotion {
                    drawBokeh(ctx: &ctx, cx: cx, trunkTopY: trunkTop.y, g: g, t: t)
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
                CubicKeyframe(1.06, duration: 0.18)
                CubicKeyframe(0.97, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.squashY) {
                CubicKeyframe(1.0, duration: 0.0)
                CubicKeyframe(0.95, duration: 0.18)
                CubicKeyframe(1.03, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
            }
        }
    }

    // MARK: - Tree Drawing Helpers

    /// Curved, tapered trunk using a quad-bezier outline
    private func drawTrunk(ctx: inout GraphicsContext, base: CGPoint, top: CGPoint, g: CGFloat) {
        let baseW: CGFloat = 14 * g
        let topW: CGFloat = 6 * g
        let controlOffset = (top.x - base.x) * 0.6

        var path = Path()
        // Left edge
        path.move(to: CGPoint(x: base.x - baseW / 2, y: base.y))
        path.addQuadCurve(
            to: CGPoint(x: top.x - topW / 2, y: top.y),
            control: CGPoint(x: base.x - baseW / 2 + controlOffset, y: (base.y + top.y) / 2)
        )
        // Top edge
        path.addLine(to: CGPoint(x: top.x + topW / 2, y: top.y))
        // Right edge
        path.addQuadCurve(
            to: CGPoint(x: base.x + baseW / 2, y: base.y),
            control: CGPoint(x: base.x + baseW / 2 + controlOffset, y: (base.y + top.y) / 2)
        )
        path.closeSubpath()

        // Bark gradient: dark brown on left → warm brown on right
        ctx.fill(path, with: .linearGradient(
            Gradient(colors: [Color(hex: 0x5D4408), Color(hex: 0x8B6914), Color(hex: 0x6B5210)]),
            startPoint: CGPoint(x: base.x - baseW, y: base.y),
            endPoint: CGPoint(x: base.x + baseW, y: base.y)
        ))

        // Bark texture lines
        for i in stride(from: 0.2, through: 0.8, by: 0.2) {
            let y = base.y + (top.y - base.y) * i
            let w = baseW + (topW - baseW) * i
            let xCenter = base.x + (top.x - base.x) * i
            var line = Path()
            line.move(to: CGPoint(x: xCenter - w * 0.3, y: y))
            line.addLine(to: CGPoint(x: xCenter + w * 0.15, y: y - 3))
            ctx.stroke(line, with: .color(Color(hex: 0x3D2A06).opacity(0.3 * g)), lineWidth: 0.5)
        }
    }

    /// Two visible branches forking from near the trunk top
    private func drawBranches(ctx: inout GraphicsContext, trunkTop: CGPoint, g: CGFloat, wind: Double, t: Double) {
        let branches: [(dx: CGFloat, dy: CGFloat, len: CGFloat, angle: CGFloat)] = [
            (dx: -28, dy: -20, len: 35, angle: -0.5),
            (dx:  22, dy: -25, len: 30, angle:  0.4),
            (dx: -15, dy: -40, len: 25, angle: -0.3),
        ]

        for (i, branch) in branches.enumerated() {
            guard g > 0.4 + CGFloat(i) * 0.15 else { continue }
            let branchWind = sin(t * (1.0 + Double(i) * 0.3)) * 2.0
            let start = CGPoint(
                x: trunkTop.x + branch.dx * g * 0.5,
                y: trunkTop.y + 15 - CGFloat(i) * 10
            )
            let end = CGPoint(
                x: trunkTop.x + branch.dx * g + CGFloat(branchWind) * g,
                y: trunkTop.y + branch.dy * g
            )

            var path = Path()
            path.move(to: start)
            path.addQuadCurve(
                to: end,
                control: CGPoint(
                    x: (start.x + end.x) / 2 + branch.angle * 10,
                    y: (start.y + end.y) / 2 - 5
                )
            )
            ctx.stroke(
                path,
                with: .color(Color(hex: 0x6B5210).opacity(Double(g))),
                lineWidth: (3.0 - CGFloat(i) * 0.5) * g
            )
        }
    }

    /// Organic canopy: 9 overlapping circles with varying greens, positions,
    /// and sizes. Each circle sways independently with the wind for a
    /// natural, breathing crown shape.
    private func drawCanopy(ctx: inout GraphicsContext, cx: CGFloat, trunkTopY: CGFloat, g: CGFloat, wind: Double, t: Double) {
        let blobs: [(dx: CGFloat, dy: CGFloat, r: CGFloat, color: Color, phase: Double)] = [
            // Back layer (darker, larger)
            (dx:  -5, dy: -50, r: 52, color: Color(hex: 0x15803D), phase: 0.7),
            (dx:  20, dy: -45, r: 44, color: Color(hex: 0x166534), phase: 1.1),
            (dx: -22, dy: -55, r: 40, color: Color(hex: 0x14532D), phase: 0.5),
            // Mid layer (medium green)
            (dx:   0, dy: -70, r: 48, color: Color(hex: 0x16A34A), phase: 0.9),
            (dx:  25, dy: -65, r: 38, color: Color(hex: 0x22C55E), phase: 1.3),
            (dx: -25, dy: -68, r: 36, color: Color(hex: 0x15803D), phase: 0.6),
            // Front layer (brightest, smaller)
            (dx:   8, dy: -82, r: 35, color: Color(hex: 0x4ADE80), phase: 1.0),
            (dx: -12, dy: -78, r: 30, color: Color(hex: 0x22C55E), phase: 0.8),
            (dx:   0, dy: -90, r: 28, color: Color(hex: 0x86EFAC).opacity(0.7), phase: 1.2),
        ]

        for blob in blobs {
            let blobWind = sin(t * blob.phase) * 4.0
            let x = cx + blob.dx * g + CGFloat(blobWind + wind * 0.5) * g
            let y = trunkTopY + blob.dy * g
            let r = blob.r * g

            guard r > 2 else { continue }

            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 1.7)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [blob.color, blob.color.opacity(0.3)]),
                    center: CGPoint(x: x - r * 0.15, y: y - r * 0.2),
                    startRadius: 0,
                    endRadius: r
                )
            )
        }

        // Highlight shimmer on the canopy (sunlight)
        if g > 0.6 {
            let shimmerX = cx + CGFloat(sin(t * 0.7)) * 15 * g
            let shimmerY = trunkTopY - 70 * g
            let shimmerR = 20.0 * g
            ctx.fill(
                Path(ellipseIn: CGRect(x: shimmerX - shimmerR, y: shimmerY - shimmerR,
                                       width: shimmerR * 2, height: shimmerR * 1.5)),
                with: .color(.white.opacity(0.08 * Double(g)))
            )
        }
    }

    /// Small grass tufts at the base of the tree
    private func drawGrass(ctx: inout GraphicsContext, cx: CGFloat, ground: CGFloat, g: CGFloat, t: Double) {
        let grassColors: [Color] = [Color(hex: 0x22C55E), Color(hex: 0x16A34A), Color(hex: 0x4ADE80)]
        let positions: [CGFloat] = [-50, -35, -20, -8, 5, 18, 30, 42]

        for (i, xOff) in positions.enumerated() {
            let grassWind = sin(t * 1.5 + Double(i) * 0.7) * 2.0
            let h: CGFloat = CGFloat([12, 16, 10, 14, 11, 15, 9, 13][i]) * g
            let baseX = cx + xOff * g
            let tipX = baseX + CGFloat(grassWind) * g

            var blade = Path()
            blade.move(to: CGPoint(x: baseX - 1, y: ground))
            blade.addQuadCurve(
                to: CGPoint(x: tipX, y: ground - h),
                control: CGPoint(x: baseX + CGFloat(grassWind * 0.5), y: ground - h * 0.6)
            )
            blade.addLine(to: CGPoint(x: baseX + 1, y: ground))
            ctx.fill(blade, with: .color(grassColors[i % grassColors.count].opacity(0.6 * Double(g))))
        }
    }

    /// Leaf particles that drift and fall from the canopy
    private func drawFallingLeaves(ctx: inout GraphicsContext, cx: CGFloat, ground: CGFloat, g: CGFloat, t: Double) {
        let leafColors: [Color] = [PSColors.primaryGreen, Color(hex: 0x4ADE80),
                                    Color(hex: 0x86EFAC), Color(hex: 0xFBBF24)]

        for i in 0..<6 {
            let seed = Double(i) * 137.508 // golden angle for distribution
            let cycle = (t * 0.3 + seed).truncatingRemainder(dividingBy: 4.0) / 4.0
            let leafX = cx + CGFloat(sin(t * 0.8 + seed) * 50 + cos(seed) * 20) * g
            let leafY = (ground - 150 * g) + CGFloat(cycle) * 160 * g
            let rot = t * 2.0 + seed
            let size: CGFloat = CGFloat(4 + (i % 3) * 2) * g
            let opacity = (1.0 - cycle) * 0.5 * Double(g)

            guard opacity > 0.05 else { continue }

            ctx.drawLayer { inner in
                inner.translateBy(x: leafX, y: leafY)
                inner.rotate(by: .radians(rot))
                let leafPath = Path(ellipseIn: CGRect(x: -size / 2, y: -size / 4, width: size, height: size / 2))
                inner.fill(leafPath, with: .color(leafColors[i % leafColors.count].opacity(opacity)))
            }
        }
    }

    /// Soft bokeh light circles drifting through the canopy
    private func drawBokeh(ctx: inout GraphicsContext, cx: CGFloat, trunkTopY: CGFloat, g: CGFloat, t: Double) {
        for i in 0..<4 {
            let seed = Double(i) * 97.0
            let x = cx + CGFloat(sin(t * 0.4 + seed) * 40) * g
            let y = trunkTopY + CGFloat(cos(t * 0.3 + seed) * 30 - 50) * g
            let r = CGFloat(3 + i * 2) * g
            let alpha = (sin(t * 0.6 + seed) * 0.5 + 0.5) * 0.12 * Double(g)

            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(alpha))
            )
        }
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
