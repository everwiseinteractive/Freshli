import SwiftUI

// MARK: - Predictive Surface Card
//
// The "living" card on the Home screen that uses Apple Intelligence
// to predict the user's next action. Powered by:
//
//   1. IntentPredictionService — heuristic + Foundation Models layer
//   2. predictiveSurface Metal shader — GPU-driven glow and morphing
//   3. Ghost State pattern — translucent when uncertain, blooms when confident
//
// The card breathes, glows, and subtly morphs its geometry in real-time,
// intensity scaling from whisper-quiet to vivid as the model's confidence
// grows. When the user taps, the app navigates to the predicted action.
//
// Privacy: all prediction runs on-device. No data leaves the phone.

struct PredictiveSurfaceCard: View {
    let predictionService: IntentPredictionService
    var switchToTab: (AppTab) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var isPulsing = false

    /// Metal shader confidence — drives glow intensity + morph amplitude.
    private var shaderConfidence: Float {
        predictionService.predictions.first?.confidence ?? 0
    }

    /// Whether we have a strong enough prediction to show the card.
    private var hasPrediction: Bool {
        predictionService.topIntent != nil && shaderConfidence >= 0.35
    }

    var body: some View {
        if hasPrediction {
            Button {
                PSHaptics.shared.mediumTap()
                navigateToPrediction()
            } label: {
                cardContent
            }
            .buttonStyle(PressableButtonStyle())
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(PSMotion.springBouncy.delay(0.2)) {
                    appeared = true
                }
            }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: PSSpacing.lg) {
            // Prediction icon — pulsing with AI glow
            Image(systemName: predictionService.topIntentIcon)
                .font(.system(size: PSLayout.scaledFont(26), weight: .semibold))
                .foregroundStyle(predictionService.topIntentColor)
                .symbolEffect(.breathe.pulse, isActive: !reduceMotion)
                .frame(width: PSLayout.scaled(48), height: PSLayout.scaled(48))

            VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                // Apple Intelligence badge
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: PSLayout.scaledFont(10), weight: .bold))
                    Text(String(localized: "Freshli Intelligence"))
                        .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundStyle(FLColors.aiGlow)

                // Prediction title
                Text(predictionService.topIntentTitle)
                    .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)

                // AI reasoning
                if !predictionService.topPredictionReason.isEmpty {
                    Text(predictionService.topPredictionReason)
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(PSSpacing.cardPadding)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(
                    predictionService.topIntentColor.opacity(Double(shaderConfidence) * 0.25),
                    lineWidth: 1
                )
        )
        // Metal 4 predictive surface shader — glow + geometry morph
        .metalPredictiveSurface(
            confidence: shaderConfidence,
            color: predictionService.topIntentColor
        )
        .elevation(.z2)
    }

    // MARK: - Navigation

    private func navigateToPrediction() {
        guard let intent = predictionService.topIntent else { return }

        // Record the action for pattern learning
        predictionService.recordAction(intent)

        switch intent {
        case .rescueFood, .checkRecipes:
            switchToTab(.recipes)
        case .addItems, .managePantry:
            switchToTab(.pantry)
        case .shareFood:
            switchToTab(.community)
        case .viewImpact:
            // Impact is accessible from profile
            switchToTab(.profile)
        }
    }
}
