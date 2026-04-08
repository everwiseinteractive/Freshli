import SwiftUI

// MARK: - Animated Progress Ring
// Premium circular progress indicator with spring-animated fill.

struct PSProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    init(progress: Double, lineWidth: CGFloat = 6, color: Color = PSColors.primaryGreen, size: CGFloat = 48) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityValue("\(Int(animatedProgress * 100))%")
        .onAppear {
            withAnimation(PSMotion.springGentle.delay(0.3)) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(PSMotion.springDefault) {
                animatedProgress = min(newValue, 1.0)
            }
        }
    }
}

// MARK: - Progress Ring with Label

struct PSProgressRingLabeled: View {
    let progress: Double
    let value: String
    let label: String
    let color: Color
    let size: CGFloat

    init(progress: Double, value: String, label: String, color: Color = PSColors.primaryGreen, size: CGFloat = 64) {
        self.progress = progress
        self.value = value
        self.label = label
        self.color = color
        self.size = size
    }

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            ZStack {
                PSProgressRing(progress: progress, lineWidth: 5, color: color, size: size)

                Text(value)
                    .font(.system(size: PSLayout.scaledFont(size * 0.28), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
            }

            Text(label)
                .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
