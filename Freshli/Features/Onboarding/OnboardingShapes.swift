import SwiftUI

// MARK: - Morphing Blob Shape
// Organic blob that morphs between screens using Catmull-Rom → Bezier interpolation.
// Each page has a unique control-point set; intermediate states are lerped.

struct MorphingBlobShape: Shape {
    var morphProgress: CGFloat // 0…2 across 3 pages
    var animatableData: CGFloat {
        get { morphProgress }
        set { morphProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) * 0.45

        // 3 page shapes: clean circle → organic blob → rounded square
        let page = Int(morphProgress.clamped(to: 0...2))
        let t = morphProgress - CGFloat(page)

        let fromPoints = controlPoints(for: page, center: CGPoint(x: cx, y: cy), radius: r)
        let toPoints = controlPoints(for: min(page + 1, 2), center: CGPoint(x: cx, y: cy), radius: r)

        let points = zip(fromPoints, toPoints).map { from, to in
            CGPoint(x: from.x + (to.x - from.x) * t,
                    y: from.y + (to.y - from.y) * t)
        }

        return smoothBlobPath(points: points)
    }

    private func controlPoints(for page: Int, center: CGPoint, radius: CGFloat) -> [CGPoint] {
        let count = 8
        switch page {
        case 0:
            // Near-circle with subtle organic wobble (clean fridge)
            return (0..<count).map { i in
                let angle = CGFloat(i) / CGFloat(count) * .pi * 2
                let wobble: CGFloat = (i % 2 == 0) ? 1.0 : 0.95
                return CGPoint(
                    x: center.x + cos(angle) * radius * wobble,
                    y: center.y + sin(angle) * radius * wobble
                )
            }
        case 1:
            // Organic blob (savings/earth shape)
            let offsets: [CGFloat] = [1.05, 0.88, 1.1, 0.85, 1.0, 0.92, 1.08, 0.9]
            return (0..<count).map { i in
                let angle = CGFloat(i) / CGFloat(count) * .pi * 2
                return CGPoint(
                    x: center.x + cos(angle) * radius * offsets[i],
                    y: center.y + sin(angle) * radius * offsets[i]
                )
            }
        default:
            // Rounded square (community/map shape)
            let squareR = radius * 0.92
            let cornerPull: CGFloat = 0.72
            return [
                CGPoint(x: center.x, y: center.y - squareR),                                   // top
                CGPoint(x: center.x + squareR * cornerPull, y: center.y - squareR * cornerPull), // top-right
                CGPoint(x: center.x + squareR, y: center.y),                                   // right
                CGPoint(x: center.x + squareR * cornerPull, y: center.y + squareR * cornerPull), // bottom-right
                CGPoint(x: center.x, y: center.y + squareR),                                   // bottom
                CGPoint(x: center.x - squareR * cornerPull, y: center.y + squareR * cornerPull), // bottom-left
                CGPoint(x: center.x - squareR, y: center.y),                                   // left
                CGPoint(x: center.x - squareR * cornerPull, y: center.y - squareR * cornerPull), // top-left
            ]
        }
    }

    private func smoothBlobPath(points: [CGPoint]) -> Path {
        guard points.count >= 3 else { return Path() }
        var path = Path()
        let n = points.count

        path.move(to: midpoint(points[n - 1], points[0]))

        for i in 0..<n {
            let p0 = points[i]
            let p1 = points[(i + 1) % n]
            let mid = midpoint(p0, p1)
            path.addQuadCurve(to: mid, control: p0)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

// MARK: - Floating Particles Canvas
// Ambient floating particles that respond to page changes.

struct OnboardingParticlesView: View {
    let page: Int
    @State private var time: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let particleColors: [[Color]] = [
        [PSColors.primaryGreen, PSColors.emeraldLight, PSColors.accentTeal],          // Kitchen
        [PSColors.secondaryAmber, PSColors.primaryGreen, Color(hex: 0xFBBF24)],       // Savings
        [PSColors.infoBlue, PSColors.accentTeal, PSColors.primaryGreen],              // Community
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let colors = particleColors[min(page, 2)]

                for i in 0..<18 {
                    let seed = Double(i) * 137.508 // golden angle
                    let speed = 0.3 + (seed.truncatingRemainder(dividingBy: 0.7))
                    let phase = seed.truncatingRemainder(dividingBy: .pi * 2)

                    let x = (sin(elapsed * speed * 0.4 + phase) * 0.35 + 0.5) * size.width
                    let y = (cos(elapsed * speed * 0.3 + phase * 1.3) * 0.35 + 0.5) * size.height
                    let radius = CGFloat(3 + (seed.truncatingRemainder(dividingBy: 5)))
                    let opacity = 0.15 + sin(elapsed * speed + phase) * 0.1

                    let color = colors[i % colors.count].opacity(opacity)
                    context.fill(
                        Circle().path(in: CGRect(x: x - radius, y: y - radius,
                                                 width: radius * 2, height: radius * 2)),
                        with: .color(color)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Morphing Background
// Combines MeshGradient (iOS 18+) + morphing blob + floating particles.

struct OnboardingMorphBackground: View {
    let page: Int
    let morphProgress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var meshPhase: CGFloat = 0

    private var meshColors: [Color] {
        switch page {
        case 0: return [
            PSColors.green50, PSColors.emeraldLight.opacity(0.6),
            PSColors.green50, PSColors.primaryGreen.opacity(0.15),
            PSColors.emeraldLight.opacity(0.3), PSColors.green50,
            PSColors.green50, PSColors.emeraldLight.opacity(0.4), PSColors.green50
        ]
        case 1: return [
            Color(hex: 0xFEFCE8), PSColors.green50,
            Color(hex: 0xFEF3C7).opacity(0.6), PSColors.primaryGreen.opacity(0.1),
            Color(hex: 0xFEFCE8), PSColors.green50,
            PSColors.green50, Color(hex: 0xFEF3C7).opacity(0.4), Color(hex: 0xFEFCE8)
        ]
        default: return [
            Color(hex: 0xEFF6FF), PSColors.accentTeal.opacity(0.15),
            Color(hex: 0xDBEAFE).opacity(0.4), PSColors.primaryGreen.opacity(0.1),
            Color(hex: 0xEFF6FF), PSColors.accentTeal.opacity(0.2),
            Color(hex: 0xEFF6FF), Color(hex: 0xDBEAFE).opacity(0.3), Color(hex: 0xEFF6FF)
        ]
        }
    }

    var body: some View {
        ZStack {
            // iOS 18 MeshGradient background
            meshGradientLayer

            // Morphing blob behind content
            MorphingBlobShape(morphProgress: morphProgress)
                .fill(blobGradient)
                .frame(width: PSLayout.scaled(320), height: PSLayout.scaled(320))
                .blur(radius: 60)
                .opacity(0.35)

            // Floating ambient particles
            OnboardingParticlesView(page: page)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
                meshPhase = 1
            }
        }
    }

    private var meshGradientLayer: some View {
        let drift: Float = reduceMotion ? 0 : Float(meshPhase) * 0.04
        return MeshGradient(
            width: 3, height: 3,
            points: [
                SIMD2(0, 0), SIMD2(0.5 + drift, 0), SIMD2(1, 0),
                SIMD2(0, 0.5 - drift), SIMD2(0.5 + drift, 0.5 + drift), SIMD2(1, 0.5 + drift),
                SIMD2(0, 1), SIMD2(0.5 - drift, 1), SIMD2(1, 1)
            ],
            colors: meshColors
        )
        .ignoresSafeArea()
    }

    private var blobGradient: some ShapeStyle {
        switch page {
        case 0: return AnyShapeStyle(PSColors.emeraldLight.gradient)
        case 1: return AnyShapeStyle(Color(hex: 0xFEF3C7).gradient)
        default: return AnyShapeStyle(Color(hex: 0xDBEAFE).gradient)
        }
    }
}

// MARK: - Helpers

private extension Comparable {
    nonisolated func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
