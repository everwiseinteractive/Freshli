import SwiftUI

// MARK: - Freshli Design System Tokens (Swift 6.3)
// Senior UI/UX implementation of the Freshli Design System.
// Extends the existing PSColors / PSTypography with premium brand tokens,
// glass-morphism card styles, SF Symbols 6.0 iconography, and modern button shapes.

// MARK: - 1. Color Palette — FreshliColor

/// Semantic brand palette built on `ShapeStyle` so every token works with
/// `.foregroundStyle()`, `.tint()`, and gradient APIs out of the box.
enum FreshliColor {

    // MARK: Primary — Vibrant organic green
    /// Hero actions, tab bar highlights, impact streaks.
    static let freshliGreen = Color(
        light: Color(hex: 0x34C759),   // Vibrant iOS system green
        dark:  Color(hex: 0x30D158)    // Slightly warmer for OLED
    )

    /// Pressed / active state for primary surfaces.
    static let freshliGreenDeep = Color(
        light: Color(hex: 0x248A3D),
        dark:  Color(hex: 0x34C759)
    )

    /// Subtle primary tint for backgrounds and badges.
    static let freshliGreenSurface = Color(
        light: Color(hex: 0xE8F9ED),
        dark:  Color(hex: 0x0D3B1A).opacity(0.35)
    )

    // MARK: Expiry Amber — Warm warning
    /// "Expiring Soon" badges, alert borders, countdown rings.
    static let expiryAmber = Color(
        light: Color(hex: 0xF5A623),
        dark:  Color(hex: 0xFFBF47)
    )

    static let expiryAmberSurface = Color(
        light: Color(hex: 0xFFF4DE),
        dark:  Color(hex: 0x3D2E0A).opacity(0.35)
    )

    // MARK: Impact Gold — Premium celebration
    /// Milestone badges, streak animations, weekly-wrap confetti.
    static let impactGold = Color(
        light: Color(hex: 0xFFD700),
        dark:  Color(hex: 0xFFE34D)
    )

    static let impactGoldSurface = Color(
        light: Color(hex: 0xFFFBE6),
        dark:  Color(hex: 0x3D3300).opacity(0.30)
    )

    // MARK: Hierarchical helpers

    /// Adaptive label that maps to the system hierarchy.
    static func label(_ level: HierarchicalShapeStyle.Level) -> some ShapeStyle {
        switch level {
        case .primary:    return AnyShapeStyle(.primary)
        case .secondary:  return AnyShapeStyle(.secondary)
        case .tertiary:   return AnyShapeStyle(.tertiary)
        case .quaternary: return AnyShapeStyle(.quaternary)
        @unknown default: return AnyShapeStyle(.primary)
        }
    }
}

/// Convenience namespace for hierarchy levels used by `FreshliColor.label(_:)`.
enum HierarchicalShapeStyle {
    enum Level { case primary, secondary, tertiary, quaternary }
}

// MARK: - 2. Typography — San Francisco Rounded + Dynamic Type

extension Font {
    // MARK: Display

    /// Hero stat counters (e.g. "£42 saved").  Rounded, bold, scales with Dynamic Type.
    static let freshliDisplayLarge: Font = .system(.largeTitle, design: .rounded, weight: .bold)

    /// Section headers inside cards.
    static let freshliDisplayMedium: Font = .system(.title2, design: .rounded, weight: .semibold)

    /// Tab bar labels, compact stat tiles.
    static let freshliDisplaySmall: Font = .system(.title3, design: .rounded, weight: .semibold)

    // MARK: Body

    /// Primary body copy — keeps the editorial feel with a slightly heavier weight.
    static let freshliBody: Font = .system(.body, design: .rounded, weight: .regular)

    /// Emphasised inline text (e.g. item names in lists).
    static let freshliBodyMedium: Font = .system(.body, design: .rounded, weight: .medium)

    /// Subheadlines and supporting text.
    static let freshliSubheadline: Font = .system(.subheadline, design: .rounded, weight: .regular)

    // MARK: Small

    /// Captions, timestamps, and metadata.
    static let freshliCaption: Font = .system(.caption, design: .rounded, weight: .medium)

    /// Tiny legal / expiry-date footnotes.
    static let freshliFootnote: Font = .system(.footnote, design: .rounded, weight: .regular)
}

/// View modifier that applies Freshli typography to a `Text` view while preserving
/// Dynamic Type accessibility scaling on all device sizes.
struct FreshliFontModifier: ViewModifier {
    let font: Font
    let tracking: CGFloat

    init(_ font: Font, tracking: CGFloat = -0.2) {
        self.font = font
        self.tracking = tracking
    }

    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(tracking)
            .dynamicTypeSize(...DynamicTypeSize.accessibility3) // caps at xxxLarge for layout safety
    }
}

extension Text {
    /// Apply a Freshli font with tight tracking and Dynamic Type scaling.
    func freshliFont(_ font: Font, tracking: CGFloat = -0.2) -> some View {
        self.modifier(FreshliFontModifier(font, tracking: tracking))
    }
}

// MARK: - 3. Shadows & Glass — FreshliCardStyle

/// A premium glass-morphism card modifier using `.ultraThinMaterial` with a
/// 0.5 pt primary border at 10 % opacity.
struct FreshliCardStyle: ViewModifier {
    var cornerRadius: CGFloat = PSSpacing.radiusLg
    var shadowRadius: CGFloat = 12
    var shadowOpacity: Double = 0.06

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: PSColors.textPrimary.opacity(shadowOpacity), radius: shadowRadius, y: 4)
    }
}

extension View {
    /// Apply the Freshli glass-card treatment.
    func freshliCard(cornerRadius: CGFloat = PSSpacing.radiusLg) -> some View {
        modifier(FreshliCardStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - 4. Iconography — SF Symbols 6.0 with Variable Color & Animation

/// Centralised icon catalogue using SF Symbols 6.0.
/// Every icon supports Variable Color for state transitions and SymbolEffect animations.
enum FreshliIcon {
    // Tab bar
    static let pantry          = "refrigerator.fill"
    static let impact          = "leaf.fill"
    static let community       = "person.2.fill"
    static let recipes         = "frying.pan.fill"
    static let profile         = "person.crop.circle.fill"

    // Actions
    static let scan            = "barcode.viewfinder"
    static let addItem         = "plus.circle.fill"
    static let consume         = "checkmark.circle.fill"
    static let share           = "square.and.arrow.up"
    static let donate          = "hand.raised.fill"
    static let delete          = "trash.fill"

    // Status
    static let fresh           = "leaf.fill"              // Variable color: 0→1 as freshness
    static let expiringSoon    = "exclamationmark.triangle.fill"
    static let expired         = "xmark.octagon.fill"
    static let streak          = "flame.fill"

    // Celebrations
    static let milestone       = "star.circle.fill"
    static let confetti        = "party.popper.fill"

    // System
    static let calendar        = "calendar.badge.clock"
    static let reminder        = "checklist"
    static let notification    = "bell.badge.fill"
    static let settings        = "gearshape.fill"
}

/// View modifier that applies SF Symbols 6.0 Variable Color and SymbolEffect animations.
struct FreshliSymbolModifier: ViewModifier {
    let variableValue: Double  // 0.0 … 1.0
    let animateOnAppear: Bool

    func body(content: Content) -> some View {
        content
            .symbolRenderingMode(.hierarchical)
            .symbolEffect(.variableColor.iterative, value: variableValue)
            .symbolEffect(.bounce, options: animateOnAppear ? .repeating : .nonRepeating, value: animateOnAppear)
    }
}

extension Image {
    /// Apply Freshli's variable-color + bounce animation to an SF Symbol.
    func freshliSymbol(variableValue: Double = 1.0, animateOnAppear: Bool = false) -> some View {
        self
            .symbolRenderingMode(.hierarchical)
            .modifier(FreshliSymbolModifier(variableValue: variableValue, animateOnAppear: animateOnAppear))
    }
}

// MARK: - 5. Global Button Styles — Capsule + ControlSize

/// Modern, friendly primary button using `ButtonBorderShape.capsule`.
struct FreshliPrimaryButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(fontForControlSize)
            .fontDesign(.rounded)
            .fontWeight(.bold)
            .tracking(-0.3)
            .padding(.horizontal, horizontalPadding)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                Capsule(style: .continuous)
                    .fill(FreshliColor.freshliGreen)
                    .shadow(color: FreshliColor.freshliGreen.opacity(0.35), radius: 10, y: 6)
            )
            .clipShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var height: CGFloat {
        switch controlSize {
        case .mini:        return 32
        case .small:       return 38
        case .regular:     return 50
        case .large:       return 56
        case .extraLarge:  return 64
        @unknown default:  return 50
        }
    }

    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini, .small: return 16
        case .regular:      return 24
        case .large:        return 32
        case .extraLarge:   return 40
        @unknown default:   return 24
        }
    }

    private var fontForControlSize: Font {
        switch controlSize {
        case .mini, .small: return .system(.subheadline, design: .rounded, weight: .bold)
        case .regular:      return .system(.body, design: .rounded, weight: .bold)
        case .large, .extraLarge: return .system(.title3, design: .rounded, weight: .bold)
        @unknown default:   return .system(.body, design: .rounded, weight: .bold)
        }
    }
}

/// Secondary outline capsule button.
struct FreshliSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .tracking(-0.2)
            .padding(.horizontal, 24)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .foregroundStyle(FreshliColor.freshliGreen)
            .background(
                Capsule(style: .continuous)
                    .stroke(FreshliColor.freshliGreen, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Freshli Design System") {
    ScrollView {
        VStack(spacing: 24) {
            // Typography
            Text("£42 Saved")
                .freshliFont(.freshliDisplayLarge)

            Text("Your Impact This Week")
                .freshliFont(.freshliDisplayMedium)

            // Glass card
            VStack(alignment: .leading, spacing: 12) {
                Label("Expiring Tomorrow", systemImage: FreshliIcon.expiringSoon)
                    .font(.freshliBodyMedium)
                    .foregroundStyle(FreshliColor.expiryAmber)
                Text("3 items need attention before they expire.")
                    .font(.freshliSubheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .freshliCard()

            // Icons with variable color
            HStack(spacing: 20) {
                Image(systemName: FreshliIcon.fresh)
                    .freshliSymbol(variableValue: 0.8, animateOnAppear: true)
                    .foregroundStyle(FreshliColor.freshliGreen)
                    .font(.title)

                Image(systemName: FreshliIcon.streak)
                    .freshliSymbol(variableValue: 1.0, animateOnAppear: true)
                    .foregroundStyle(FreshliColor.impactGold)
                    .font(.title)

                Image(systemName: FreshliIcon.milestone)
                    .freshliSymbol(variableValue: 0.5)
                    .foregroundStyle(FreshliColor.impactGold)
                    .font(.title)
            }

            // Buttons
            Button("Save to Pantry") {}
                .buttonStyle(FreshliPrimaryButtonStyle())
                .controlSize(.large)

            Button("View Recipes") {}
                .buttonStyle(FreshliSecondaryButtonStyle())
        }
        .padding()
    }
}
