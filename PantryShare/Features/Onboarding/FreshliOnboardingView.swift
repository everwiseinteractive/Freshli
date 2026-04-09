import SwiftUI

// MARK: - Freshli Onboarding Flow
// Full onboarding experience: 3 narrative pages → Sign in with Apple → Permissions → Zoom-out reveal.
// Uses a paging TabView with morphing backgrounds and custom SwiftUI animations.

enum OnboardingPhase: Equatable {
    case pages       // 3 narrative screens
    case signIn      // Sign in with Apple
    case permissions // Notification + Location requests
    case complete    // Zoom-out transition
}

struct FreshliOnboardingView: View {
    @Environment(AuthManager.self) private var authManager
    var onComplete: () -> Void

    @State private var phase: OnboardingPhase = .pages
    @State private var currentPage: Int = 0
    @State private var morphProgress: CGFloat = 0
    @State private var zoomOut = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Morphing background (visible during pages phase)
            if phase == .pages {
                OnboardingMorphBackground(page: currentPage, morphProgress: morphProgress)
                    .transition(.opacity)
            } else if phase != .complete {
                // Static background for sign-in and permissions
                PSColors.green50.ignoresSafeArea()
                    .transition(.opacity)

                // Subtle decorative blobs
                Circle()
                    .fill(PSColors.emeraldLight)
                    .frame(width: PSLayout.scaled(300), height: PSLayout.scaled(300))
                    .blur(radius: PSLayout.scaled(100))
                    .opacity(0.3)
                    .offset(x: PSLayout.scaled(120), y: PSLayout.scaled(-200))
                    .transition(.opacity)
            }

            // Content phases
            switch phase {
            case .pages:
                pagesView
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

            case .signIn:
                OnboardingSignInView(
                    onSignedIn: {
                        advanceTo(.permissions)
                    },
                    onSkip: {
                        authManager.skipAuth()
                        advanceTo(.permissions)
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .permissions:
                OnboardingPermissionsView {
                    advanceTo(.complete)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

            case .complete:
                // This phase triggers the zoom-out; the parent view handles the actual reveal
                Color.clear
            }
        }
        .animation(PSMotion.springDefault, value: phase)
        // Zoom-out scale when completing
        .scaleEffect(zoomOut ? 0.85 : 1.0)
        .opacity(zoomOut ? 0 : 1)
        .onChange(of: phase) { _, newPhase in
            if newPhase == .complete {
                triggerZoomOut()
            }
        }
    }

    // MARK: - Paging View

    private var pagesView: some View {
        VStack(spacing: 0) {
            // Paging TabView
            TabView(selection: $currentPage) {
                KitchenOptimizedPage()
                    .tag(0)

                SavingsImpactPage()
                    .tag(1)

                CommunityMapPage()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentPage) { oldValue, newValue in
                PSHaptics.shared.selection()
                withAnimation(PSMotion.springDefault) {
                    morphProgress = CGFloat(newValue)
                }
            }

            // Bottom controls
            VStack(spacing: PSLayout.scaled(32)) {
                // Page indicator dots
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? pageColor(for: currentPage) : PSColors.neutral200)
                            .frame(width: index == currentPage ? 32 : 10, height: 10)
                            .animation(PSMotion.springBouncy, value: currentPage)
                    }
                }

                // Continue / Get Started button
                Button {
                    PSHaptics.shared.mediumTap()
                    if currentPage < 2 {
                        withAnimation(PSMotion.springBouncy) {
                            currentPage += 1
                        }
                    } else {
                        PSHaptics.shared.celebrate()
                        advanceTo(.signIn)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentPage == 2
                             ? String(localized: "Get Started")
                             : String(localized: "Continue"))
                            .font(.system(size: PSLayout.scaledFont(20), weight: .bold))

                        if currentPage < 2 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: PSLayout.scaled(64))
                    .background(pageColor(for: currentPage))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                    .shadow(color: pageColor(for: currentPage).opacity(0.3), radius: 20, y: 8)
                }
                .buttonStyle(PressableButtonStyle())
                .animation(PSMotion.springDefault, value: currentPage)

                // Skip for pages
                if currentPage < 2 {
                    Button {
                        PSHaptics.shared.lightTap()
                        advanceTo(.signIn)
                    } label: {
                        Text(String(localized: "Skip"))
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .padding(.bottom, PSLayout.scaled(48))
        }
    }

    // MARK: - Helpers

    private func pageColor(for page: Int) -> Color {
        switch page {
        case 0: return PSColors.primaryGreen
        case 1: return PSColors.secondaryAmber
        default: return PSColors.infoBlue
        }
    }

    private func advanceTo(_ newPhase: OnboardingPhase) {
        withAnimation(PSMotion.springDefault) {
            phase = newPhase
        }
    }

    private func triggerZoomOut() {
        if reduceMotion {
            onComplete()
            return
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            zoomOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Zoom-Out Reveal Modifier
// Applied to the home dashboard to animate its entrance when onboarding completes.

struct ZoomRevealModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && !reduceMotion ? 1.15 : 1.0)
            .opacity(isActive ? 0 : 1)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.4), value: isActive)
    }
}

extension View {
    func zoomReveal(isHidden: Bool) -> some View {
        modifier(ZoomRevealModifier(isActive: isHidden))
    }
}

#Preview {
    FreshliOnboardingView(onComplete: {})
        .environment(AuthManager())
}
