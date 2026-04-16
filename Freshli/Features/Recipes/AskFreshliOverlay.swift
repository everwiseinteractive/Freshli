import SwiftUI

// MARK: - Ask Freshli AI Fullscreen Overlay
//
// Apple Design Award-level fullscreen experience for on-device
// Apple Intelligence recipe generation. This overlay sits above ALL
// content when active — navigation bars, tab bars, everything.
//
// Three states:
//   1. Generating  — animated sparkle orbs + typewriter status text
//   2. Results     — staggered cascade of mission cards
//   3. Error       — retry prompt with gentle animation
//
// Dismissed ONLY when the user taps the CTA button or close icon.

struct AskFreshliOverlay: View {
    @State var aiService: AIRescueService
    let atRiskItems: [FreshliItem]
    let onSelectMission: (UsageMission) -> Void
    let onDismiss: () -> Void

    // MARK: - Entrance Animation State
    @State private var showBackground = false
    @State private var showHeader = false
    @State private var showOrbs = false
    @State private var showStatusText = false
    @State private var showResults = false
    @State private var showCTA = false
    @State private var showCloseButton = false

    // MARK: - Orb Animation
    @State private var orbRotation: Double = 0
    @State private var orbPulse: CGFloat = 1.0
    @State private var centerGlow: CGFloat = 0.4
    @State private var sparklePhase: CGFloat = 0

    // MARK: - Typewriter
    @State private var statusText: String = ""
    @State private var typewriterTask: Task<Void, Never>?

    // MARK: - Results
    @State private var visibleCardIndices: Set<Int> = []
    @State private var ctaScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed

    private var isGenerating: Bool { aiService.isGenerating }
    private var hasResults: Bool { !aiService.missions.isEmpty && !isGenerating }
    private var hasError: Bool { aiService.lastError != nil && !isGenerating }

    var body: some View {
        ZStack {
            // Layer 1: Deep gradient background
            backgroundLayer
                .opacity(showBackground ? 1 : 0)

            // Layer 2: Ambient particle field
            if showOrbs && !reduceMotion {
                AIOrbField(isGenerating: isGenerating)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Layer 3: Center content
            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Spacer()
                    if showCloseButton {
                        closeButton
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                if isGenerating || (!hasResults && !hasError) {
                    generatingContent
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if hasError {
                    errorContent
                        .transition(.opacity.combined(with: .offset(y: 20)))
                } else if hasResults {
                    resultsContent
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Spacer()

                // CTA Button
                if showCTA && (hasResults || hasError) {
                    ctaSection
                        .transition(.offset(y: 80).combined(with: .opacity))
                }

                // Enough clearance for the home indicator + safe area
                // so the CTA button is never obscured by tab bar or home indicator.
                Spacer().frame(height: 100)
            }

            // Layer 4: "Powered by" badge at top
            if showHeader {
                VStack {
                    poweredByBadge
                        .transition(.offset(y: -20).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(.all)
        .animation(
            reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.2),
            value: isGenerating
        )
        .animation(
            reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.2),
            value: hasResults
        )
        .animation(
            reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.2),
            value: hasError
        )
        .onAppear {
            // Hide the floating tab bar so it doesn't overlap the CTA button
            TabBarVisibilityService.shared.hide()

            if reduceMotion {
                showBackground = true
                showHeader = true
                showOrbs = true
                showStatusText = true
                showCloseButton = true
                showCTA = true
                showResults = true
            } else {
                startEntranceCascade()
            }
            triggerGeneration()
        }
        .onDisappear {
            typewriterTask?.cancel()
            // Restore the floating tab bar when the overlay is dismissed
            TabBarVisibilityService.shared.show()
        }
        .onChange(of: aiService.isGenerating) { _, newValue in
            if !newValue {
                // Generation finished — reveal results or error
                if hasResults {
                    revealResults()
                } else if hasError {
                    withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                        showCTA = true
                    }
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            // Base gradient — Apple Intelligence palette
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.08, green: 0.06, blue: 0.18), location: 0),
                    .init(color: Color(red: 0.05, green: 0.12, blue: 0.22), location: 0.4),
                    .init(color: Color(red: 0.04, green: 0.08, blue: 0.16), location: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Accent glow blobs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [PSColors.primaryGreen.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -80, y: -200)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [PSColors.accentTeal.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .offset(x: 100, y: 180)
                .blur(radius: 50)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: -60, y: 100)
                .blur(radius: 40)
        }
    }

    // MARK: - Powered By Badge

    private var poweredByBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "apple.intelligence")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [PSColors.primaryGreen, PSColors.accentTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text(String(localized: "Powered by Apple Intelligence"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: Capsule())
        .padding(.top, 60)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            PSHaptics.shared.lightTap()
            dismissWithAnimation()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.1), in: Circle())
        }
        .accessibilityLabel(String(localized: "Close Ask Freshli"))
    }

    // MARK: - Generating Content

    private var generatingContent: some View {
        VStack(spacing: 28) {
            // Central sparkle icon with orbiting ring
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                PSColors.primaryGreen.opacity(0.6),
                                PSColors.accentTeal.opacity(0.4),
                                Color.purple.opacity(0.3),
                                PSColors.primaryGreen.opacity(0.6)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(orbRotation))
                    .scaleEffect(orbPulse)

                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PSColors.primaryGreen.opacity(centerGlow),
                                PSColors.accentTeal.opacity(centerGlow * 0.5),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                // Sparkle icon
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, PSColors.accentTeal.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }

            // Status text
            VStack(spacing: 12) {
                Text(String(localized: "Asking Freshli..."))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if showStatusText {
                    Text(statusText)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .frame(height: 40)
                        .padding(.horizontal, 40)
                }
            }

            // Item pills — what the AI is analyzing
            if !atRiskItems.isEmpty {
                itemPills
            }
        }
        .onAppear {
            if !reduceMotion {
                startOrbAnimations()
            }
            startTypewriter()
        }
    }

    // MARK: - Item Pills

    private var itemPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(atRiskItems.prefix(6).enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 6) {
                        Text(item.category.emoji)
                            .font(.system(size: 14))
                        Text(item.name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.1), in: Capsule())
                    .opacity(showStatusText ? 1 : 0)
                    .offset(y: showStatusText ? 0 : 10)
                    .animation(
                        reduceMotion ? .none : .spring(duration: 0.4, bounce: 0.2).delay(Double(index) * 0.08),
                        value: showStatusText
                    )
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Error Content

    private var errorContent: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(PSColors.warningAmber.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(PSColors.warningAmber)
                    .symbolEffect(.pulse, options: .repeat(.periodic(delay: 2.0)))
            }

            VStack(spacing: 12) {
                Text(String(localized: "Couldn't Cook Up Ideas"))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(aiService.lastError ?? String(localized: "Something went wrong. Please try again."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                PSHaptics.shared.mediumTap()
                retryGeneration()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                    Text(String(localized: "Try Again"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(.white.opacity(0.15), in: Capsule())
            }
        }
    }

    // MARK: - Results Content

    private var resultsContent: some View {
        VStack(spacing: 20) {
            // Results header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PSColors.primaryGreen)
                    .symbolEffect(.bounce, value: showResults)

                Text(String(localized: "Your Rescue Recipes"))
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(String(localized: "\(aiService.missions.count) bespoke recipes for your pantry"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            // Mission cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(Array(aiService.missions.enumerated()), id: \.element.id) { index, mission in
                        if visibleCardIndices.contains(index) {
                            AIMissionCard(
                                mission: mission,
                                index: index,
                                onTap: { onSelectMission(mission) }
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .offset(y: 40).combined(with: .opacity).combined(with: .scale(scale: 0.92)),
                                    removal: .opacity
                                )
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: 420)
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                PSHaptics.shared.lightTap()
                if !reduceMotion {
                    withAnimation(.spring(duration: 0.15)) { ctaScale = 0.92 }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        withAnimation(.spring(duration: 0.15)) { ctaScale = 1.0 }
                        try? await Task.sleep(for: .milliseconds(100))
                        dismissWithAnimation()
                    }
                } else {
                    dismissWithAnimation()
                }
            } label: {
                Text(hasResults
                     ? String(localized: "Let's Get Cooking!")
                     : String(localized: "Done"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.05, green: 0.08, blue: 0.16))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 16, y: 8)
            }
            .scaleEffect(ctaScale)
            .padding(.horizontal, 32)

            Text(String(localized: "On-device, private, no network needed"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Animation Orchestration

    private func startEntranceCascade() {
        // Phase 1: Background sweeps in
        withAnimation(.easeOut(duration: 0.4)) {
            showBackground = true
        }

        // Phase 2: Close button appears
        withAnimation(.spring(duration: 0.4, bounce: 0.2).delay(0.2)) {
            showCloseButton = true
        }

        // Phase 3: Header badge drops in
        withAnimation(.spring(duration: 0.5, bounce: 0.25).delay(0.25)) {
            showHeader = true
        }

        // Phase 4: Orbs materialize
        withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.35)) {
            showOrbs = true
        }

        // Phase 5: Status text types in
        withAnimation(.spring(duration: 0.4, bounce: 0.15).delay(0.5)) {
            showStatusText = true
        }
    }

    private func startOrbAnimations() {
        // Continuous ring rotation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }
        // Breathing pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            orbPulse = 1.08
        }
        // Center glow pulse
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            centerGlow = 0.7
        }
    }

    private func startTypewriter() {
        let messages = [
            String(localized: "Reviewing your pantry items..."),
            String(localized: "Finding the best combinations..."),
            String(localized: "Crafting rescue recipes...")
        ]

        typewriterTask = Task { @MainActor in
            for message in messages {
                guard !Task.isCancelled else { return }
                statusText = ""
                for char in message {
                    guard !Task.isCancelled else { return }
                    statusText.append(char)
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 5 : 30))
                }
                try? await Task.sleep(for: .seconds(1.2))
            }
            // Loop if still generating
            if aiService.isGenerating {
                startTypewriter()
            }
        }
    }

    private func revealResults() {
        typewriterTask?.cancel()

        // Haptic burst for completion
        PSHaptics.shared.success()

        // Stagger card reveals
        for i in 0..<aiService.missions.count {
            withAnimation(
                .spring(duration: 0.6, bounce: 0.25)
                .delay(Double(i) * 0.15 + 0.2)
            ) {
                visibleCardIndices.insert(i)
            }
        }

        // CTA appears after all cards
        let ctaDelay = Double(aiService.missions.count) * 0.15 + 0.5
        withAnimation(.spring(duration: 0.5, bounce: 0.2).delay(ctaDelay)) {
            showCTA = true
            showResults = true
        }
    }

    private func retryGeneration() {
        withAnimation(.spring(duration: 0.3)) {
            showCTA = false
            showResults = false
            visibleCardIndices.removeAll()
        }
        triggerGeneration()
        startTypewriter()
    }

    private func triggerGeneration() {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .hour, value: 48, to: Date()) ?? Date()
        let items = atRiskItems.filter { $0.expiryDate <= cutoff && !$0.isConsumed }
        Task {
            await aiService.generateMissions(for: items.isEmpty ? atRiskItems : items)
        }
    }

    private func dismissWithAnimation() {
        typewriterTask?.cancel()
        if reduceMotion {
            onDismiss()
        } else {
            withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
                showBackground = false
                showHeader = false
                showOrbs = false
                showResults = false
                showCTA = false
                showCloseButton = false
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                onDismiss()
            }
        }
    }
}

// MARK: - AI Mission Card

private struct AIMissionCard: View {
    let mission: UsageMission
    let index: Int
    let onTap: () -> Void

    @State private var isPressed = false

    private let cardColors: [Color] = [
        Color(red: 0.15, green: 0.65, blue: 0.45), // Emerald
        Color(red: 0.2, green: 0.55, blue: 0.7),   // Ocean
        Color(red: 0.55, green: 0.35, blue: 0.7)    // Amethyst
    ]

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: number + title
                HStack(alignment: .top, spacing: 12) {
                    // Recipe number badge
                    Text("\(index + 1)")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(cardColors[index % cardColors.count], in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mission.title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(mission.description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 4)

                    // Sparkle AI badge
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PSColors.primaryGreen, PSColors.accentTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(6)
                        .background(.white.opacity(0.1), in: Circle())
                }

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(height: 1)

                // Bottom row: metadata
                HStack(spacing: 16) {
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(localized: "\(mission.estimatedMinutes) min"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.5))

                    // Difficulty
                    HStack(spacing: 4) {
                        Image(systemName: mission.difficulty.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(mission.difficulty.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    // Items used
                    HStack(spacing: 4) {
                        Text(mission.itemEmojis)
                            .font(.system(size: 13))
                        Text(String(localized: "\(mission.freshliItems.count) items"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Arrow
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.15),
                                        cardColors[index % cardColors.count].opacity(0.3),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(AIMissionCardButtonStyle())
        .accessibilityLabel(String(localized: "Recipe \(index + 1): \(mission.title)"))
    }
}

// MARK: - Mission Card Button Style

private struct AIMissionCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(reduceMotion ? .none : .spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

// MARK: - AI Orb Particle Field
// Floating luminous particles that orbit gently during generation,
// then converge and burst when results arrive.

private struct AIOrbField: View {
    let isGenerating: Bool

    @State private var orbs: [AIOrbParticle] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let centerX = size.width / 2
                let centerY = size.height * 0.38

                for orb in orbs {
                    let age = elapsed - orb.birth
                    guard age >= 0 else { continue }

                    // Orbital motion
                    let orbitalAngle = orb.baseAngle + age * orb.angularSpeed
                    let radius = orb.orbitRadius + sin(age * orb.wobbleSpeed) * orb.wobbleAmp

                    let x = centerX + cos(orbitalAngle) * radius
                    let y = centerY + sin(orbitalAngle) * radius * 0.6 // Elliptical

                    // Breathing scale
                    let breathe = 1.0 + sin(age * orb.breatheSpeed) * 0.3
                    let size = orb.size * breathe

                    // Opacity pulsing
                    let opacity = orb.baseOpacity + sin(age * 2.5 + orb.phaseOffset) * 0.15

                    context.opacity = max(0, min(1, opacity))

                    let rect = CGRect(
                        x: x - size / 2,
                        y: y - size / 2,
                        width: size,
                        height: size
                    )

                    // Soft glow circle
                    context.fill(
                        Circle().path(in: rect.insetBy(dx: -size * 0.3, dy: -size * 0.3)),
                        with: .color(orb.color.opacity(0.15))
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(orb.color.opacity(0.6))
                    )
                }
            }
        }
        .onAppear { spawnOrbs() }
    }

    private func spawnOrbs() {
        let colors: [Color] = [
            PSColors.primaryGreen,
            PSColors.accentTeal,
            Color.purple.opacity(0.8),
            Color.cyan.opacity(0.8),
            Color.white.opacity(0.6),
            Color.mint.opacity(0.7)
        ]

        let now = Date.timeIntervalSinceReferenceDate
        orbs = (0..<18).map { i in
            AIOrbParticle(
                birth: now + Double.random(in: -0.5...0.5),
                baseAngle: Double.random(in: 0...(2 * .pi)),
                angularSpeed: Double.random(in: 0.15...0.5) * (Bool.random() ? 1 : -1),
                orbitRadius: Double.random(in: 60...180),
                wobbleSpeed: Double.random(in: 0.5...1.5),
                wobbleAmp: Double.random(in: 5...20),
                size: Double.random(in: 3...8),
                breatheSpeed: Double.random(in: 1.0...3.0),
                baseOpacity: Double.random(in: 0.25...0.55),
                phaseOffset: Double.random(in: 0...(2 * .pi)),
                color: colors[i % colors.count]
            )
        }
    }
}

private struct AIOrbParticle {
    let birth: Double
    let baseAngle: Double
    let angularSpeed: Double
    let orbitRadius: Double
    let wobbleSpeed: Double
    let wobbleAmp: Double
    let size: Double
    let breatheSpeed: Double
    let baseOpacity: Double
    let phaseOffset: Double
    let color: Color
}

// MARK: - View Extension

extension View {
    /// Present the Ask Freshli AI overlay above everything.
    func askFreshliOverlay(
        isPresented: Binding<Bool>,
        aiService: AIRescueService,
        atRiskItems: [FreshliItem],
        onSelectMission: @escaping (UsageMission) -> Void
    ) -> some View {
        ZStack {
            self

            if isPresented.wrappedValue {
                AskFreshliOverlay(
                    aiService: aiService,
                    atRiskItems: atRiskItems,
                    onSelectMission: { mission in
                        isPresented.wrappedValue = false
                        onSelectMission(mission)
                    },
                    onDismiss: {
                        isPresented.wrappedValue = false
                    }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 1.05))
                    )
                )
                .zIndex(9999)
            }
        }
        .animation(
            .spring(duration: 0.45, bounce: 0.15),
            value: isPresented.wrappedValue
        )
    }
}
