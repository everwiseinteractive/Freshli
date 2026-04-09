import SwiftUI

// Figma: Stat count-up animation — numbers animate from 0 to target
// Uses AnimatableModifier for smooth interpolation
// Response: springDefault timing for rewarding reveal

struct CelebrationCountUpText: View {
    let targetValue: Double
    let format: String
    var prefix: String = ""
    var suffix: String = ""
    var font: Font = .system(size: 48, weight: .black, design: .rounded)
    var color: Color = .white
    var delay: Double = 0

    @State private var animatedValue: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            if !prefix.isEmpty {
                Text(prefix)
                    .font(font)
                    .foregroundStyle(color.opacity(0.7))
            }

            Text(formattedValue)
                .font(font)
                .foregroundStyle(color)
                .contentTransition(.numericText(value: animatedValue))
                .monospacedDigit()

            if !suffix.isEmpty {
                Text(suffix)
                    .font(font)
                    .foregroundStyle(color.opacity(0.7))
            }
        }
        .onAppear {
            if reduceMotion {
                animatedValue = targetValue
            } else {
                withAnimation(.easeOut(duration: 1.2).delay(delay)) {
                    animatedValue = targetValue
                }
            }
        }
    }

    private var formattedValue: String {
        String(format: format, animatedValue)
    }
}

// MARK: - Convenience Initializers

extension CelebrationCountUpText {
    /// Integer count-up (e.g. "42")
    static func integer(
        _ value: Int,
        font: Font = .system(size: 48, weight: .black, design: .rounded),
        color: Color = .white,
        delay: Double = 0
    ) -> CelebrationCountUpText {
        CelebrationCountUpText(
            targetValue: Double(value),
            format: "%.0f",
            font: font,
            color: color,
            delay: delay
        )
    }

    /// Currency count-up (e.g. "$142")
    static func currency(
        _ value: Double,
        font: Font = .system(size: 48, weight: .black, design: .rounded),
        color: Color = .white,
        delay: Double = 0
    ) -> CelebrationCountUpText {
        CelebrationCountUpText(
            targetValue: value,
            format: "%.0f",
            prefix: "$",
            font: font,
            color: color,
            delay: delay
        )
    }

    /// Weight count-up (e.g. "12.5kg")
    static func weight(
        _ value: Double,
        font: Font = .system(size: 48, weight: .black, design: .rounded),
        color: Color = .white,
        delay: Double = 0
    ) -> CelebrationCountUpText {
        CelebrationCountUpText(
            targetValue: value,
            format: "%.1f",
            suffix: "kg",
            font: font,
            color: color,
            delay: delay
        )
    }
}
