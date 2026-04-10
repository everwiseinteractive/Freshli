import SwiftUI
import Charts
import os

/// Premium Impact Dashboard for Freshli iOS app
/// Features: mesh gradient background, glassmorphism cards, Swift Charts integration,
/// milestone celebrations with particle effects, and activity feed
struct FreshliImpactDashboardView: View {
    @State private var viewModel: ImpactDashboardViewModel
    @State private var meshAnimationPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showMilestoneOverlay = false
    @State private var milestoneAnimationTrigger = false

    private let userId: UUID
    private let logger = Logger(subsystem: "com.freshli.app", category: "FreshliImpactDashboardView")

    init(userId: UUID) {
        self.userId = userId
        self._viewModel = State(initialValue: ImpactDashboardViewModel(userId: userId))
    }

    var body: some View {
        ZStack {
            // MARK: - Background with Mesh Gradient
            backgroundLayer

            // MARK: - Main Content
            ScrollView {
                VStack(spacing: PSSpacing.xl) {
                    // Impact cards
                    impactCardsSection

                    // Weekly freshness chart
                    freshnessChartSection

                    // Activity feed
                    activityFeedSection

                    Spacer(minLength: PSSpacing.xxxl)
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.screenVertical)
            }

            // MARK: - Milestone Celebration Overlay
            if viewModel.showMilestone {
                milestoneOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .task {
            await viewModel.loadData()
        }
    }

    // MARK: - Background with Mesh Gradient

    @ViewBuilder
    private var backgroundLayer: some View {
        if #available(iOS 18, *) {
            TimelineView(.animation(minimumInterval: 0.05, paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSince1970
                let phase = time.truncatingRemainder(dividingBy: 8.0) / 8.0

                meshGradientBackground(phase: phase)
                    .ignoresSafeArea()
            }
        } else {
            // Fallback for iOS 17 and earlier
            LinearGradient(
                gradient: Gradient(colors: [
                    PSColors.primaryGreen.opacity(0.1),
                    PSColors.accentTeal.opacity(0.08),
                    PSColors.backgroundPrimary
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    /// Mesh gradient with animated points (iOS 18+)
    @available(iOS 18, *)
    @ViewBuilder
    private func meshGradientBackground(phase: CGFloat) -> some View {
        let pointCount: Int = 9 // 3x3 grid
        let cols = 3
        let rows = 3

        // Dynamic color selection based on impact
        let impactIntensity = (viewModel.weeklyStats?.co2Avoided ?? 0) / 100.0
        let isHighImpact = impactIntensity > 0.5

        let baseColors: [Color] = isHighImpact
            ? [
                PSColors.primaryGreen,
                PSColors.accentTeal,
                PSColors.primaryGreenDark.opacity(0.8),
                PSColors.primaryGreen.opacity(0.7),
                PSColors.backgroundPrimary,
                PSColors.accentTeal.opacity(0.6),
                PSColors.primaryGreenDark,
                PSColors.primaryGreen.opacity(0.5),
                PSColors.accentTeal.opacity(0.4)
            ]
            : [
                Color(hex: 0xE0E7FF),
                Color(hex: 0xF0F9FF),
                Color(hex: 0xECFDF5),
                Color(hex: 0xF8FAFC),
                PSColors.backgroundPrimary,
                Color(hex: 0xF0FDFA),
                Color(hex: 0xDEF7F9),
                Color(hex: 0xF0FDF4),
                Color(hex: 0xFAF5FF)
            ]

        let points: [SIMD2<Float>] = (0..<pointCount).map { i in
            let col = i % cols
            let row = i / cols
            let x = Float(col) / Float(cols - 1)
            let y = Float(row) / Float(rows - 1)

            // Subtle animation: slight oscillation
            let p = Float(phase)
            let animationOffset = sin(p * .pi * 2 + Float(i)) * Float(0.05)
            return SIMD2(
                x: x + animationOffset,
                y: y + animationOffset
            )
        }

        MeshGradient(
            width: cols,
            height: rows,
            points: points,
            colors: baseColors
        )
    }

    // MARK: - Impact Cards Section

    @ViewBuilder
    private var impactCardsSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("Your Impact")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .padding(.horizontal, PSSpacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PSSpacing.md) {
                    impactCard(
                        title: "CO₂ Avoided",
                        value: String(format: "%.1f", viewModel.weeklyStats?.co2Avoided ?? 0),
                        unit: "kg",
                        icon: "leaf.fill",
                        tint: PSColors.accentTeal,
                        changePercent: viewModel.weeklyComparison?.co2ChangePercent ?? 0
                    )

                    impactCard(
                        title: "Money Saved",
                        value: String(format: "$%.2f", viewModel.weeklyStats?.moneySaved ?? 0),
                        unit: "",
                        icon: "dollarsign.circle.fill",
                        tint: PSColors.primaryGreen,
                        changePercent: viewModel.weeklyComparison?.moneyChangePercent ?? 0
                    )

                    impactCard(
                        title: "Meals Shared",
                        value: "\(viewModel.weeklyStats?.eventsCount ?? 0)",
                        unit: "this week",
                        icon: "heart.fill",
                        tint: Color(hex: 0xEC4899),
                        changePercent: 0
                    )
                }
                .padding(.horizontal, PSSpacing.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
        }
    }

    /// Individual impact card with glassmorphism
    @ViewBuilder
    private func impactCard(
        title: String,
        value: String,
        unit: String,
        icon: String,
        tint: Color,
        changePercent: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            HStack(alignment: .top, spacing: PSSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)

                Spacer()

                // Change badge
                if changePercent != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: changePercent > 0 ? "arrow.up.right" : "arrow.down.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(Int(abs(changePercent)))%")
                            .font(PSTypography.caption2)
                    }
                    .foregroundStyle(changePercent > 0 ? PSColors.primaryGreen : Color(hex: 0xEF4444))
                    .padding(.vertical, PSSpacing.xxs)
                    .padding(.horizontal, PSSpacing.xs)
                    .background(
                        (changePercent > 0 ? PSColors.primaryGreen : Color(hex: 0xEF4444))
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))
                }
            }

            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text(value)
                    .font(PSTypography.statLarge)
                    .foregroundStyle(PSColors.textPrimary)
                    .contentTransition(.numericText())

                HStack(spacing: PSSpacing.xxs) {
                    Text(title)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textSecondary)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }
        }
        .frame(minWidth: 160)
        .padding(PSSpacing.lg)
        .background(
            .ultraThinMaterial
        )
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl)
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl))
        .shadow(color: PSColors.primaryGreen.opacity(0.1), radius: 12, y: 4)
        .impactShimmer()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)".trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Weekly Freshness Chart

    @ViewBuilder
    private var freshnessChartSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("Weekly Freshness")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .padding(.horizontal, PSSpacing.sm)

            Chart {
                ForEach(viewModel.freshnessTrend, id: \.id) { daily in
                    BarMark(
                        x: .value("Day", daily.day),
                        yStart: .value("Start", 0),
                        yEnd: .value("Saved", daily.savedPercent)
                    )
                    .foregroundStyle(by: .value("Status", "Saved"))
                    .opacity(0.9)

                    BarMark(
                        x: .value("Day", daily.day),
                        yStart: .value("Start", daily.savedPercent),
                        yEnd: .value("Wasted", daily.savedPercent + daily.wastedPercent)
                    )
                    .foregroundStyle(by: .value("Status", "Wasted"))
                    .opacity(0.6)
                }
            }
            .chartYScale(domain: 0...100)
            .chartForegroundStyleScale([
                "Saved": PSColors.primaryGreen,
                "Wasted": PSColors.warningAmber
            ])
            .chartLegend(position: .bottomLeading, alignment: .leading)
            .frame(height: 220)
            .padding(PSSpacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
            .accessibilityLabel("Weekly freshness trend chart")
            .accessibilityHint("Shows percentage of items saved vs wasted each day")
        }
    }

    // MARK: - Activity Feed Section

    @ViewBuilder
    private var activityFeedSection: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            Text("Recent Activity")
                .font(PSTypography.headline)
                .foregroundStyle(PSColors.textPrimary)
                .padding(.horizontal, PSSpacing.sm)

            if viewModel.recentEvents.isEmpty {
                VStack(spacing: PSSpacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen.opacity(0.5))

                    Text("No activities yet")
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(PSSpacing.xxxl)
            } else {
                VStack(spacing: PSSpacing.sm) {
                    ForEach(viewModel.recentEvents, id: \.id) { event in
                        activityRow(for: event)
                    }
                }
                .padding(PSSpacing.lg)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg))
            }
        }
    }

    /// Individual activity row
    @ViewBuilder
    private func activityRow(for event: SupabaseImpactEvent) -> some View {
        HStack(spacing: PSSpacing.md) {
            // Event icon
            Image(systemName: iconForEventType(event.eventType))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tintForEventType(event.eventType))
                .frame(width: 32, height: 32)
                .background(tintForEventType(event.eventType).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm))

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.itemName ?? eventTypeLabel(event.eventType))
                    .font(PSTypography.calloutMedium)
                    .foregroundStyle(PSColors.textPrimary)

                HStack(spacing: PSSpacing.xs) {
                    if let moneySaved = event.estimatedMoneySaved, moneySaved > 0 {
                        Label(
                            String(format: "$%.2f", moneySaved),
                            systemImage: "dollarsign.circle.fill"
                        )
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textTertiary)
                    }

                    if let co2Avoided = event.estimatedCo2Avoided, co2Avoided > 0 {
                        Label(
                            String(format: "%.1f kg CO₂", co2Avoided),
                            systemImage: "leaf.fill"
                        )
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textTertiary)
                    }
                }
            }

            Spacer()

            // Relative time
            Text(relativeTimeString(for: event.createdAt))
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(.vertical, PSSpacing.sm)
    }

    // MARK: - Milestone Overlay

    @ViewBuilder
    private var milestoneOverlay: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                // Particle burst
                MilestoneParticleBurst(trigger: viewModel.showMilestone)
                    .frame(height: 200)

                // Icon
                Image(systemName: viewModel.lastMilestoneIcon)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .scaleEffect(milestoneAnimationTrigger ? 1.0 : 0.5)
                    .opacity(milestoneAnimationTrigger ? 1.0 : 0.0)

                // Content
                VStack(spacing: PSSpacing.md) {
                    Text("Milestone Unlocked!")
                        .font(PSTypography.title2)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(viewModel.lastMilestoneTitle)
                        .font(PSTypography.headline)
                        .foregroundStyle(PSColors.primaryGreen)

                    Text(viewModel.lastMilestoneValue)
                        .font(PSTypography.statMedium)
                        .foregroundStyle(PSColors.textPrimary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(PSSpacing.xxxl)
            .frame(maxWidth: 280)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.1)) {
                milestoneAnimationTrigger = true
            }
            PSHaptics.shared.celebrate()
            HapticHarvestService.shared.harvestCelebration()
        }
    }

    // MARK: - Helper Methods

    private func iconForEventType(_ eventType: String) -> String {
        switch eventType.lowercased() {
        case "item_consumed":
            return "checkmark.circle.fill"
        case "item_shared":
            return "heart.fill"
        case "item_donated":
            return "gift.fill"
        default:
            return "leaf.fill"
        }
    }

    private func tintForEventType(_ eventType: String) -> Color {
        switch eventType.lowercased() {
        case "item_consumed":
            return PSColors.primaryGreen
        case "item_shared":
            return Color(hex: 0xEC4899)
        case "item_donated":
            return PSColors.infoBlue
        default:
            return PSColors.accentTeal
        }
    }

    private func eventTypeLabel(_ eventType: String) -> String {
        switch eventType.lowercased() {
        case "item_consumed":
            return "Item Consumed"
        case "item_shared":
            return "Item Shared"
        case "item_donated":
            return "Item Donated"
        default:
            return "Impact Event"
        }
    }

    private func relativeTimeString(for date: Date?) -> String {
        guard let date else { return "Now" }

        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Milestone Particle Burst

/// Particle burst animation for milestone celebration
private struct MilestoneParticleBurst: View {
    let trigger: Bool
    @State private var particles: [MilestoneParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Image(systemName: "star.fill")
                    .font(.system(size: particle.size, weight: .semibold))
                    .foregroundStyle(particle.color)
                    .offset(x: particle.offset.x, y: particle.offset.y)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            generateParticles()
        }
    }

    private func generateParticles() {
        particles = (0..<12).map { i in
            let angle = Double(i) * (360.0 / 12.0)
            let radians = angle * .pi / 180.0
            let distance: CGFloat = CGFloat.random(in: 40...80)

            let particle = MilestoneParticle(
                id: i,
                size: CGFloat.random(in: 8...16),
                color: [PSColors.primaryGreen, PSColors.accentTeal, Color(hex: 0xFBBF24)]
                    .randomElement() ?? PSColors.primaryGreen,
                offset: .zero,
                opacity: 1.0
            )

            if trigger {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    withAnimation(.easeOut(duration: 0.8)) {
                        if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                            particles[index].offset = CGPoint(
                                x: cos(radians) * distance,
                                y: sin(radians) * distance
                            )
                            particles[index].opacity = 0
                        }
                    }
                }
            }

            return particle
        }
    }
}

/// Individual milestone particle
private struct MilestoneParticle: Identifiable {
    let id: Int
    let size: CGFloat
    let color: Color
    var offset: CGPoint
    var opacity: Double
}

// MARK: - Preview

#Preview {
    FreshliImpactDashboardView(userId: UUID())
        .preferredColorScheme(nil)
}
