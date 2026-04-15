import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - Dynamic App Icon Layer System
// Multi-layer icon architecture for iOS 26 Icon Composer.
//
// The Freshli icon is decomposed into 3 semantic layers that the
// system composites with depth, parallax, and dynamic lighting:
//
//   ┌─────────────────────────────────────────┐
//   │  FRONT LAYER — Leaf glyph + sparkle     │  Reacts to tilt
//   ��  MID LAYER   — Glass orb + ring         │  Specular highlight
//   │  BACK LAYER  — Gradient field + aura    │  Ambient depth
//   └─────────────────────────────────────────┘
//
// Each layer exists in 3 appearance variants:
//   • Light  — Vibrant greens on white/light background
//   • Dark   — Deep greens on dark background
//   • Tinted — Monochrome silhouette for user tint color
//
// The layers are rendered as SwiftUI views, then exported as
// 1024×1024 PNGs for Icon Composer assembly.
//
// Specular annotations:
//   • Front layer has `isSpecular: true` — the leaf catches light
//   • Mid layer has partial specularity — the glass orb refracts
//   • Back layer is matte — provides depth without glare
// ══════════════════════════════════════════════════════════════════

// MARK: - Icon Layer Specification

/// Describes a single layer of the multi-layer dynamic icon.
struct IconLayerSpec: Identifiable, Sendable {
    let id: String
    let name: String
    let depth: IconDepth
    let isSpecular: Bool
    let specularity: Double  // 0→1, how much this layer catches light

    enum IconDepth: String, Sendable {
        case back = "back"
        case mid = "middle"
        case front = "front"
    }
}

/// All three Freshli icon layers.
enum FreshliIconLayers {
    static let back = IconLayerSpec(
        id: "back",
        name: "Background Field",
        depth: .back,
        isSpecular: false,
        specularity: 0.0
    )

    static let mid = IconLayerSpec(
        id: "mid",
        name: "Glass Orb",
        depth: .mid,
        isSpecular: true,
        specularity: 0.5
    )

    static let front = IconLayerSpec(
        id: "front",
        name: "Leaf Glyph",
        depth: .front,
        isSpecular: true,
        specularity: 0.85
    )

    static let all: [IconLayerSpec] = [back, mid, front]
}

// MARK: - Icon Appearance Mode

enum IconAppearanceMode: String, CaseIterable, Sendable {
    case light = "light"
    case dark = "dark"
    case tinted = "tinted"
}

// MARK: - Back Layer View (Background Field + Aura)

/// The deepest layer — a radial gradient field with organic aura.
/// Provides the ambient color base that gives the icon depth.
struct IconBackLayerView: View {
    let appearance: IconAppearanceMode
    let size: CGFloat

    var body: some View {
        ZStack {
            // Base gradient field
            RadialGradient(
                colors: backgroundColors,
                center: .center,
                startRadius: 0,
                endRadius: size * 0.55
            )

            // Organic aura rings
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .strokeBorder(
                        auraColor.opacity(0.08 - Double(ring) * 0.02),
                        lineWidth: size * 0.02
                    )
                    .frame(width: size * (0.6 + CGFloat(ring) * 0.15))
            }
        }
        .frame(width: size, height: size)
    }

    private var backgroundColors: [Color] {
        switch appearance {
        case .light:
            return [Color(hex: 0xD1FAE5), Color(hex: 0xA7F3D0), Color(hex: 0x6EE7B7)]
        case .dark:
            return [Color(hex: 0x064E3B), Color(hex: 0x0D3B2C), Color(hex: 0x0A1F16)]
        case .tinted:
            return [Color.gray.opacity(0.15), Color.gray.opacity(0.08), Color.gray.opacity(0.03)]
        }
    }

    private var auraColor: Color {
        switch appearance {
        case .light: return Color(hex: 0x10B981)
        case .dark: return Color(hex: 0x34D399)
        case .tinted: return .gray
        }
    }
}

// MARK: - Mid Layer View (Glass Orb + Ring)

/// The middle layer — a glass orb with Fresnel rim and chromatic ring.
/// This layer catches specular highlights and provides the signature
/// Freshli glass aesthetic in the icon.
struct IconMidLayerView: View {
    let appearance: IconAppearanceMode
    let size: CGFloat

    var body: some View {
        ZStack {
            // Glass orb body
            Circle()
                .fill(orbGradient)
                .frame(width: size * 0.58)

            // Fresnel rim highlight
            Circle()
                .strokeBorder(
                    .linearGradient(
                        colors: [
                            rimColor.opacity(0.6),
                            rimColor.opacity(0.0),
                            rimColor.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size * 0.015
                )
                .frame(width: size * 0.58)

            // Chromatic ring (signature Freshli detail)
            Circle()
                .strokeBorder(
                    .angularGradient(
                        colors: ringColors,
                        center: .center,
                        startAngle: .zero,
                        endAngle: .degrees(360)
                    ),
                    lineWidth: size * 0.012
                )
                .frame(width: size * 0.68)
                .opacity(appearance == .tinted ? 0.3 : 0.7)

            // Inner specular catchlight
            Ellipse()
                .fill(
                    .linearGradient(
                        colors: [
                            Color.white.opacity(appearance == .tinted ? 0.1 : 0.35),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size * 0.32, height: size * 0.2)
                .offset(x: -size * 0.06, y: -size * 0.1)
                .rotationEffect(.degrees(-15))
        }
        .frame(width: size, height: size)
    }

    private var orbGradient: some ShapeStyle {
        .radialGradient(
            colors: orbColors,
            center: UnitPoint(x: 0.35, y: 0.35),
            startRadius: 0,
            endRadius: size * 0.35
        )
    }

    private var orbColors: [Color] {
        switch appearance {
        case .light:
            return [
                Color.white.opacity(0.9),
                Color(hex: 0xECFDF5).opacity(0.7),
                Color(hex: 0xA7F3D0).opacity(0.4)
            ]
        case .dark:
            return [
                Color(hex: 0x1A3A2A).opacity(0.9),
                Color(hex: 0x134E4A).opacity(0.7),
                Color(hex: 0x064E3B).opacity(0.5)
            ]
        case .tinted:
            return [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.2),
                Color.gray.opacity(0.1)
            ]
        }
    }

    private var rimColor: Color {
        appearance == .tinted ? .gray : .white
    }

    private var ringColors: [Color] {
        switch appearance {
        case .light:
            return [
                Color(hex: 0x10B981), Color(hex: 0x06B6D4),
                Color(hex: 0x8B5CF6), Color(hex: 0x10B981)
            ]
        case .dark:
            return [
                Color(hex: 0x34D399), Color(hex: 0x22D3EE),
                Color(hex: 0xA78BFA), Color(hex: 0x34D399)
            ]
        case .tinted:
            return [.gray, .gray.opacity(0.7), .gray.opacity(0.5), .gray]
        }
    }
}

// MARK: - Front Layer View (Leaf Glyph + Sparkle)

/// The topmost layer — the Freshli leaf symbol with sparkle accents.
/// Has the highest specularity — catches system lighting to create
/// the "living icon" effect as the user tilts their device.
struct IconFrontLayerView: View {
    let appearance: IconAppearanceMode
    let size: CGFloat

    var body: some View {
        ZStack {
            // Leaf glyph
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundStyle(leafGradient)
                .shadow(color: leafShadow, radius: size * 0.02, y: size * 0.01)

            // Sparkle accents (suggest freshness + intelligence)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.06, weight: .bold))
                .foregroundStyle(sparkleColor)
                .offset(x: size * 0.14, y: -size * 0.15)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.04, weight: .bold))
                .foregroundStyle(sparkleColor.opacity(0.7))
                .offset(x: -size * 0.16, y: size * 0.08)
        }
        .frame(width: size, height: size)
    }

    private var leafGradient: some ShapeStyle {
        .linearGradient(
            colors: leafColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var leafColors: [Color] {
        switch appearance {
        case .light:
            return [Color(hex: 0x059669), Color(hex: 0x10B981)]
        case .dark:
            return [Color(hex: 0x34D399), Color(hex: 0x6EE7B7)]
        case .tinted:
            return [.primary, .primary.opacity(0.8)]
        }
    }

    private var leafShadow: Color {
        switch appearance {
        case .light: return Color(hex: 0x059669).opacity(0.3)
        case .dark: return Color.black.opacity(0.4)
        case .tinted: return .clear
        }
    }

    private var sparkleColor: Color {
        switch appearance {
        case .light: return Color(hex: 0xFBBF24)
        case .dark: return Color(hex: 0xFDE68A)
        case .tinted: return .primary.opacity(0.6)
        }
    }
}

// MARK: - Composite Preview (All Layers)

/// Preview composite showing all 3 layers stacked, simulating how
/// the icon appears on the Home Screen.
struct FreshliDynamicIconPreview: View {
    let appearance: IconAppearanceMode
    let size: CGFloat

    var body: some View {
        ZStack {
            IconBackLayerView(appearance: appearance, size: size)
            IconMidLayerView(appearance: appearance, size: size)
            IconFrontLayerView(appearance: appearance, size: size)
        }
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
    }
}

// MARK: - Icon Layer Export Helper

/// Renders each icon layer to a UIImage for export.
/// Call from a debug view or build script to generate the PNGs.
@MainActor
enum IconLayerExporter {
    /// Renders a single layer at 1024×1024 to UIImage.
    @MainActor
    static func renderLayer<V: View>(_ view: V, size: CGFloat = 1024) -> UIImage? {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1.0
        return renderer.uiImage
    }

    /// Exports all layers for all appearances to the Documents directory.
    /// Returns the paths of all generated files.
    @discardableResult
    static func exportAll() -> [String] {
        var paths: [String] = []
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let iconDir = docs.appendingPathComponent("IconLayers", isDirectory: true)
        try? FileManager.default.createDirectory(at: iconDir, withIntermediateDirectories: true)

        for appearance in IconAppearanceMode.allCases {
            let suffix = appearance.rawValue

            // Back layer
            if let img = renderLayer(IconBackLayerView(appearance: appearance, size: 1024)) {
                let path = iconDir.appendingPathComponent("back_\(suffix).png")
                try? img.pngData()?.write(to: path)
                paths.append(path.path)
            }

            // Mid layer
            if let img = renderLayer(IconMidLayerView(appearance: appearance, size: 1024)) {
                let path = iconDir.appendingPathComponent("mid_\(suffix).png")
                try? img.pngData()?.write(to: path)
                paths.append(path.path)
            }

            // Front layer
            if let img = renderLayer(IconFrontLayerView(appearance: appearance, size: 1024)) {
                let path = iconDir.appendingPathComponent("front_\(suffix).png")
                try? img.pngData()?.write(to: path)
                paths.append(path.path)
            }
        }

        return paths
    }
}

// MARK: - Previews

#Preview("Dynamic Icon — All Appearances") {
    HStack(spacing: 24) {
        ForEach(IconAppearanceMode.allCases, id: \.rawValue) { mode in
            VStack {
                FreshliDynamicIconPreview(appearance: mode, size: 120)
                Text(mode.rawValue.capitalized)
                    .font(.caption)
            }
        }
    }
    .padding()
}

#Preview("Icon Layers — Exploded") {
    VStack(spacing: 16) {
        Text("Back").font(.caption2)
        IconBackLayerView(appearance: .light, size: 200)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

        Text("Middle").font(.caption2)
        IconMidLayerView(appearance: .light, size: 200)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))

        Text("Front").font(.caption2)
        IconFrontLayerView(appearance: .light, size: 200)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
    }
    .padding()
}
