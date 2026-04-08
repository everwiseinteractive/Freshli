import SwiftUI

// Figma: SuccessCelebration confetti — 6 particles (or 4/12 by intensity)
// scale [0, 1.5, 0], random xy offset ±200, opacity [1, 1, 0], 1s duration
// Mix of circles and rounded squares in white + accent colors

struct CelebrationParticleLayer: View {
    let count: Int
    let trigger: Bool
    var accentColor: Color = .white

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            ZStack {
                ForEach(0..<count, id: \.self) { index in
                    CelebrationParticle(
                        index: index,
                        total: count,
                        animate: trigger,
                        accentColor: accentColor
                    )
                }
            }
        }
    }
}

// MARK: - Individual Particle

private struct CelebrationParticle: View {
    let index: Int
    let total: Int
    let animate: Bool
    let accentColor: Color

    // Figma: particles distributed radially with random jitter
    private var angle: Double {
        Double(index) * (360.0 / Double(total)) + Double.random(in: -25...25)
    }
    private var distance: CGFloat { CGFloat.random(in: 70...160) }
    private var particleSize: CGFloat { CGFloat.random(in: 8...16) }
    private var isRound: Bool { index % 3 != 0 }
    private var isAccent: Bool { index % 4 == 0 }

    @State private var phase: ParticlePhase = .idle

    var body: some View {
        Group {
            if isRound {
                Circle()
                    .fill(isAccent ? accentColor.opacity(0.9) : .white)
                    .frame(width: particleSize, height: particleSize)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(isAccent ? accentColor.opacity(0.9) : .white)
                    .frame(width: particleSize, height: particleSize * 0.7)
                    .rotationEffect(.degrees(Double.random(in: -45...45)))
            }
        }
        .scaleEffect(phase.scale)
        .offset(x: phase.offsetX, y: phase.offsetY)
        .opacity(phase.opacity)
        .onChange(of: animate) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        let radians = angle * .pi / 180
        let targetX = cos(radians) * distance
        let targetY = sin(radians) * distance
        let delay = 0.15 + Double(index) * 0.025

        // Figma Phase 1: grow + scatter outward
        withAnimation(.easeOut(duration: 0.35).delay(delay)) {
            phase = .expanding(x: targetX * 0.6, y: targetY * 0.6)
        }

        // Figma Phase 2: full scatter + begin fade
        withAnimation(.easeOut(duration: 0.3).delay(delay + 0.3)) {
            phase = .scattered(x: targetX, y: targetY)
        }

        // Figma Phase 3: shrink + fade out
        withAnimation(.easeIn(duration: 0.35).delay(delay + 0.55)) {
            phase = .faded(x: targetX * 1.1, y: targetY * 1.1)
        }
    }
}

// MARK: - Particle Animation Phases

private enum ParticlePhase {
    case idle
    case expanding(x: CGFloat, y: CGFloat)
    case scattered(x: CGFloat, y: CGFloat)
    case faded(x: CGFloat, y: CGFloat)

    var scale: CGFloat {
        switch self {
        case .idle: return 0
        case .expanding: return 1.5
        case .scattered: return 1.0
        case .faded: return 0
        }
    }

    var offsetX: CGFloat {
        switch self {
        case .idle: return 0
        case .expanding(let x, _): return x
        case .scattered(let x, _): return x
        case .faded(let x, _): return x
        }
    }

    var offsetY: CGFloat {
        switch self {
        case .idle: return 0
        case .expanding(_, let y): return y
        case .scattered(_, let y): return y
        case .faded(_, let y): return y
        }
    }

    var opacity: Double {
        switch self {
        case .idle: return 0
        case .expanding: return 1
        case .scattered: return 0.8
        case .faded: return 0
        }
    }
}
