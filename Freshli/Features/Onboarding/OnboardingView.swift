import SwiftUI

// Figma: Onboarding — 3 steps, AnimatePresence mode="wait", bouncy springs
// w-40 h-40 rounded-[2.5rem] icon container with border-4 border-white
// Floating Sparkles decorative element, text-4xl font-black title
// Full-width CTA with step color, progress dots with layoutId

private struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let lightColor: Color
}

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var blobVisible = false
    @State private var iconRotation: Double = 0
    @State private var celebrateTrigger = false
    @State private var collectiveImpact = CollectiveImpactService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Three slides, one story: pain → magic → belonging. The copy goes
    // from concrete personal cost, to the signature on-device AI feature,
    // to the sense of joining something bigger. Each slide tries to earn
    // the user's attention with a fact they will actually remember by the
    // time they're standing in front of their fridge.

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: String(localized: "£700 of food, gone each year."),
            description: String(localized: "That's what the average household throws in the bin. Freshli tracks every item in your fridge, tells you what's about to go off, and helps you rescue it before it's too late."),
            icon: "leaf.fill",
            color: PSColors.primaryGreen,
            lightColor: PSColors.emeraldLight
        ),
        OnboardingStep(
            title: String(localized: "Rescue Chef, on your phone."),
            description: String(localized: "Tap one button and Apple Intelligence writes recipes for your exact pantry — on-device, private, no internet needed. Never stare at a wilting vegetable again."),
            icon: "sparkles",
            color: PSColors.secondaryAmber,
            lightColor: Color(hex: 0xFEF3C7)
        ),
        OnboardingStep(
            title: String(localized: "You're not rescuing alone."),
            description: String(localized: "Thousands of people are saving food alongside you right now — share surplus, donate to a community fridge, watch your impact climb. Every meal rescued is one less in a landfill."),
            icon: "person.2.fill",
            color: PSColors.infoBlue,
            lightColor: Color(hex: 0xDBEAFE)
        ),
    ]

    var body: some View {
        let step = steps[currentStep]

        ZStack {
            // Figma: step bg color (e.g., bg-green-50) — fuller opacity
            step.lightColor.opacity(0.6)
                .ignoresSafeArea()

            // Figma: 150vw blur-3xl decorative blob with entrance animation
            Circle()
                .fill(step.lightColor)
                .frame(width: ScreenMetrics.bounds.width * 1.5,
                       height: ScreenMetrics.bounds.width * 1.5)
                .blur(radius: 80)
                // Figma: animate: { opacity: 0.4 }
                .opacity(blobVisible ? 0.4 : 0)
                .scaleEffect(blobVisible ? 1 : 0.6)
                .offset(x: ScreenMetrics.bounds.width * 0.37,
                         y: -ScreenMetrics.bounds.width * 0.37)

            VStack {
                Spacer()

                // Figma: AnimatePresence mode="wait" — content block
                VStack(spacing: 0) {
                    // Figma: Icon container w-40 h-40 rounded-[2.5rem] with border-4 border-white
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                            .fill(step.lightColor)
                            .adaptiveFrame(width: 160, height: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                                    .strokeBorder(.white, lineWidth: 4)
                            )
                            .elevation(.z4)
                            .overlay {
                                Image(systemName: step.icon)
                                    .font(.system(size: PSLayout.scaledFont(72), weight: .regular))
                                    .foregroundStyle(step.color)
                                    .rotationEffect(.degrees(iconRotation))
                            }

                        // Figma: floating Sparkles decorative element
                        Image(systemName: "sparkles")
                            .font(.system(size: PSLayout.scaledFont(20), weight: .semibold))
                            .foregroundStyle(.white)
                            .adaptiveFrame(width: 48, height: 48)
                            .background(step.color)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .elevation(.z2)
                            .offset(x: PSLayout.scaled(-40), y: PSLayout.scaled(-20))
                    }
                    .padding(.bottom, PSLayout.scaled(48))

                    // Figma: text-4xl font-black tracking-tight (2.25rem = 36px)
                    Text(step.title)
                        .font(.system(size: 34, weight: .black))
                        .tracking(-0.5)
                        .foregroundStyle(PSColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                        .padding(.bottom, PSSpacing.lg)

                    // Figma: text-lg font-medium text-neutral-600
                    Text(step.description)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .minimumScaleFactor(0.85)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .id(currentStep) // triggers animation on step change
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)).combined(with: .offset(y: 40)),
                    removal: .opacity.combined(with: .scale(scale: 1.1)).combined(with: .offset(y: -40))
                ))

                Spacer()

                // Figma: bottom section — progress dots + CTA
                VStack(spacing: PSLayout.scaled(40)) {
                    // Figma: inactive w-2.5 h-2.5 bg-neutral-200, active w-8 h-2.5 step color
                    HStack(spacing: 12) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentStep ? step.color : PSColors.neutral200)
                                .frame(width: index == currentStep ? 32 : 10, height: 10)
                                .flAnimation(PSMotion.springBouncy, value: currentStep)
                        }
                    }

                    // Figma: full-width CTA with step color, rounded-[1.25rem], py-5, font-bold text-xl
                    Button {
                        PSHaptics.shared.mediumTap()
                        if currentStep < steps.count - 1 {
                            withAnimation(FLMotion.adaptive(PSMotion.springBouncy, reduceMotion: reduceMotion)) {
                                currentStep += 1
                            }
                        } else {
                            // Final-slide commit moment: success haptic
                            // instead of a light tap because this is the
                            // user crossing the threshold into the app.
                            PSHaptics.shared.success()
                            AnalyticsService.shared.track(.onboardingCompleted)
                            celebrateTrigger = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                onComplete()
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            // The final-slide label is a commitment, not a
                            // generic "Get Started" — the user is saying
                            // YES to rescuing food. The phrasing matters.
                            Text(currentStep == steps.count - 1
                                 ? String(localized: "Start Rescuing")
                                 : String(localized: "Continue"))
                                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))

                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .bold))
                            } else {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 16, weight: .bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: PSLayout.scaled(64))
                        .background(step.color)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                        .shadow(color: step.color.opacity(0.3), radius: 20, y: 8)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .accessibilityHint(
                        currentStep == steps.count - 1
                            ? String(localized: "Opens Freshli")
                            : String(localized: "Goes to the next onboarding slide")
                    )

                    // Live "rescue wave" ticker — social proof that the
                    // user is joining something already in motion. The
                    // counter ticks live while they read the slides, so
                    // by the time they tap Start Rescuing there's a
                    // felt sense of urgency and community.
                    liveRescueTicker(stepColor: step.color)
                }
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .padding(.bottom, PSLayout.screenHeight * 0.05)
            }
        }
        .flAnimation(PSMotion.springDefault, value: currentStep)
        .celebrationPop(trigger: $celebrateTrigger)
        .sensoryFeedback(.selection, trigger: currentStep)
        // Figma: initial rotate -20°, animate to 0 with springs.bouncy delay 0.2
        .onAppear {
            AnalyticsService.shared.track(.onboardingStarted)
            AnalyticsService.shared.track(.onboardingSlideViewed, properties: .props([
                "slide_index": currentStep
            ]))
            if reduceMotion {
                blobVisible = true
                iconRotation = 0
            } else {
                withAnimation(PSMotion.springGentle) {
                    blobVisible = true
                }
                withAnimation(PSMotion.springBouncy.delay(0.2)) {
                    iconRotation = -20
                }
                withAnimation(PSMotion.springBouncy.delay(0.5)) {
                    iconRotation = 0
                }
            }
        }
        // Figma: icon re-enters each step with rotate -20 → 0
        .onChange(of: currentStep) { _, newStep in
            AnalyticsService.shared.track(.onboardingSlideViewed, properties: .props([
                "slide_index": newStep
            ]))
            if !reduceMotion {
                iconRotation = -20
                withAnimation(PSMotion.springBouncy.delay(0.1)) {
                    iconRotation = 0
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Onboarding step \(currentStep + 1) of \(steps.count)"))
    }

    // MARK: - Live Rescue Ticker
    //
    // A small, unobtrusive row pinned below the CTA that pulls from the
    // existing CollectiveImpactService — the same service that powers the
    // Home tab's Collective Wave card. The count ticks in real time
    // while the user reads the slides, so by the time they decide to tap
    // "Start Rescuing" there's a felt sense of momentum: thousands of
    // other people are doing this right now, join them.

    @ViewBuilder
    private func liveRescueTicker(stepColor: Color) -> some View {
        HStack(spacing: PSSpacing.sm) {
            // Pulsing live dot
            Circle()
                .fill(PSColors.primaryGreen)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(PSColors.primaryGreen.opacity(0.4))
                        .frame(width: 16, height: 16)
                        .scaleEffect(blobVisible ? 1.4 : 0.8)
                        .opacity(blobVisible ? 0 : 0.6)
                )

            Text(liveTickerMessage)
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(PSColors.textSecondary)
                .contentTransition(.numericText())
                .compositingGroup()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.top, PSSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(liveTickerAccessibilityLabel)
    }

    private var liveTickerMessage: String {
        let count = collectiveImpact.rescuesThisHour
        if count > 0 {
            return String(localized: "\(collectiveImpact.rescueCountDisplay) rescues in the last hour")
        }
        return String(localized: "Join the rescue wave")
    }

    private var liveTickerAccessibilityLabel: String {
        let count = collectiveImpact.rescuesThisHour
        if count > 0 {
            return String(localized: "\(count) people rescued food in the last hour")
        }
        return String(localized: "Join the rescue wave")
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
