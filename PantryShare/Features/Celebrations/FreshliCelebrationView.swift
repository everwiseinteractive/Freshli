import SwiftUI

// MARK: - Freshli Celebration View
// Unified full-screen celebration with Canvas confetti, matchedGeometryEffect
// transitions, spatial audio, and glassmorphism stat cards.
// Four celebration types: consumed (green), shared (teal/blue),
// milestone (gold burst), community claim (warm gradient).

struct FreshliCelebrationView: View {
    let type: CelebrationType
    let flavor: FreshliCelebrationFlavor
    let sourceID: String
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var burstTriggered = false
    @State private var particleEngine = FreshliParticleEngine()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FreshliExpandingCelebrationContainer(
            sourceID: sourceID,
            namespace: namespace,
            backgroundColor: type.backgroundColor,
            isPresented: true
        ) {
            ZStack {
                // Gradient background overlay for depth
                backgroundGradient

                // Canvas particle layer (120fps)
                FreshliParticleCanvas(
                    particles: particleEngine.particles,
                    flavor: flavor
                )

                // Burst ring effect at origin
                FreshliBurstOverlay(flavor: flavor, trigger: burstTriggered)

                // Main content
                celebrationContent
                    .dynamicIslandAware()
            }
        }
        .onAppear {
            triggerCelebration()
        }
        .onDisappear {
            particleEngine.stop()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            // Radial glow from center
            RadialGradient(
                colors: [
                    type.iconBackgroundColor.opacity(0.4),
                    type.backgroundColor.opacity(0.1),
                    .clear,
                ],
                center: .center,
                startRadius: 20,
                endRadius: UIScreen.main.bounds.width * 0.7
            )
            .ignoresSafeArea()
            .opacity(showContent ? 1 : 0)

            // Top-to-bottom gradient for depth
            LinearGradient(
                colors: [
                    .white.opacity(0.08),
                    .clear,
                    .black.opacity(0.15),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Content Layout

    private var celebrationContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: PSLayout.scaled(60))

            // Hero icon with glassmorphism container
            heroSection
                .padding(.bottom, PSLayout.scaled(36))

            // Title
            Text(type.title)
                .font(.system(size: PSLayout.scaledFont(36), weight: .black))
                .tracking(-0.5)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .padding(.bottom, PSLayout.scaled(12))

            // Subtitle
            Text(type.subtitle)
                .font(.system(size: PSLayout.scaledFont(17), weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .lineLimit(3)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 15)

            Spacer(minLength: PSLayout.scaled(20))

            // Glassmorphism stat card (for milestone/community)
            if shouldShowStatCard {
                glassStatCard
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                    .padding(.bottom, PSLayout.scaled(24))
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.85)
            }

            Spacer(minLength: PSLayout.scaled(16))

            // CTA Button
            if type.intensity != .small {
                ctaButton
                    .padding(.bottom, PSLayout.scaled(44))
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack {
            // Glassmorphism icon container
            RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                )
                .adaptiveFrame(width: 128, height: 128)
                .shadow(color: type.backgroundColor.opacity(0.4), radius: 30, y: 12)

            // Inner color fill
            RoundedRectangle(cornerRadius: PSSpacing.radiusHero - 4, style: .continuous)
                .fill(type.iconBackgroundColor.opacity(0.6))
                .adaptiveFrame(width: 120, height: 120)

            // Icon
            Image(systemName: type.icon)
                .font(.system(size: PSLayout.scaledFont(56), weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .scaleEffect(showContent ? 1 : 0.4)
        .opacity(showContent ? 1 : 0)
    }

    // MARK: - Glassmorphism Stat Card

    private var shouldShowStatCard: Bool {
        switch type {
        case .impactMilestone, .communityImpact, .weeklyRecap:
            return true
        default:
            return false
        }
    }

    private var glassStatCard: some View {
        VStack(spacing: PSSpacing.lg) {
            switch type {
            case .impactMilestone(_, let stat):
                statRow(icon: "star.fill", value: stat, label: String(localized: "Reached"))

            case .communityImpact(let items, let neighbors):
                HStack(spacing: PSSpacing.md) {
                    miniStat(icon: "shippingbox.fill", value: "\(items)", label: String(localized: "Items"))
                    miniStatDivider
                    miniStat(icon: "person.2.fill", value: "\(neighbors)", label: String(localized: "Neighbors"))
                }

            default:
                EmptyView()
            }
        }
        .padding(PSLayout.cardPadding)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    private func statRow(icon: String, value: String, label: String) -> some View {
        HStack(spacing: PSSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(type.pulseColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Spacer()
        }
    }

    private func miniStat(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(type.pulseColor)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private var miniStatDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(width: 1, height: 50)
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button(action: {
            PSHaptics.shared.mediumTap()
            withAnimation(PSMotion.springDefault) {
                onDismiss()
            }
        }) {
            Text(type.ctaLabel)
                .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                .foregroundStyle(type.ctaTextColor)
                .frame(maxWidth: .infinity)
                .frame(height: PSLayout.scaled(60))
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .shadow(color: type.ctaShadowColor, radius: 20, y: 8)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
    }

    // MARK: - Animation Sequence

    private func triggerCelebration() {
        if reduceMotion {
            showContent = true
            return
        }

        // 1. Haptic burst
        PSHaptics.shared.celebrate()

        // 2. Content reveal
        withAnimation(PSMotion.springBouncy.delay(0.1)) {
            showContent = true
        }

        // 3. Particle burst (slightly delayed for dramatic effect)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            burstTriggered = true

            let center = CGPoint(
                x: UIScreen.main.bounds.midX,
                y: UIScreen.main.bounds.height * 0.3
            )
            let size = UIScreen.main.bounds.size
            let count = type.intensity == .hero ? 60 : 35

            particleEngine.emit(
                count: count,
                flavor: flavor,
                from: center,
                in: size
            )

            // Spatial shimmer sound anchored toward the stat card area
            let normalizedX = 0.5 // centered
            FreshliCelebrationAudio.shared.playShimmer(
                anchoredTo: normalizedX,
                flavor: flavor
            )
        }

        // 4. Second haptic for hero celebrations
        if type.intensity == .hero {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                PSHaptics.shared.celebrate()
            }
        }
    }
}

// MARK: - Flavor Resolution from CelebrationType

extension FreshliCelebrationFlavor {
    init(from type: CelebrationType) {
        switch type {
        case .firstItemAdded, .firstFoodSaved, .expiryRescueStreak:
            self = .consumed
        case .shareCompleted, .donationCompleted:
            self = .shared
        case .impactMilestone, .achievementUnlock:
            self = .milestone
        case .communityImpact:
            self = .community
        case .recipeMatchSuccess:
            self = .consumed
        case .weeklyRecap:
            self = .milestone
        }
    }
}

// MARK: - Convenience Initializer (without matchedGeometry)

extension FreshliCelebrationView {
    /// Standalone celebration without matchedGeometryEffect (for overlay usage)
    init(
        type: CelebrationType,
        namespace: Namespace.ID,
        onDismiss: @escaping () -> Void
    ) {
        self.type = type
        self.flavor = FreshliCelebrationFlavor(from: type)
        self.sourceID = "freshli_celebration_\(type.id)"
        self.namespace = namespace
        self.onDismiss = onDismiss
    }
}

// MARK: - Previews

#Preview("Consumed Celebration") {
    @Previewable @Namespace var ns
    FreshliCelebrationView(
        type: .firstFoodSaved,
        flavor: .consumed,
        sourceID: "preview",
        namespace: ns,
        onDismiss: {}
    )
}

#Preview("Shared Celebration") {
    @Previewable @Namespace var ns
    FreshliCelebrationView(
        type: .shareCompleted(itemName: "Organic Milk"),
        flavor: .shared,
        sourceID: "preview",
        namespace: ns,
        onDismiss: {}
    )
}

#Preview("Milestone Celebration") {
    @Previewable @Namespace var ns
    FreshliCelebrationView(
        type: .impactMilestone(milestone: "Waste Warrior", stat: "50 items saved"),
        flavor: .milestone,
        sourceID: "preview",
        namespace: ns,
        onDismiss: {}
    )
}

#Preview("Community Celebration") {
    @Previewable @Namespace var ns
    FreshliCelebrationView(
        type: .communityImpact(totalItems: 25, neighbors: 8),
        flavor: .community,
        sourceID: "preview",
        namespace: ns,
        onDismiss: {}
    )
}
