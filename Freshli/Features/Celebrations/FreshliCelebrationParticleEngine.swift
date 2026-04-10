import SwiftUI

// MARK: - Freshli Celebration Particle Engine
// High-performance Canvas + PhaseAnimator particle system for 120fps ProMotion.
// Particle math is offloaded to a background Task, rendering on MainActor.
// Uses unique name FreshliCelebrationParticle to avoid conflicts with
// ConfettiParticle (PSSuccessCelebration) and InventoryConfettiParticle.

// MARK: - Celebration Flavor

enum FreshliCelebrationFlavor: Sendable {
    case consumed     // Green confetti — item consumed/saved
    case shared       // Teal/blue confetti — item shared with neighbor
    case milestone    // Gold burst — milestone reached
    case community    // Warm gradient — community claim

    var colors: [Color] {
        switch self {
        case .consumed:
            return [
                Color(hex: 0x22C55E), // green-500
                Color(hex: 0x4ADE80), // green-400
                Color(hex: 0x86EFAC), // green-300
                Color(hex: 0xDCFCE7), // green-100
                .white,
            ]
        case .shared:
            return [
                Color(hex: 0x14B8A6), // teal-500
                Color(hex: 0x2DD4BF), // teal-400
                Color(hex: 0x3B82F6), // blue-500
                Color(hex: 0x60A5FA), // blue-400
                .white,
            ]
        case .milestone:
            return [
                Color(hex: 0xD97706), // amber-600
                Color(hex: 0xF59E0B), // amber-500
                Color(hex: 0xFBBF24), // amber-400
                Color(hex: 0xFDE68A), // amber-200
                .white,
            ]
        case .community:
            return [
                Color(hex: 0xF59E0B), // amber-500
                Color(hex: 0xEF4444), // red-500
                Color(hex: 0xF97316), // orange-500
                Color(hex: 0xFBBF24), // amber-400
                .white,
            ]
        }
    }

    /// Resolved colors for Sendable particle math on background thread
    var resolvedColorIndices: [Int] {
        Array(0..<colors.count)
    }
}

// MARK: - Particle Data (Sendable for background computation)

struct FreshliCelebrationParticle: Sendable, Identifiable {
    let id: Int
    var x: Double
    var y: Double
    var velocityX: Double
    var velocityY: Double
    var rotation: Double
    var rotationSpeed: Double
    var scale: Double
    var opacity: Double
    var colorIndex: Int
    var shape: ParticleShape
    var life: Double      // 0→1, particle dies at 1
    var lifeSpeed: Double // how fast life drains

    enum ParticleShape: Int, Sendable {
        case circle
        case roundedRect
        case leaf
    }
}

// MARK: - Particle Engine (background math, MainActor rendering)

@Observable @MainActor
final class FreshliParticleEngine {
    var particles: [FreshliCelebrationParticle] = []
    var isActive = false

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private let gravity: Double = 280
    private let drag: Double = 0.985

    func emit(count: Int, flavor: FreshliCelebrationFlavor, from origin: CGPoint, in size: CGSize) {
        isActive = true
        let colorCount = flavor.colors.count

        // Build initial particles on background thread
        Task.detached(priority: .userInitiated) {
            var newParticles: [FreshliCelebrationParticle] = []
            newParticles.reserveCapacity(count)

            for i in 0..<count {
                let angle = Double.random(in: -Double.pi...Double.pi)
                let speed = Double.random(in: 300...800)
                let shape: FreshliCelebrationParticle.ParticleShape = {
                    switch i % 5 {
                    case 0, 1: return .circle
                    case 2, 3: return .roundedRect
                    default:   return .leaf
                    }
                }()

                let particle = FreshliCelebrationParticle(
                    id: i,
                    x: origin.x,
                    y: origin.y,
                    velocityX: cos(angle) * speed,
                    velocityY: sin(angle) * speed - Double.random(in: 100...300),
                    rotation: Double.random(in: 0...360),
                    rotationSpeed: Double.random(in: -400...400),
                    scale: Double.random(in: 0.5...1.3),
                    opacity: 1.0,
                    colorIndex: Int.random(in: 0..<colorCount),
                    shape: shape,
                    life: 0,
                    lifeSpeed: Double.random(in: 0.3...0.6)
                )
                newParticles.append(particle)
            }

            await MainActor.run { [newParticles] in
                self.particles = newParticles
                self.startDisplayLink()
            }
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isActive = false
        particles.removeAll()
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] timestamp in
            self?.tick(timestamp: timestamp)
        }, selector: #selector(DisplayLinkTarget.step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        lastTimestamp = 0
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func tick(timestamp: CFTimeInterval) {
        let dt: Double
        if lastTimestamp == 0 {
            dt = 1.0 / 120.0
        } else {
            dt = min(timestamp - lastTimestamp, 1.0 / 30.0) // cap at 30fps minimum
        }
        lastTimestamp = timestamp

        let gravity = self.gravity
        let drag = self.drag

        // Offload physics to background
        let current = particles
        Task.detached(priority: .userInitiated) {
            var updated = current
            var allDead = true

            for i in updated.indices {
                updated[i].velocityY += gravity * dt
                updated[i].velocityX *= drag
                updated[i].velocityY *= drag
                updated[i].x += updated[i].velocityX * dt
                updated[i].y += updated[i].velocityY * dt
                updated[i].rotation += updated[i].rotationSpeed * dt
                updated[i].life += updated[i].lifeSpeed * dt

                // Fade out in final 30% of life
                if updated[i].life > 0.7 {
                    updated[i].opacity = max(0, 1.0 - ((updated[i].life - 0.7) / 0.3))
                }
                // Scale down near death
                if updated[i].life > 0.8 {
                    updated[i].scale *= 0.97
                }

                if updated[i].life < 1.0 {
                    allDead = false
                }
            }

            await MainActor.run { [updated, allDead] in
                self.particles = updated
                if allDead {
                    self.stop()
                }
            }
        }
    }
}

// MARK: - Display Link Target (prevent retain cycle)

private final class DisplayLinkTarget {
    let callback: (CFTimeInterval) -> Void

    init(callback: @escaping (CFTimeInterval) -> Void) {
        self.callback = callback
    }

    @objc func step(_ link: CADisplayLink) {
        callback(link.timestamp)
    }
}

// MARK: - Canvas Renderer

struct FreshliParticleCanvas: View {
    let particles: [FreshliCelebrationParticle]
    let flavor: FreshliCelebrationFlavor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            Canvas { context, size in
                let colors = flavor.colors

                for particle in particles where particle.opacity > 0.01 {
                    let color = colors[particle.colorIndex % colors.count]
                    let rect = CGRect(
                        x: particle.x - 6 * particle.scale,
                        y: particle.y - 6 * particle.scale,
                        width: 12 * particle.scale,
                        height: 12 * particle.scale
                    )

                    var ctx = context
                    ctx.opacity = particle.opacity

                    // Rotate around particle center
                    let center = CGPoint(x: particle.x, y: particle.y)
                    ctx.translateBy(x: center.x, y: center.y)
                    ctx.rotate(by: .degrees(particle.rotation))
                    ctx.translateBy(x: -center.x, y: -center.y)

                    switch particle.shape {
                    case .circle:
                        let path = Circle().path(in: rect)
                        ctx.fill(path, with: .color(color))

                    case .roundedRect:
                        let w = 12 * particle.scale
                        let h = 8 * particle.scale
                        let r = CGRect(
                            x: particle.x - w / 2,
                            y: particle.y - h / 2,
                            width: w,
                            height: h
                        )
                        let path = RoundedRectangle(cornerRadius: 2).path(in: r)
                        ctx.fill(path, with: .color(color))

                    case .leaf:
                        // Small leaf shape via ellipse + rotation
                        let w = 14 * particle.scale
                        let h = 8 * particle.scale
                        let r = CGRect(
                            x: particle.x - w / 2,
                            y: particle.y - h / 2,
                            width: w,
                            height: h
                        )
                        let path = Ellipse().path(in: r)
                        ctx.fill(path, with: .color(color))
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }
}

// MARK: - PhaseAnimator Burst Layer
// Lightweight burst overlay using PhaseAnimator for the initial "pop" effect

struct FreshliBurstOverlay: View {
    let flavor: FreshliCelebrationFlavor
    let trigger: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if trigger && !reduceMotion {
            PhaseAnimator([BurstPhase.initial, .expanded, .faded], trigger: trigger) { phase in
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(
                            flavor.colors.first?.opacity(0.4) ?? .white.opacity(0.4),
                            lineWidth: phase.ringWidth
                        )
                        .frame(width: phase.ringSize, height: phase.ringSize)
                        .opacity(phase.ringOpacity)

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    flavor.colors.first?.opacity(0.3) ?? .clear,
                                    .clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: phase.glowRadius
                            )
                        )
                        .frame(width: phase.glowRadius * 2, height: phase.glowRadius * 2)
                        .opacity(phase.glowOpacity)
                }
            } animation: { phase in
                switch phase {
                case .initial: .easeOut(duration: 0.15)
                case .expanded: .easeOut(duration: 0.4)
                case .faded: .easeIn(duration: 0.3)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private enum BurstPhase: CaseIterable {
    case initial, expanded, faded

    var ringSize: CGFloat {
        switch self {
        case .initial: return 40
        case .expanded: return 200
        case .faded: return 240
        }
    }

    var ringWidth: CGFloat {
        switch self {
        case .initial: return 8
        case .expanded: return 3
        case .faded: return 1
        }
    }

    var ringOpacity: Double {
        switch self {
        case .initial: return 0.8
        case .expanded: return 0.5
        case .faded: return 0
        }
    }

    var glowRadius: CGFloat {
        switch self {
        case .initial: return 30
        case .expanded: return 120
        case .faded: return 160
        }
    }

    var glowOpacity: Double {
        switch self {
        case .initial: return 0.6
        case .expanded: return 0.2
        case .faded: return 0
        }
    }
}
