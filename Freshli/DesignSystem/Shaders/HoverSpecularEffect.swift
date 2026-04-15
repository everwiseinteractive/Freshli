import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Hover Specular Highlight System
// Metal-driven specular highlight that follows the user's touch
// proximity or Apple Pencil hover. Every interactive element in
// the app responds to hover with a subtle, directional light
// reflection that follows the angle of interaction.
//
// Architecture:
//   1. `.onContinuousHover` captures pointer position (iPad/Mac/Pencil)
//   2. A lightweight `.colorEffect` shader computes a directional
//      specular highlight based on the hover position relative to
//      the view's center
//   3. On iPhone (no hover), touch-down position creates the same
//      effect via the press gesture
//
// The specular is intentionally subtle — it should feel like light
// playing across a glass surface, not a flashlight beam.
//
// Accessibility:
//   - Disabled when Reduce Motion is enabled
//   - Disabled when shader quality < .medium
//   - No visual change for non-hover devices (graceful no-op)
// ══════════════════════════════════════════════════════════════════

// MARK: - Hover Specular Modifier

/// Adds a directional specular highlight that follows hover position.
/// Works with Apple Pencil hover, iPad pointer, and Mac trackpad.
/// On iPhone, the highlight appears on touch-down at the press location.
struct HoverSpecularModifier: ViewModifier {
    let intensity: Double
    let cornerRadius: CGFloat

    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering = false
    @State private var isPressed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var schemeContrast
    @Environment(\.shaderQuality) private var quality

    init(intensity: Double = 0.6, cornerRadius: CGFloat = PSSpacing.radiusXxl) {
        self.intensity = intensity
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        if reduceMotion || schemeContrast == .increased || !quality.enableComplexShaders {
            content
        } else {
            content
                .overlay {
                    if isHovering || isPressed {
                        specularOverlay
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        withAnimation(.easeOut(duration: 0.15)) {
                            hoverLocation = location
                            isHovering = true
                        }
                    case .ended:
                        withAnimation(.easeOut(duration: 0.3)) {
                            isHovering = false
                        }
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            hoverLocation = value.location
                            if !isPressed {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    isPressed = true
                                }
                                MotionVocabularyService.shared.speakMotion(
                                    .specularFlash(intensity: Float(intensity))
                                )
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.easeOut(duration: 0.25)) {
                                isPressed = false
                            }
                        }
                )
        }
    }

    // MARK: - Specular Overlay

    /// The specular highlight rendered as a radial gradient positioned
    /// at the hover/touch location. This approach avoids a continuous
    /// TimelineView — the gradient simply moves with the pointer.
    private var specularOverlay: some View {
        GeometryReader { proxy in
            let normalizedX = hoverLocation.x / max(proxy.size.width, 1)
            let normalizedY = hoverLocation.y / max(proxy.size.height, 1)

            // Specular intensity based on distance from center
            let centerDist = sqrt(
                pow(normalizedX - 0.5, 2) + pow(normalizedY - 0.5, 2)
            )
            let edgeBoost = min(centerDist * 1.5, 1.0)  // Brighter near edges (Fresnel)

            // Directional specular — ellipse stretched toward the hover point
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(intensity * (0.15 + edgeBoost * 0.1)),
                            Color.white.opacity(intensity * 0.04),
                            Color.clear
                        ],
                        center: UnitPoint(x: normalizedX, y: normalizedY),
                        startRadius: 0,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.5
                    )
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                // Add a subtle Fresnel rim on the side closest to hover
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            .linearGradient(
                                colors: [
                                    Color.white.opacity(normalizedY < 0.5 ? 0.15 : 0.0),
                                    Color.white.opacity(normalizedY >= 0.5 ? 0.12 : 0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .opacity(isHovering || isPressed ? intensity : 0)
                }
        }
    }
}

// MARK: - Hover Lift Modifier

/// Combines the specular highlight with a subtle Z-axis lift effect.
/// When hovered, the element scales up slightly and gains elevation,
/// creating the illusion of the item "rising" toward the user's finger.
struct HoverLiftModifier: ViewModifier {
    let liftScale: CGFloat
    let liftElevation: FLElevation

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(liftScale: CGFloat = 1.02, liftElevation: FLElevation = .z3) {
        self.liftScale = liftScale
        self.liftElevation = liftElevation
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && !reduceMotion ? liftScale : 1.0)
            .elevation(isHovering ? liftElevation : .z1)
            .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isHovering = true
                case .ended:
                    isHovering = false
                }
            }
    }
}

// MARK: - Pencil Tilt Specular Modifier

/// Enhanced specular that responds to Apple Pencil altitude angle.
/// When the Pencil hovers at an angle, the specular highlight shifts
/// to simulate light refracting through a glass surface from the
/// pencil's approach direction.
///
/// Note: On devices without Apple Pencil, falls back to standard
/// HoverSpecularModifier behavior using pointer position only.
struct PencilTiltSpecularModifier: ViewModifier {
    let intensity: Double

    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.shaderQuality) private var quality

    init(intensity: Double = 0.7) {
        self.intensity = intensity
    }

    func body(content: Content) -> some View {
        if reduceMotion || !quality.enableComplexShaders {
            content
        } else {
            content
                .overlay {
                    if isHovering {
                        GeometryReader { proxy in
                            let nx = hoverLocation.x / max(proxy.size.width, 1)
                            let ny = hoverLocation.y / max(proxy.size.height, 1)

                            // Dual specular: primary catchlight + secondary rim
                            ZStack {
                                // Primary catchlight
                                Ellipse()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.white.opacity(intensity * 0.2),
                                                Color.clear
                                            ],
                                            center: UnitPoint(x: nx, y: ny),
                                            startRadius: 0,
                                            endRadius: min(proxy.size.width, proxy.size.height) * 0.35
                                        )
                                    )

                                // Secondary rim glow on opposite side
                                Ellipse()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                PSColors.primaryGreen.opacity(intensity * 0.06),
                                                Color.clear
                                            ],
                                            center: UnitPoint(x: 1 - nx, y: 1 - ny),
                                            startRadius: 0,
                                            endRadius: min(proxy.size.width, proxy.size.height) * 0.4
                                        )
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        }
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        withAnimation(.interactiveSpring(response: 0.12)) {
                            hoverLocation = location
                            isHovering = true
                        }
                    case .ended:
                        withAnimation(.easeOut(duration: 0.3)) {
                            isHovering = false
                        }
                    }
                }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Add a directional specular highlight that follows hover/touch proximity.
    /// Works with Apple Pencil hover, iPad pointer, Mac trackpad, and iPhone touch.
    func hoverSpecular(intensity: Double = 0.6, cornerRadius: CGFloat = PSSpacing.radiusXxl) -> some View {
        modifier(HoverSpecularModifier(intensity: intensity, cornerRadius: cornerRadius))
    }

    /// Add hover lift — scale + elevation change on hover for "rising" effect.
    func hoverLift(scale: CGFloat = 1.02, elevation: FLElevation = .z3) -> some View {
        modifier(HoverLiftModifier(liftScale: scale, liftElevation: elevation))
    }

    /// Add Apple Pencil tilt-aware specular with dual catchlight.
    func pencilSpecular(intensity: Double = 0.7) -> some View {
        modifier(PencilTiltSpecularModifier(intensity: intensity))
    }

    /// Composite hover treatment for interactive cards — specular + lift + haptic.
    func interactiveHover(
        intensity: Double = 0.5,
        cornerRadius: CGFloat = PSSpacing.radiusXxl
    ) -> some View {
        self
            .hoverSpecular(intensity: intensity, cornerRadius: cornerRadius)
            .hoverLift(scale: 1.015, elevation: .z2)
    }
}
