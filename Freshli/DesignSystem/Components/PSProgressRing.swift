import SwiftUI

// MARK: - Animated Progress Ring
// Premium circular progress indicator with spring-animated fill
// and Metal GPU-powered breathing glow at the arc's leading edge.

struct PSProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let color: Color
    let size: CGFloat

    @State private var animatedProgress: Double = 0
    @State private var startDate = Date.now
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: Double, lineWidth: CGFloat = 6, color: Color = PSColors.primaryGreen, size: CGFloat = 48) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.color = color
        self.size = size
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = Float(timeline.date.timeIntervalSince(startDate))
            let resolved = resolveRingColor()

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
            .modifier(ProgressGlowShaderModifier(
                size: size,
                progress: animatedProgress,
                time: time,
                r: resolved.r,
                g: resolved.g,
                b: resolved.b
            ))
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

    private func resolveRingColor() -> (r: Float, g: Float, b: Float) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Float(r), Float(g), Float(b))
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

// MARK: - Safe Progress Glow Shader Modifier

private struct ProgressGlowShaderModifier: ViewModifier {
    let size: CGFloat
    let progress: Double
    let time: Float
    let r: Float
    let g: Float
    let b: Float

    func body(content: Content) -> some View {
        if ShaderWarmUpService.shadersAvailable {
            content
                .colorEffect(
                    ShaderLibrary.freshnessGlow(
                        .float2(Float(size), Float(size)),
                        .float(Float(progress)),
                        .float(time),
                        .float(r),
                        .float(g),
                        .float(b)
                    )
                )
                .drawingGroup()
        } else {
            content
        }
    }
}
