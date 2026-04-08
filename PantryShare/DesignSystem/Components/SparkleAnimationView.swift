import SwiftUI

/// SparkleAnimationView renders a performant particle burst animation using Canvas.
/// Particles include leaf emojis and geometric shapes in harvest theme colors.
struct SparkleAnimationView: View {
    let intensity: SparkleIntensity
    @State private var particles: [Particle] = []
    @State private var isAnimating = false

    private var particleCount: Int {
        switch intensity {
        case .gentle:      return Int.random(in: 3...5)
        case .standard:    return Int.random(in: 10...15)
        case .celebration: return Int.random(in: 25...35)
        }
    }

    private var animationDuration: Double {
        switch intensity {
        case .gentle:      return 1.5
        case .standard:    return 2.0
        case .celebration: return 2.5
        }
    }

    var body: some View {
        Canvas { context, size in
            for particle in particles {
                let progress = particle.progress
                let x = particle.startX + particle.vx * progress * 150
                let y = particle.startY + particle.vy * progress * 200
                let scale = 1.0 - (progress * 0.3) // Slight shrinking
                let opacity = 1.0 - (progress * progress) // Fade out

                let position = CGPoint(x: x, y: y)

                // Draw particles (leaf emoji or geometric shape)
                if particle.isLeaf {
                    var leafContext = context
                    leafContext.opacity = opacity
                    leafContext.scaleBy(x: scale, y: scale)
                    let text = Text("🍃")
                        .font(.system(size: 16))
                    leafContext.draw(text, at: position)
                } else {
                    // Geometric shape (circle or star)
                    drawShape(context: context, particle: particle, at: position, scale: scale, opacity: opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            generateParticles()
            startAnimation()
        }
    }

    // MARK: - Particle Generation

    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            let angle = Double.random(in: 0..<2 * .pi)
            let speed = Double.random(in: 0.8...1.2)
            let isLeaf = Bool.random() && Int.random(in: 0..<2) == 0

            return Particle(
                startX: 0,
                startY: 0,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                color: [PSColors.primaryGreen, PSColors.freshGreen, PSColors.accentTeal].randomElement() ?? PSColors.primaryGreen,
                isLeaf: isLeaf,
                progress: 0
            )
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        withAnimation(.easeOut(duration: animationDuration)) {
            for index in particles.indices {
                particles[index].progress = 1.0
            }
            isAnimating = true
        }
    }

    // MARK: - Shape Drawing

    private func drawShape(context: GraphicsContext, particle: Particle, at position: CGPoint, scale: CGFloat, opacity: Double) {
        var shapePath = Path()

        if particle.isCircle {
            shapePath.addArc(
                center: position,
                radius: 4 * scale,
                startAngle: .zero,
                endAngle: .radians(.pi * 2),
                clockwise: false
            )
        } else {
            // Simple star shape
            drawStar(center: position, radius: 5 * scale, points: 5, into: &shapePath)
        }

        var fillContext = context
        fillContext.opacity = opacity
        fillContext.fill(
            shapePath,
            with: .color(particle.color)
        )
    }

    private func drawStar(center: CGPoint, radius: CGFloat, points: Int, into path: inout Path) {
        let angle = 2 * CGFloat.pi / CGFloat(points)
        for i in 0..<points {
            let x = center.x + radius * cos(CGFloat(i) * angle - .pi / 2)
            let y = center.y + radius * sin(CGFloat(i) * angle - .pi / 2)
            let point = CGPoint(x: x, y: y)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
    }
}

// MARK: - Particle Model

struct Particle {
    let startX: CGFloat
    let startY: CGFloat
    let vx: Double
    let vy: Double
    let color: Color
    let isLeaf: Bool
    var progress: Double = 0

    var isCircle: Bool {
        !isLeaf && Bool.random()
    }
}

// MARK: - Preview

#Preview("Sparkle - Gentle") {
    ZStack {
        PSColors.backgroundPrimary
            .ignoresSafeArea()

        SparkleAnimationView(intensity: .gentle)
    }
}

#Preview("Sparkle - Standard") {
    ZStack {
        PSColors.backgroundPrimary
            .ignoresSafeArea()

        SparkleAnimationView(intensity: .standard)
    }
}

#Preview("Sparkle - Celebration") {
    ZStack {
        PSColors.backgroundPrimary
            .ignoresSafeArea()

        SparkleAnimationView(intensity: .celebration)
    }
}
