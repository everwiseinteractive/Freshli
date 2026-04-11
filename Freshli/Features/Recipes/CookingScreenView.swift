import SwiftUI
import AVFoundation
import Combine

// MARK: - Voice Type

enum VoiceType: String, CaseIterable, Identifiable {
    case warm
    case classic
    case british
    case energetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warm:      return "Aria — Warm"
        case .classic:   return "Classic"
        case .british:   return "Harper — British"
        case .energetic: return "Kai — Energetic"
        }
    }

    var voiceDescription: String {
        switch self {
        case .warm:      return "Friendly, nurturing & patient"
        case .classic:   return "Clear & neutral American"
        case .british:   return "Refined & articulate"
        case .energetic: return "Upbeat Australian accent"
        }
    }

    var icon: String {
        switch self {
        case .warm:      return "heart.fill"
        case .classic:   return "waveform"
        case .british:   return "crown.fill"
        case .energetic: return "bolt.fill"
        }
    }

    var languageCode: String {
        switch self {
        case .warm, .classic: return "en-US"
        case .british:        return "en-GB"
        case .energetic:      return "en-AU"
        }
    }

    var rate: Float {
        switch self {
        case .warm:      return AVSpeechUtteranceDefaultSpeechRate * 0.78
        case .classic:   return AVSpeechUtteranceDefaultSpeechRate * 0.85
        case .british:   return AVSpeechUtteranceDefaultSpeechRate * 0.80
        case .energetic: return AVSpeechUtteranceDefaultSpeechRate * 0.95
        }
    }

    var pitch: Float {
        switch self {
        case .warm:      return 1.18
        case .classic:   return 1.05
        case .british:   return 1.00
        case .energetic: return 1.22
        }
    }

    var volume: Float {
        switch self {
        case .warm:      return 0.90
        case .classic:   return 0.90
        case .british:   return 0.85
        case .energetic: return 0.95
        }
    }

    /// Resolves the richest available system voice for this type.
    /// Tries premium → enhanced → standard so users with downloaded
    /// high-quality voices automatically get the best experience.
    func makeVoice() -> AVSpeechSynthesisVoice? {
        let candidates: [String]
        switch self {
        case .warm:
            candidates = [
                "com.apple.voice.premium.en-US.Zoe",
                "com.apple.voice.premium.en-US.Aria",
                "com.apple.ttsbundle.Samantha-premium",
                "com.apple.voice.enhanced.en-US.samantha",
            ]
        case .classic:
            candidates = [
                "com.apple.ttsbundle.Samantha-premium",
                "com.apple.voice.enhanced.en-US.samantha",
                "com.apple.voice.premium.en-US.Nicky",
            ]
        case .british:
            candidates = [
                "com.apple.voice.premium.en-GB.Daniel",
                "com.apple.ttsbundle.Daniel-premium",
                "com.apple.voice.enhanced.en-GB.daniel",
            ]
        case .energetic:
            candidates = [
                "com.apple.voice.premium.en-AU.Karen",
                "com.apple.ttsbundle.Karen-premium",
                "com.apple.voice.enhanced.en-AU.karen",
            ]
        }
        for id in candidates {
            if let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        }
        return AVSpeechSynthesisVoice(language: languageCode)
    }
}

// MARK: - CookingScreenView
// Flagship Apple Design Award-level immersive cooking experience for Freshli.
// Forced dark "chef mode" with voice guidance, gesture-driven step navigation,
// animated timer ring, glass-morphism step card, and a full celebration overlay.

struct CookingScreenView: View {
    let recipe: Recipe
    var matchingPantryItems: [String] = []

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State
    @State private var currentStepIndex = 0
    @State private var completedSteps: Set<Int> = []
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var timerSeconds: Int = 180
    @State private var timerRunning = false
    @State private var timerElapsed: Int = 0
    @State private var timerDuration: Int = 180
    @State private var isSpeaking = false
    @State private var voiceEnabled = true
    @State private var showIngredients = false
    @State private var showMusicPicker = false
    @State private var showCompletion = false
    @State private var funFactText = ""
    @State private var showFunFact = false
    @State private var wavePhase: CGFloat = 0
    @State private var appeared = false
    @State private var userRating: Int = 0
    @State private var selectedVoiceType: VoiceType = .warm
    @State private var showVoiceSettings = false

    // MARK: - Timer publisher
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Voice
    private let speechSynthesizer = AVSpeechSynthesizer()

    // MARK: - Derived
    private var totalSteps: Int { recipe.steps.count }
    private var currentStep: String {
        guard currentStepIndex < recipe.steps.count else { return "" }
        return recipe.steps[currentStepIndex]
    }
    private var isLastStep: Bool { currentStepIndex == totalSteps - 1 }
    private var timerProgress: Double { min(Double(timerElapsed) / Double(max(timerDuration, 1)), 1.0) }
    private var timerRemaining: Int { max(timerDuration - timerElapsed, 0) }
    private var timerColor: Color {
        timerProgress < 0.5
            ? PSColors.primaryGreen
            : timerProgress < 0.75
                ? PSColors.warningAmber
                : PSColors.expiredRed
    }

    /// Ambient glow color derived from step keywords for immersive context.
    private var stepAmbientColor: Color {
        let lower = currentStep.lowercased()
        if lower.contains("heat") || lower.contains("fire") || lower.contains("sear") || lower.contains("fry") || lower.contains("roast") {
            return Color.orange
        } else if lower.contains("boil") || lower.contains("simmer") || lower.contains("water") || lower.contains("steam") {
            return Color.blue.opacity(0.9)
        } else if lower.contains("season") || lower.contains("salt") || lower.contains("spice") {
            return Color.orange.opacity(0.7)
        } else if lower.contains("mix") || lower.contains("stir") || lower.contains("whisk") || lower.contains("blend") {
            return PSColors.accentTeal
        } else if lower.contains("serve") || lower.contains("plate") || lower.contains("garnish") {
            return Color.yellow.opacity(0.9)
        }
        return PSColors.primaryGreen
    }
    private var timerDisplay: String {
        let m = timerRemaining / 60
        let s = timerRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Food Facts
    private let foodFacts: [String] = [
        "Honey never expires — archaeologists found 3,000-year-old honey in Egyptian tombs!",
        "Bananas are technically berries, while strawberries are not.",
        "Avocados ripen faster next to apples or bananas, thanks to ethylene gas.",
        "The Maillard reaction — browning — creates thousands of flavor compounds in cooked food.",
        "Salt doesn't actually make water boil faster; it raises the boiling point slightly.",
        "Fresh herbs have about 5 times more flavor compounds than dried.",
        "Cooking garlic in oil for 30 seconds unlocks its full aromatic potential.",
        "A pinch of salt in sweet dishes enhances sweetness without making it salty.",
        "Resting meat after cooking lets juices redistribute — up to 15% juicier!",
        "Pasta water is liquid gold — its starch helps sauce cling to noodles.",
        "Overcooked vegetables lose up to 50% of their vitamin C.",
        "Umami — the fifth taste — is most concentrated in aged cheeses, mushrooms, and tomatoes.",
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            // Always-dark chef mode background
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, PSSpacing.sm)
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

                stepProgressIndicator
                    .padding(.top, PSSpacing.lg)
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

                heroStepCard
                    .padding(.top, PSSpacing.lg)
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

                timerSection
                    .padding(.top, PSSpacing.xl)
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)

                Spacer(minLength: PSSpacing.lg)

                bottomActionBar
                    .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
                    .padding(.bottom, PSSpacing.xl)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)

            // Fun fact pill overlay
            if showFunFact {
                funFactOverlay
                    .transition(.asymmetric(
                        insertion: .offset(y: 20).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(10)
            }

            // Completion overlay
            if showCompletion {
                completionOverlay
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(20)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { handleAppear() }
        .onReceive(ticker) { _ in handleTick() }
        .onChange(of: currentStepIndex) { _, _ in handleStepChange() }
        .sheet(isPresented: $showIngredients) { ingredientsSheet }
        .sheet(isPresented: $showMusicPicker) { musicPickerSheet }
        .sheet(isPresented: $showVoiceSettings) { voiceSettingsSheet }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: 0x060F0A), location: 0),
                .init(color: Color(hex: 0x0C1E14), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: PSSpacing.md) {
            // Dismiss button
            Button {
                PSHaptics.shared.lightTap()
                speechSynthesizer.stopSpeaking(at: .immediate)
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: PSLayout.scaledFont(26), weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(PressableButtonStyle())

            // Center: title + step label
            VStack(spacing: 2) {
                Text(recipe.title)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Step \(currentStepIndex + 1) of \(totalSteps)")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)

            // Voice button — tap opens settings, long-press toggles
            Button {
                PSHaptics.shared.lightTap()
                showVoiceSettings = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: voiceEnabled ? "waveform" : "waveform.slash")
                        .font(.system(size: PSLayout.scaledFont(22), weight: .medium))
                        .foregroundStyle(voiceEnabled ? .white : .white.opacity(0.35))
                    if voiceEnabled {
                        Circle()
                            .fill(PSColors.primaryGreen)
                            .frame(width: PSLayout.scaled(7), height: PSLayout.scaled(7))
                            .offset(x: PSLayout.scaled(3), y: PSLayout.scaled(3))
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Step Progress Indicator

    private var stepProgressIndicator: some View {
        HStack(spacing: PSSpacing.xs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(pillColor(for: index))
                    .frame(
                        width: index == currentStepIndex
                            ? PSLayout.scaled(32)
                            : PSLayout.scaled(16),
                        height: PSLayout.scaled(5)
                    )
                    .animation(
                        reduceMotion ? .none : PSMotion.springDefault,
                        value: currentStepIndex
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pillColor(for index: Int) -> Color {
        if completedSteps.contains(index) { return PSColors.primaryGreen }
        if index == currentStepIndex { return .white }
        return .white.opacity(0.15)
    }

    // MARK: - Hero Step Card

    private var heroStepCard: some View {
        ZStack(alignment: .bottom) {
            // Ambient glow — colour-coded to step context
            Circle()
                .fill(stepAmbientColor.opacity(0.18))
                .frame(width: PSLayout.scaled(220), height: PSLayout.scaled(220))
                .blur(radius: PSLayout.scaled(55))
                .offset(y: PSLayout.scaled(-20))
                .animation(.easeInOut(duration: 0.6), value: currentStepIndex)

            // Glass card
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .fill(stepAmbientColor.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .stroke(stepAmbientColor.opacity(0.18), lineWidth: 1)
                )

            VStack(spacing: PSSpacing.lg) {
                // Step badge top-left
                HStack {
                    Text("Step \(currentStepIndex + 1)")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.primaryGreen)
                        .padding(.horizontal, PSSpacing.md)
                        .padding(.vertical, PSSpacing.xs)
                        .background(PSColors.primaryGreen.opacity(0.15))
                        .clipShape(Capsule())
                    Spacer()
                }

                Spacer(minLength: PSSpacing.sm)

                // Step instruction
                Text(currentStep)
                    .font(.system(size: PSLayout.scaledFont(22), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("step-\(currentStepIndex)")
                    .transition(.asymmetric(
                        insertion: .offset(x: dragOffset < 0 ? 40 : -40).combined(with: .opacity),
                        removal: .offset(x: dragOffset < 0 ? -40 : 40).combined(with: .opacity)
                    ))

                Spacer(minLength: PSSpacing.sm)

                // Sound wave (when speaking)
                if isSpeaking {
                    soundWaveView
                        .transition(.opacity)
                } else {
                    // Placeholder spacer so card doesn't jump
                    Color.clear.frame(height: PSLayout.scaled(24))
                }
            }
            .padding(PSSpacing.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: PSLayout.scaled(220))
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset) * 0.015))
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(reduceMotion ? .none : .interactiveSpring()) {
                        dragOffset = value.translation.width
                        isDragging = true
                    }
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width < -threshold {
                        advanceStep()
                    } else if value.translation.width > threshold {
                        retreatStep()
                    } else {
                        withAnimation(reduceMotion ? .none : PSMotion.springBouncy) {
                            dragOffset = 0
                        }
                    }
                    isDragging = false
                }
        )
        .animation(reduceMotion ? .none : PSMotion.springGentle, value: currentStepIndex)
    }

    // MARK: - Sound Wave

    private var soundWaveView: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(PSColors.primaryGreen)
                    .frame(
                        width: 3,
                        height: 8 + sin(wavePhase * .pi * 2 + Double(i) * 0.8) * 8
                    )
                    .animation(
                        .easeInOut(duration: 0.15).repeatForever(),
                        value: wavePhase
                    )
            }
        }
        .frame(height: PSLayout.scaled(24))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                wavePhase = 1.0
            }
        }
    }

    // MARK: - Timer Section

    private var timerSection: some View {
        HStack(spacing: PSSpacing.xxl) {
            Spacer()

            // Circular progress ring
            ZStack {
                // Urgent glow pulse when nearly expired
                if timerProgress > 0.75 && timerRunning {
                    Circle()
                        .fill(PSColors.expiredRed.opacity(0.18))
                        .frame(width: PSLayout.scaled(112), height: PSLayout.scaled(112))
                        .scaleEffect(wavePhase > 0 ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: wavePhase)
                }

                // Track ring
                Circle()
                    .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: PSLayout.scaled(100), height: PSLayout.scaled(100))

                // Progress ring
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: PSLayout.scaled(100), height: PSLayout.scaled(100))
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: timerProgress)

                // Countdown text
                VStack(spacing: 2) {
                    Text(timerDisplay)
                        .font(.system(size: PSLayout.scaledFont(22), weight: .bold, design: .monospaced))
                        .foregroundStyle(timerProgress > 0.75 ? PSColors.expiredRed : .white)
                        .monospacedDigit()
                    Text(timerRunning ? "remaining" : "paused")
                        .font(.system(size: PSLayout.scaledFont(9), weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            // Controls
            VStack(spacing: PSSpacing.md) {
                // Play/Pause
                Button {
                    PSHaptics.shared.mediumTap()
                    withAnimation(reduceMotion ? .none : PSMotion.springDefault) {
                        timerRunning.toggle()
                    }
                } label: {
                    Image(systemName: timerRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(44), weight: .regular))
                        .foregroundStyle(PSColors.primaryGreen)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(PressableButtonStyle())

                // Reset
                Button {
                    PSHaptics.shared.lightTap()
                    resetTimer()
                } label: {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: PSLayout.scaledFont(24), weight: .regular))
                        .foregroundStyle(.white.opacity(0.50))
                }
                .buttonStyle(PressableButtonStyle())
            }

            Spacer()
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: PSSpacing.md) {
            // Ingredients button
            Button {
                PSHaptics.shared.lightTap()
                showIngredients = true
            } label: {
                VStack(spacing: PSSpacing.xxs) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: PSLayout.scaledFont(20), weight: .medium))
                    Text("Ingredients")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: PSLayout.scaled(64), height: PSLayout.scaled(56))
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())

            // Complete Step / Finish Cooking (center — hero button)
            Button {
                PSHaptics.shared.mediumTap()
                handleCompleteStep()
            } label: {
                HStack(spacing: PSSpacing.sm) {
                    if isLastStep {
                        Text("Finish Cooking 🎉")
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                        Text("Complete Step")
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: PSLayout.scaled(56))
                .background(
                    LinearGradient(
                        colors: [PSColors.primaryGreen, Color(hex: 0x16A34A)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: PSColors.primaryGreen.opacity(0.5), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(PressableButtonStyle())

            // Music button
            Button {
                PSHaptics.shared.lightTap()
                showMusicPicker = true
            } label: {
                VStack(spacing: PSSpacing.xxs) {
                    Image(systemName: "music.note")
                        .font(.system(size: PSLayout.scaledFont(20), weight: .medium))
                    Text("Music")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: PSLayout.scaled(64), height: PSLayout.scaled(56))
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Fun Fact Overlay

    private var funFactOverlay: some View {
        VStack {
            Spacer()
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                    .foregroundStyle(PSColors.warningAmber)
                Text(funFactText)
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.90))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                    .fill(Color(hex: 0x1A2E1F))
                    .overlay(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                            .stroke(PSColors.primaryGreen.opacity(0.30), lineWidth: 1)
                    )
            )
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.bottom, PSLayout.scaled(160))
        }
    }

    // MARK: - Ingredients Sheet

    private var ingredientsSheet: some View {
        ZStack {
            Color(hex: 0x0C1E14).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: PSSpacing.md) {
                    // Handle pill
                    RoundedRectangle(cornerRadius: PSSpacing.radiusFull, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .frame(width: 38, height: 5)
                        .frame(maxWidth: .infinity)
                        .padding(.top, PSSpacing.md)

                    Text("Ingredients")
                        .font(.system(size: PSLayout.scaledFont(22), weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, PSSpacing.cardPadding)
                        .padding(.top, PSSpacing.sm)

                    Text("\(recipe.ingredients.count) items")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, PSSpacing.cardPadding)
                        .padding(.bottom, PSSpacing.sm)

                    VStack(spacing: 0) {
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                            let isInPantry = matchingPantryItems.contains { $0.lowercased() == ingredient.lowercased() }

                            HStack(spacing: PSSpacing.md) {
                                Image(systemName: isInPantry ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: PSLayout.scaledFont(20), weight: .medium))
                                    .foregroundStyle(isInPantry ? PSColors.primaryGreen : .white.opacity(0.30))

                                Text(ingredient)
                                    .font(.system(size: PSLayout.scaledFont(15), weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.90))

                                Spacer()

                                if isInPantry {
                                    Text("In Pantry")
                                        .font(.system(size: PSLayout.scaledFont(11), weight: .semibold, design: .rounded))
                                        .foregroundStyle(PSColors.primaryGreen)
                                        .padding(.horizontal, PSSpacing.sm)
                                        .padding(.vertical, PSSpacing.xxs)
                                        .background(PSColors.primaryGreen.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, PSSpacing.cardPadding)
                            .padding(.vertical, PSSpacing.md)

                            if index < recipe.ingredients.count - 1 {
                                Divider()
                                    .background(.white.opacity(0.08))
                                    .padding(.horizontal, PSSpacing.cardPadding)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                            .fill(.white.opacity(0.05))
                    )
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.bottom, PSSpacing.xxxl)
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Music Picker Sheet

    private var musicPickerSheet: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x060F0A), location: 0),
                    .init(color: Color(hex: 0x0C1E14), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                // Handle pill
                RoundedRectangle(cornerRadius: PSSpacing.radiusFull, style: .continuous)
                    .fill(.white.opacity(0.25))
                    .frame(width: 38, height: 5)
                    .padding(.top, PSSpacing.lg)

                Text("Play Music While Cooking")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: PSSpacing.md) {
                    MusicServiceButton(
                        icon: "music.note.list",
                        name: "Apple Music",
                        accentColor: Color(hex: 0xFC3C44),
                        urlString: "music://"
                    )
                    MusicServiceButton(
                        icon: "music.mic",
                        name: "Spotify",
                        accentColor: Color(hex: 0x1DB954),
                        urlString: "spotify://"
                    )
                    MusicServiceButton(
                        icon: "play.rectangle.fill",
                        name: "YouTube Music",
                        accentColor: Color(hex: 0xFF0000),
                        urlString: "youtubemusic://",
                        fallbackURLString: "https://music.youtube.com"
                    )
                    MusicServiceButton(
                        icon: "mic.fill",
                        name: "Podcasts",
                        accentColor: Color(hex: 0xB150E2),
                        urlString: "podcasts://"
                    )
                }
                .padding(.horizontal, PSSpacing.lg)

                Text("Opens your music app — come right back and keep cooking!")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PSSpacing.xl)

                Spacer()
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Voice Settings Sheet

    private var voiceSettingsSheet: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x060F0A), location: 0),
                    .init(color: Color(hex: 0x0C1E14), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                // Handle
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(0.25))
                    .frame(width: 38, height: 5)
                    .padding(.top, PSSpacing.lg)

                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        Text("Voice Chef")
                            .font(.system(size: PSLayout.scaledFont(22), weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Your personal sous chef")
                            .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Toggle("", isOn: $voiceEnabled)
                        .tint(PSColors.primaryGreen)
                        .onChange(of: voiceEnabled) { _, enabled in
                            if enabled {
                                speakStep(humanPhrase(for: currentStep, index: currentStepIndex))
                            } else {
                                speechSynthesizer.stopSpeaking(at: .immediate)
                                isSpeaking = false
                            }
                        }
                }
                .padding(.horizontal, PSSpacing.cardPadding)

                if voiceEnabled {
                    VStack(alignment: .leading, spacing: PSSpacing.md) {
                        Text("Voice Style")
                            .font(.system(size: PSLayout.scaledFont(14), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                            .padding(.horizontal, PSSpacing.cardPadding)

                        VStack(spacing: PSSpacing.sm) {
                            ForEach(VoiceType.allCases) { voiceType in
                                Button {
                                    PSHaptics.shared.lightTap()
                                    withAnimation(PSMotion.springDefault) {
                                        selectedVoiceType = voiceType
                                    }
                                    // Live preview — uses the best available voice for this type
                                    let preview = AVSpeechUtterance(string: "Hello! Ready to cook something amazing?")
                                    preview.voice           = voiceType.makeVoice()
                                    preview.rate            = voiceType.rate
                                    preview.pitchMultiplier = voiceType.pitch
                                    preview.volume          = voiceType.volume
                                    preview.preUtteranceDelay = 0.15
                                    speechSynthesizer.stopSpeaking(at: .immediate)
                                    speechSynthesizer.speak(preview)
                                } label: {
                                    HStack(spacing: PSSpacing.md) {
                                        ZStack {
                                            Circle()
                                                .fill(selectedVoiceType == voiceType
                                                      ? PSColors.primaryGreen
                                                      : .white.opacity(0.08))
                                                .frame(width: PSLayout.scaled(42), height: PSLayout.scaled(42))
                                            Image(systemName: voiceType.icon)
                                                .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                                                .foregroundStyle(selectedVoiceType == voiceType
                                                                 ? .black
                                                                 : .white.opacity(0.75))
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(voiceType.displayName)
                                                .font(.system(size: PSLayout.scaledFont(15), weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Text(voiceType.voiceDescription)
                                                .font(.system(size: PSLayout.scaledFont(12), weight: .regular, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }

                                        Spacer()

                                        if selectedVoiceType == voiceType {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: PSLayout.scaledFont(20)))
                                                .foregroundStyle(PSColors.primaryGreen)
                                        }
                                    }
                                    .padding(.horizontal, PSSpacing.lg)
                                    .padding(.vertical, PSSpacing.md)
                                    .background(selectedVoiceType == voiceType
                                                ? PSColors.primaryGreen.opacity(0.12)
                                                : .white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                                            .stroke(selectedVoiceType == voiceType
                                                    ? PSColors.primaryGreen.opacity(0.40)
                                                    : .clear,
                                                    lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PSSpacing.lg)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()
            }
        }
        .environment(\.colorScheme, .dark)
        .presentationDetents(voiceEnabled ? [.fraction(0.72), .large] : [.fraction(0.28)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            // Particle canvas background
            Canvas { context, size in
                for _ in 0..<60 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let r = CGFloat.random(in: 1.5...4.0)
                    let opacity = Double.random(in: 0.15...0.55)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
            .allowsHitTesting(false)

            LinearGradient(
                colors: [
                    Color(hex: 0x052A12),
                    Color(hex: 0x0C3D1A),
                    Color(hex: 0x093020)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Content
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    Spacer(minLength: PSSpacing.jumbo)

                    // Emoji
                    Text("🎉")
                        .font(.system(size: PSLayout.scaledFont(80)))
                        .shadow(color: PSColors.primaryGreen.opacity(0.5), radius: 30, x: 0, y: 0)

                    // Title
                    VStack(spacing: PSSpacing.sm) {
                        Text("Recipe Complete!")
                            .font(.system(size: PSLayout.scaledFont(32), weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("You've made \(recipe.title)")
                            .font(.system(size: PSLayout.scaledFont(17), weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }

                    // Impact stats
                    HStack(spacing: PSSpacing.md) {
                        completionStatCard(
                            icon: "leaf.fill",
                            value: String(format: "%.1f kg", Double(matchingPantryItems.count) * 0.8),
                            label: "CO₂ Saved",
                            color: PSColors.primaryGreen
                        )
                        completionStatCard(
                            icon: "dollarsign.circle.fill",
                            value: String(format: "$%.2f", Double(matchingPantryItems.count) * 3.50),
                            label: "Money Saved",
                            color: PSColors.warningAmber
                        )
                    }
                    .padding(.horizontal, PSSpacing.cardPadding)

                    // Star rating
                    VStack(spacing: PSSpacing.md) {
                        Text("Rate Your Cook")
                            .font(.system(size: PSLayout.scaledFont(16), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))

                        HStack(spacing: PSSpacing.md) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    PSHaptics.shared.lightTap()
                                    withAnimation(PSMotion.springBouncy) {
                                        userRating = star
                                    }
                                } label: {
                                    Image(systemName: star <= userRating ? "star.fill" : "star")
                                        .font(.system(size: PSLayout.scaledFont(32), weight: .medium))
                                        .foregroundStyle(star <= userRating ? Color(hex: 0xFFD700) : .white.opacity(0.25))
                                        .scaleEffect(star == userRating ? 1.20 : 1.0)
                                        .animation(PSMotion.springBouncy, value: userRating)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Done button
                    Button {
                        PSHaptics.shared.celebrate()
                        speechSynthesizer.stopSpeaking(at: .immediate)
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: PSLayout.scaledFont(17), weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: PSLayout.scaled(56))
                            .background(
                                LinearGradient(
                                    colors: [PSColors.primaryGreen, Color(hex: 0x16A34A)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: PSColors.primaryGreen.opacity(0.50), radius: 16, x: 0, y: 6)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, PSSpacing.cardPadding)

                    Spacer(minLength: PSSpacing.jumbo)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func completionStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: PSSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(24), weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: PSLayout.scaledFont(22), weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(12), weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PSSpacing.lg)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
    }

    // MARK: - Logic

    private func handleAppear() {
        let duration = estimatedDuration(for: currentStep)
        timerDuration = duration
        timerSeconds = duration
        timerElapsed = 0

        let anim: Animation = reduceMotion ? .easeOut(duration: 0.2) : PSMotion.springGentle.delay(0.12)
        withAnimation(anim) { appeared = true }

        if voiceEnabled {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                await MainActor.run {
                    speakStep(humanPhrase(for: currentStep, index: currentStepIndex))
                }
            }
        }
    }

    private func handleTick() {
        guard timerRunning else { return }
        if timerElapsed < timerDuration {
            timerElapsed += 1
        } else {
            timerRunning = false
            PSHaptics.shared.warning()
        }
    }

    private func handleStepChange() {
        resetTimer()
        timerRunning = false

        let duration = estimatedDuration(for: currentStep)
        timerDuration = duration
        timerSeconds = duration

        if voiceEnabled {
            speakStep(humanPhrase(for: currentStep, index: currentStepIndex))
        }
        maybeShowFunFact()
    }

    private func handleCompleteStep() {
        completedSteps.insert(currentStepIndex)

        if isLastStep {
            // Last step complete
            let phrase = "Amazing work! You've completed all steps. Enjoy your meal!"
            speakStep(phrase)
            PSHaptics.shared.celebrate()
            withAnimation(reduceMotion ? .none : PSMotion.springGentle.delay(0.5)) {
                showCompletion = true
            }
        } else {
            // Intermediate step complete
            let nextNum = currentStepIndex + 1
            let phrase = "Great job! Step \(currentStepIndex + 1) complete. Let's move on."
            speakStep(phrase)
            PSHaptics.shared.success()
            withAnimation(reduceMotion ? .none : PSMotion.springDefault) {
                currentStepIndex = nextNum
            }
        }
    }

    private func advanceStep() {
        guard currentStepIndex < totalSteps - 1 else {
            withAnimation(reduceMotion ? .none : PSMotion.springBouncy) { dragOffset = 0 }
            return
        }
        PSHaptics.shared.swipeThreshold()
        withAnimation(reduceMotion ? .none : PSMotion.springDefault) {
            currentStepIndex += 1
            dragOffset = 0
        }
    }

    private func retreatStep() {
        guard currentStepIndex > 0 else {
            withAnimation(reduceMotion ? .none : PSMotion.springBouncy) { dragOffset = 0 }
            return
        }
        PSHaptics.shared.swipeThreshold()
        withAnimation(reduceMotion ? .none : PSMotion.springDefault) {
            currentStepIndex -= 1
            dragOffset = 0
        }
    }

    private func resetTimer() {
        timerElapsed = 0
        timerRunning = false
    }

    private func maybeShowFunFact() {
        guard currentStepIndex > 0 else { return }
        funFactText = foodFacts.randomElement() ?? ""
        withAnimation(.easeInOut(duration: 0.4)) { showFunFact = true }
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run { withAnimation(.easeInOut(duration: 0.4)) { showFunFact = false } }
        }
    }

    // MARK: - Voice Chef

    /// Speaks a step using the selected voice type.
    ///
    /// Text is broken at natural clause boundaries (commas, colons, dashes) and
    /// each piece is queued as a **separate** `AVSpeechUtterance` with its own
    /// micro-pause. The synthesis engine then plays them back-to-back, producing
    /// authentic human-like phrasing instead of a flat robotic stream.
    ///
    /// A cyclic ±2 % rate nudge per chunk further breaks the monotone pattern.
    private func speakStep(_ text: String) {
        guard voiceEnabled else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)

        let chunks = humanChunks(from: text)
        let resolvedVoice = selectedVoiceType.makeVoice()
        // Rate nudge cycle: slight variation makes each clause feel more natural
        let nudgeCycle: [Float] = [0.00, 0.020, -0.015, 0.010, -0.020]
        var estimatedDuration: TimeInterval = 0

        for (i, chunk) in chunks.enumerated() {
            let u = AVSpeechUtterance(string: chunk)
            u.voice           = resolvedVoice
            u.rate            = max(AVSpeechUtteranceMinimumSpeechRate,
                                    min(AVSpeechUtteranceMaximumSpeechRate,
                                        selectedVoiceType.rate + nudgeCycle[i % nudgeCycle.count]))
            u.pitchMultiplier = selectedVoiceType.pitch
            u.volume          = selectedVoiceType.volume
            // First chunk: longer breath-in pause; subsequent: short clause gap
            u.preUtteranceDelay  = i == 0 ? 0.22 : 0.07
            u.postUtteranceDelay = i == chunks.count - 1 ? 0.30 : 0.09
            speechSynthesizer.speak(u)

            let words = Double(chunk.split(separator: " ").count)
            let wps   = 2.8 * Double(u.rate / AVSpeechUtteranceDefaultSpeechRate)
            estimatedDuration += (words / wps)
                + Double(u.preUtteranceDelay)
                + Double(u.postUtteranceDelay)
        }

        withAnimation { isSpeaking = true }
        Task {
            try? await Task.sleep(for: .seconds(estimatedDuration + 0.7))
            await MainActor.run { withAnimation { isSpeaking = false } }
        }
    }

    /// Splits text at punctuation-based clause boundaries so each piece
    /// becomes its own utterance, giving the Voice Chef natural human rhythm.
    ///
    /// Very short trailing fragments (≤2 words) are merged back into their
    /// predecessor to avoid awkward micro-clips.
    private func humanChunks(from text: String) -> [String] {
        var raw: [String] = []
        var current = ""

        for ch in text {
            current.append(ch)
            if ",.;:—–".contains(ch) {
                let t = current.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { raw.append(t) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { raw.append(tail) }

        // Merge orphaned short fragments into the previous chunk
        var merged: [String] = []
        for chunk in raw {
            if chunk.split(separator: " ").count <= 2, !merged.isEmpty {
                merged[merged.count - 1] += " " + chunk
            } else {
                merged.append(chunk)
            }
        }
        return merged.isEmpty ? [text] : merged
    }

    /// Wraps a raw step string with natural, contextual phrasing so the Voice Chef
    /// sounds conversational rather than mechanical.
    private func humanPhrase(for step: String, index: Int) -> String {
        let lower = step.lowercased()

        if index == 0 {
            let openers = [
                "Alright, let's get cooking! First up: \(step)",
                "Let's begin! Here's what to do first: \(step)",
                "Great, let's start! \(step)"
            ]
            return openers[abs(recipe.title.hashValue) % openers.count]
        }

        if index == totalSteps - 1 {
            let closers = [
                "Almost done! For the final step: \(step)",
                "You're so close! Last one — \(step)",
                "Home stretch! \(step)"
            ]
            return closers[index % closers.count]
        }

        if lower.contains("heat") || lower.contains("preheat") {
            return "Now go ahead and \(step.prefix(1).lowercased())\(step.dropFirst())"
        }
        if lower.contains("add") || lower.contains("pour") || lower.contains("place") {
            return "Next, \(step)"
        }
        if lower.contains("stir") || lower.contains("mix") || lower.contains("whisk") {
            return "Time to \(step.prefix(1).lowercased())\(step.dropFirst())"
        }
        if lower.contains("season") || lower.contains("taste") {
            return "Here's where the magic happens — \(step)"
        }
        if lower.contains("rest") || lower.contains("wait") || lower.contains("cool") {
            return "Take a moment — \(step)"
        }
        if lower.contains("serve") || lower.contains("plate") || lower.contains("garnish") {
            return "Almost there! \(step)"
        }
        if lower.contains("chop") || lower.contains("slice") || lower.contains("dice") {
            return "Prep time — \(step)"
        }

        let generics = [
            "Moving on — \(step)",
            "For step \(index + 1): \(step)",
            "Now, \(step)",
            "Keep it up! \(step)",
            "Great work so far. \(step)"
        ]
        return generics[index % generics.count]
    }

    // MARK: - Step Duration Estimation

    private func estimatedDuration(for step: String) -> Int {
        let lower = step.lowercased()
        if let range = lower.range(of: #"(\d+)\s*min"#, options: .regularExpression) {
            let match = String(lower[range])
            let digits = match.filter { $0.isNumber }
            if let minutes = Int(digits) { return minutes * 60 }
        }
        if lower.contains("boil") || lower.contains("simmer") { return 300 }
        if lower.contains("bake") || lower.contains("oven") { return 1200 }
        if lower.contains("marinate") { return 900 }
        if lower.contains("rest") || lower.contains("cool") { return 120 }
        if lower.contains("fry") || lower.contains("sauté") || lower.contains("sear") { return 240 }
        if lower.contains("chop") || lower.contains("dice") || lower.contains("slice") { return 120 }
        if lower.contains("mix") || lower.contains("stir") || lower.contains("whisk") { return 60 }
        return 180
    }
}

// MARK: - Music Service Button

private struct MusicServiceButton: View {
    let icon: String
    let name: String
    let accentColor: Color
    let urlString: String
    var fallbackURLString: String? = nil

    var body: some View {
        Button {
            let primary = URL(string: urlString)
            let canOpenPrimary = primary.map { UIApplication.shared.canOpenURL($0) } ?? false

            if canOpenPrimary, let url = primary {
                UIApplication.shared.open(url)
            } else if let fallback = fallbackURLString, let url = URL(string: fallback) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: PSSpacing.md) {
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: PSLayout.scaled(44), height: PSLayout.scaled(44))
                    Image(systemName: icon)
                        .font(.system(size: PSLayout.scaledFont(20), weight: .medium))
                        .foregroundStyle(accentColor)
                }

                Text(name)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("Open")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, PSSpacing.md)
                    .padding(.vertical, PSSpacing.xs)
                    .background(accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSSpacing.md)
            .background(.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
