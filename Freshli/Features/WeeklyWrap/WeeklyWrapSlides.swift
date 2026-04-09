import SwiftUI

// MARK: - Slide 1: The Big Number

struct BigNumberSlide: View {
    let viewModel: WeeklyWrapViewModel
    @State private var displayedCount: Int = 0
    @State private var showSubtitle = false
    @State private var countFinished = false

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Week label
            Text("THIS WEEK")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(3)
                .opacity(showSubtitle ? 1 : 0)

            // The Big Number
            VStack(spacing: PSSpacing.lg) {
                Text("\(displayedCount)")
                    .font(.system(size: 120, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                    .scaleEffect(countFinished ? 1.0 : 0.95)

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
        .onAppear {
            animateCountUp()
        }
    }

    private func animateCountUp() {
        let target = viewModel.wrapData.totalItemsImpacted
        let duration: Double = 1.8
        let steps = 70

        guard target > 0 else {
            displayedCount = 0
            showSubtitle = true
            countFinished = true
            return
        }

        // Show subtitle after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(PSMotion.springGentle) {
                showSubtitle = true
            }
        }

        // Counting animation with easing (slow start, fast middle, slow end)
        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            // Ease-out cubic for satisfying deceleration
            let eased = 1.0 - pow(1.0 - progress, 3)
            let delay = duration * progress

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.03)) {
                    displayedCount = Int(Double(target) * eased)
                }
                // Tick haptic every ~10 steps
                if step % 7 == 0 {
                    PSHaptics.shared.tick()
                }
            }
        }

        // Ensure final value is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            displayedCount = target
            withAnimation(PSMotion.springBouncy) {
                countFinished = true
            }
            PSHaptics.shared.success()
        }
    }
}

// MARK: - Slide 2: Community Hero

struct CommunityHeroSlide: View {
    let viewModel: WeeklyWrapViewModel
    @State private var showContent = false
    @State private var displayedPeople: Int = 0
    @State private var heartScale: CGFloat = 0.3
    @State private var heartOpacity: Double = 0

    private var peopleHelped: Int {
        viewModel.wrapData.itemsShared + viewModel.wrapData.itemsDonated
    }

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Heart icon with pulse
            ZStack {
                // Pulsing rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.15 - Double(i) * 0.04), lineWidth: 2)
                        .frame(
                            width: showContent ? CGFloat(100 + i * 40) : 40,
                            height: showContent ? CGFloat(100 + i * 40) : 40
                        )
                        .animation(
                            .easeOut(duration: 1.2)
                            .delay(Double(i) * 0.15),
                            value: showContent
                        )
                }

                Image(systemName: "heart.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(heartScale)
                    .opacity(heartOpacity)
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
        .onAppear {
            animateEntrance()
        }
    }

    private func animateEntrance() {
        // Heart entrance
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            heartScale = 1.0
            heartOpacity = 1.0
        }

        // Content reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(PSMotion.springGentle) {
                showContent = true
            }
        }

        // Count up people helped
        let target = peopleHelped
        let duration: Double = 1.5
        let steps = 50

        guard target > 0 else {
            displayedPeople = 0
            return
        }

        for step in 0...steps {
            let progress = Double(step) / Double(steps)
            let eased = 1.0 - pow(1.0 - progress, 3)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + duration * progress) {
                withAnimation(.linear(duration: 0.03)) {
                    displayedPeople = Int(Double(target) * eased)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + duration) {
            displayedPeople = target
            PSHaptics.shared.success()
        }
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

    @State private var treeGrowth: CGFloat = 0
    @State private var showStats = false
    @State private var showActions = false
    @State private var leafRotation: Double = 0

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
        .onAppear {
            animateTree()
        }
    }

    // MARK: - 3D Tree

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
                        .degrees(leafRotation * (layer == 1 ? -1 : 1)),
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
                        .rotationEffect(.degrees(leafRotation * 3 + Double(i * 30)))
                        .transition(.scale.combined(with: .opacity))
                }
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

    private func animateTree() {
        // Grow tree with spring
        withAnimation(.spring(response: 1.8, dampingFraction: 0.65)) {
            treeGrowth = max(0.3, growthFactor)
        }

        // Gentle leaf sway
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            leafRotation = 8
        }

        // Show stats after tree grows
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(PSMotion.springGentle) {
                showStats = true
            }
            PSHaptics.shared.mediumTap()
        }

        // Show action buttons
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(PSMotion.springDefault) {
                showActions = true
            }
        }
    }
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
