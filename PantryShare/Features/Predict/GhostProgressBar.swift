import SwiftUI

// MARK: - FreshliGhostProgressBar

/// A translucent progress bar that sits behind pantry item rows,
/// showing predicted remaining quantity as a fill level.
/// The bar fades from green (full) through amber (mid) to red (depleted).
struct FreshliGhostProgressBar: View {
    let prediction: FreshliPrediction?
    var height: CGFloat = 4
    var cornerRadius: CGFloat = 2

    private var fraction: Double {
        prediction?.remainingFraction ?? 1.0
    }

    private var fillColor: Color {
        guard let prediction else { return PSColors.freshGreen }
        if prediction.isUrgent {
            return PSColors.expiredRed
        } else if prediction.isRunningLow {
            return PSColors.warningAmber
        } else {
            return PSColors.freshGreen
        }
    }

    private var trackColor: Color {
        fillColor.opacity(0.12)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(trackColor)
                    .frame(height: height)

                // Fill
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor.opacity(0.6))
                    .frame(width: max(0, geo.size.width * fraction), height: height)
                    .animation(PSMotion.springDefault, value: fraction)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Ghost Progress Bar Modifier

/// Attaches a ghost progress bar below a pantry item view.
struct FreshliGhostProgressModifier: ViewModifier {
    let prediction: FreshliPrediction?
    var showLabel: Bool = false

    func body(content: Content) -> some View {
        VStack(spacing: PSSpacing.xxs) {
            content

            if let prediction {
                VStack(spacing: PSSpacing.xxxs) {
                    FreshliGhostProgressBar(prediction: prediction)

                    if showLabel {
                        HStack {
                            ghostLabel(for: prediction)
                            Spacer()
                            if prediction.confidenceScore >= 0.5 {
                                confidenceDots(score: prediction.confidenceScore)
                            }
                        }
                    }
                }
                .padding(.horizontal, PSSpacing.xs)
                .transition(PSMotion.fadeSlide)
            }
        }
    }

    @ViewBuilder
    private func ghostLabel(for prediction: FreshliPrediction) -> some View {
        let days = prediction.estimatedDaysRemaining

        HStack(spacing: PSSpacing.xxxs) {
            Image(systemName: labelIcon(for: prediction))
                .font(.system(size: 9))
            Text(labelText(days: days, reason: prediction.reason))
                .font(PSTypography.caption2)
        }
        .foregroundStyle(labelColor(for: prediction))
    }

    private func labelIcon(for prediction: FreshliPrediction) -> String {
        switch prediction.reason {
        case .expiryBeforeDepletion:
            return "clock.badge.exclamationmark"
        case .depletionBeforeExpiry, .bothSameDay:
            return "chart.line.downtrend.xyaxis"
        case .noHistory:
            return "questionmark.circle"
        }
    }

    private func labelText(days: Int, reason: FreshliPredictionReason) -> String {
        if days <= 0 {
            switch reason {
            case .expiryBeforeDepletion: return String(localized: "Likely expired")
            case .depletionBeforeExpiry, .bothSameDay: return String(localized: "Likely empty")
            case .noHistory: return String(localized: "No usage data")
            }
        } else if days == 1 {
            switch reason {
            case .expiryBeforeDepletion: return String(localized: "Expires tomorrow")
            case .depletionBeforeExpiry, .bothSameDay: return String(localized: "~1 day left")
            case .noHistory: return String(localized: "~1 day (est.)")
            }
        } else {
            switch reason {
            case .expiryBeforeDepletion: return String(localized: "Expires in ~\(days)d")
            case .depletionBeforeExpiry, .bothSameDay: return String(localized: "~\(days)d remaining")
            case .noHistory: return String(localized: "~\(days)d (est.)")
            }
        }
    }

    private func labelColor(for prediction: FreshliPrediction) -> Color {
        if prediction.isUrgent {
            return PSColors.expiredRed
        } else if prediction.isRunningLow {
            return PSColors.warningAmber
        } else {
            return PSColors.textTertiary
        }
    }

    /// Confidence indicator: 1-3 filled dots
    @ViewBuilder
    private func confidenceDots(score: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < dotCount(for: score)
                          ? PSColors.textTertiary
                          : PSColors.textTertiary.opacity(0.25))
                    .frame(width: 4, height: 4)
            }
        }
        .accessibilityLabel(String(localized: "Confidence: \(Int(score * 100))%"))
    }

    private func dotCount(for score: Double) -> Int {
        if score >= 0.75 { return 3 }
        if score >= 0.5 { return 2 }
        return 1
    }
}

// MARK: - View Extension

extension View {
    /// Adds a ghost progress bar showing predicted remaining quantity for an item.
    func freshliGhostProgress(prediction: FreshliPrediction?, showLabel: Bool = false) -> some View {
        modifier(FreshliGhostProgressModifier(prediction: prediction, showLabel: showLabel))
    }
}
