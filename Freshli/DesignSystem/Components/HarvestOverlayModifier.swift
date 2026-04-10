import SwiftUI

/// HarvestOverlayModifier applies a harvest celebration effect to any view.
/// When triggered, displays sparkles + haptic feedback + floating "+1 Saved!" text.
struct HarvestOverlayModifier: ViewModifier {
    let isActive: Binding<Bool>
    let intensity: SparkleIntensity
    @State private var showSavedText = false
    @State private var savedTextOffset: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack {
            content

            // Overlay: Sparkle animation + floating text
            if isActive.wrappedValue {
                ZStack(alignment: .center) {
                    // Sparkle particles
                    SparkleAnimationView(intensity: intensity)

                    // Floating "+1 Saved!" text
                    if showSavedText {
                        VStack {
                            Text(String(localized: "+1 Saved!"))
                                .font(.system(size: PSLayout.scaledFont(18), weight: .bold))
                                .foregroundStyle(PSColors.primaryGreen)
                                .offset(y: savedTextOffset)
                                .opacity(max(0, 1.0 - (savedTextOffset / 40)))
                        }
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    startCelebration()
                }
            }
        }
    }

    // MARK: - Celebration Sequence

    private func startCelebration() {
        // Show floating text
        withAnimation(.easeOut(duration: 0.1)) {
            showSavedText = true
        }

        // Animate text upward and fade
        withAnimation(.easeOut(duration: 1.5).delay(0.1)) {
            savedTextOffset = -40
        }

        // Dismiss overlay after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                isActive.wrappedValue = false
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Applies harvest celebration overlay with sparkles and haptic feedback.
    /// - Parameters:
    ///   - isActive: Binding to trigger the celebration
    ///   - intensity: Particle intensity level (affects particle count and duration)
    func harvestCelebration(isActive: Binding<Bool>, intensity: SparkleIntensity = .standard) -> some View {
        modifier(HarvestOverlayModifier(isActive: isActive, intensity: intensity))
    }
}

// MARK: - Preview

#Preview("Harvest Celebration - Standard") {
    @Previewable @State var isActive = true

    ZStack {
        VStack {
            Text("Tap to trigger harvest")
                .font(.headline)
            Button("Celebrate!") {
                isActive = true
            }
        }
    }
    .harvestCelebration(isActive: $isActive, intensity: .standard)
}

#Preview("Harvest Celebration - Gentle") {
    @Previewable @State var isActive = true

    ZStack {
        VStack {
            Text("Gentle sparkle celebration")
                .font(.headline)
            Button("Trigger") {
                isActive = true
            }
        }
    }
    .harvestCelebration(isActive: $isActive, intensity: .gentle)
}
