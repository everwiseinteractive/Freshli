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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: String(localized: "Welcome to PantryShare"),
            description: String(localized: "Your digital kitchen assistant to organize, cook, and share."),
            icon: "leaf.fill",
            color: PSColors.primaryGreen,
            lightColor: PSColors.emeraldLight
        ),
        OnboardingStep(
            title: String(localized: "Track Your Ingredients"),
            description: String(localized: "Never buy duplicates. Know exactly what's in your pantry anytime."),
            icon: "birthday.cake.fill",
            color: PSColors.secondaryAmber,
            lightColor: Color(hex: 0xFEF3C7)
        ),
        OnboardingStep(
            title: String(localized: "Cook & Connect"),
            description: String(localized: "Discover recipes based on what you have and share with the community."),
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
                .frame(width: UIScreen.main.bounds.width * 1.5,
                       height: UIScreen.main.bounds.width * 1.5)
                .blur(radius: 80)
                // Figma: animate: { opacity: 0.4 }
                .opacity(blobVisible ? 0.4 : 0)
                .scaleEffect(blobVisible ? 1 : 0.6)
                .offset(x: UIScreen.main.bounds.width * 0.37,
                         y: -UIScreen.main.bounds.width * 0.37)

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
                            .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
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
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
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
                }
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
                                .animation(PSMotion.springBouncy, value: currentStep)
                        }
                    }

                    // Figma: full-width CTA with step color, rounded-[1.25rem], py-5, font-bold text-xl
                    Button {
                        PSHaptics.shared.mediumTap()
                        if currentStep < steps.count - 1 {
                            withAnimation(PSMotion.springBouncy) {
                                currentStep += 1
                            }
                        } else {
                            PSHaptics.shared.celebrate()
                            onComplete()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(currentStep == steps.count - 1
                                 ? String(localized: "Get Started")
                                 : String(localized: "Continue"))
                                .font(.system(size: PSLayout.scaledFont(20), weight: .bold))

                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
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
                }
                .padding(.horizontal, PSLayout.formHorizontalPadding)
                .padding(.bottom, PSLayout.scaled(48))
            }
        }
        .animation(PSMotion.springDefault, value: currentStep)
        // Figma: initial rotate -20°, animate to 0 with springs.bouncy delay 0.2
        .onAppear {
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
        .onChange(of: currentStep) { _, _ in
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
}

#Preview {
    OnboardingView(onComplete: {})
}
