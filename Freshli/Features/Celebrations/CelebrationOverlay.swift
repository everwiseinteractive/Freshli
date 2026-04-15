import SwiftUI

// MARK: - CelebrationOverlay
// Master overlay that sits at the ROOT ZStack level (above all navigation bars and tab bars)
// and renders the active celebration without clipping.
// Routes each CelebrationType to its correct view implementation.

struct CelebrationOverlay: View {
    @Bindable var manager: CelebrationManager
    var useFreshliCelebrations: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var celebrationNamespace

    /// Animated blur intensity for celebration backdrop (0 → 1 over 0.5s)
    @State private var blurIntensity: CGFloat = 0

    var body: some View {
        ZStack {
            if let celebration = manager.activeCelebration {
                // Visual Effect Blur backdrop — animates intensity from 0 to 1 over 0.5s
                // Only for medium/hero celebrations (not toasts)
                if celebration.intensity != .small {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(blurIntensity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .onAppear {
                            if !reduceMotion {
                                withAnimation(FLMotion.freshliCurve) {
                                    blurIntensity = 1.0
                                }
                            } else {
                                blurIntensity = 1.0
                            }
                        }
                        .onDisappear {
                            blurIntensity = 0
                        }
                }

                Group {
                    if useFreshliCelebrations && celebration.intensity != .small {
                        // Enhanced Freshli celebration with Canvas particles + spatial audio
                        FreshliCelebrationView(
                            type: celebration,
                            namespace: celebrationNamespace,
                            onDismiss: { manager.dismissCelebration() }
                        )
                    } else {
                        // Original celebration system for toasts and fallback
                        legacyCelebrationView(for: celebration)
                    }
                }
                .transition(celebrationTransition(for: celebration))
                .zIndex(100)
                // Ensure celebrations appear ABOVE Dynamic Island and Home Indicator
                .ignoresSafeArea(.all)
            }
        }
        .animation(
            reduceMotion ? .none : FLMotion.freshliCurve,
            value: manager.activeCelebration?.id
        )
    }

    @ViewBuilder
    private func legacyCelebrationView(for celebration: CelebrationType) -> some View {
        switch celebration {
        // Small toast celebrations
        case .recipeMatchSuccess:
            ToastCelebrationView(
                type: celebration,
                onDismiss: { manager.dismissCelebration() }
            )
            .accessibilityLabel(String(localized: "Recipe match celebration"))

        // Streak celebrations
        case .expiryRescueStreak(let count):
            StreakCelebrationView(
                streakCount: count,
                onDismiss: { manager.dismissCelebration() }
            )

        // Milestone / Achievement / Community celebrations
        case .impactMilestone, .achievementUnlock, .communityImpact:
            MilestoneCelebrationView(
                type: celebration,
                onDismiss: { manager.dismissCelebration() }
            )

        // Weekly Recap
        case .weeklyRecap(let saved, let shared, let co2, let money):
            WeeklyRecapView(
                saved: saved,
                shared: shared,
                co2: co2,
                money: money,
                onDismiss: { manager.dismissCelebration() }
            )

        // Standard celebrations (First Item, Food Saved, Share, Donate)
        default:
            StandardCelebrationView(
                type: celebration,
                onDismiss: { manager.dismissCelebration() }
            )
        }
    }

    private func celebrationTransition(for type: CelebrationType) -> AnyTransition {
        switch type.intensity {
        case .small:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.85))
            )
        case .medium, .hero:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.85)),
                removal: .opacity
                    .combined(with: .scale(scale: 1.12))
                    .combined(with: .offset(y: -30))
            )
        }
    }
}

// MARK: - View Extension for Easy Integration
// Uses a root-level ZStack instead of .overlay to ensure celebrations
// appear ABOVE all navigation bars and tab bars without clipping.

extension View {
    func celebrationOverlay(manager: CelebrationManager) -> some View {
        ZStack {
            self
            CelebrationOverlay(manager: manager)
        }
    }
}
