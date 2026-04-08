import SwiftUI

// MARK: - CelebrationOverlay
// Master overlay that sits at the app root level and renders the active celebration
// Routes each CelebrationType to its correct view implementation

struct CelebrationOverlay: View {
    @Bindable var manager: CelebrationManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let celebration = manager.activeCelebration {
                Group {
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
                .transition(celebrationTransition(for: celebration))
                .zIndex(100)
                // Ensure celebration stays within safe area bounds on all devices
                .ignoresSafeArea(.keyboard)
            }
        }
        .animation(
            reduceMotion ? .none : PSMotion.springBouncy,
            value: manager.activeCelebration?.id
        )
    }

    private func celebrationTransition(for type: CelebrationType) -> AnyTransition {
        switch type.intensity {
        case .small:
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .opacity.combined(with: .scale(scale: 0.9))
            )
        case .medium, .hero:
            return .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.9)),
                removal: .opacity.combined(with: .scale(scale: 1.05))
            )
        }
    }
}

// MARK: - View Extension for Easy Integration

extension View {
    func celebrationOverlay(manager: CelebrationManager) -> some View {
        self.overlay {
            CelebrationOverlay(manager: manager)
        }
    }
}
