import SwiftUI

// Figma: buttonVariants — rounded-2xl, font-bold, tracking-tight
// Sizes: default h-14 px-8, sm h-10 px-4, lg h-16 px-10

enum PSButtonStyle {
    case primary
    case secondary
    case tertiary
    case destructive
}

enum PSButtonSize {
    case small
    case medium
    case large

    var height: CGFloat {
        switch self {
        case .small: return 40    // Figma: h-10
        case .medium: return 56   // Figma: h-14 (default)
        case .large: return 64    // Figma: h-16
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 16    // Figma: px-4
        case .medium: return 32   // Figma: px-8
        case .large: return 40    // Figma: px-10
        }
    }

    var font: Font {
        switch self {
        case .small: return .system(size: 14, weight: .bold)
        case .medium: return .system(size: 16, weight: .bold)
        case .large: return .system(size: 16, weight: .bold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return PSSpacing.radiusMd  // Figma: rounded-xl
        case .medium: return PSSpacing.radiusLg  // Figma: rounded-2xl
        case .large: return PSSpacing.radiusLg   // Figma: rounded-2xl
        }
    }
}

struct PSButton: View {
    let title: String
    var icon: String?
    var style: PSButtonStyle = .primary
    var size: PSButtonSize = .large
    var isFullWidth: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    @State private var tapTrigger = false

    /// Material density for the refraction ripple — primary/destructive
    /// use `.high` for a thick, viscous glass feel; secondary `.med`;
    /// tertiary `.low` for a subtle air-like ripple.
    private var rippleDensity: FLMaterialDensity {
        switch style {
        case .primary, .destructive: return .high
        case .secondary: return .med
        case .tertiary: return .low
        }
    }

    var body: some View {
        Button {
            // Destructive buttons keep their heavy tap override
            if style == .destructive {
                PSHaptics.shared.heavyTap()
            }
            // Other haptics handled by LiquidGlassPressStyle (glassRipple)
            tapTrigger.toggle()
            action()
        } label: {
            HStack(spacing: PSSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                        .controlSize(.small)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(size.font)
                    }
                    Text(title)
                        .font(size.font)
                        .tracking(-0.3)
                }
            }
            .frame(height: size.height)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, isFullWidth ? 0 : size.horizontalPadding)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            // Dynamic shadow — direction + intensity adapt to ambient light.
            // Dark rooms: warm OLED glow; bright rooms: faint washed shadow.
            .dynamicElevation(buttonElevation, color: shadowColor)
        }
        .buttonStyle(PressableButtonStyle(density: rippleDensity))
        .hoverSpecular(intensity: 0.4, cornerRadius: size.cornerRadius)
        .sensoryFeedback(.impact(weight: .light), trigger: tapTrigger)
        .accessibilityLabel(isLoading ? String(localized: "Loading") : title)
        .accessibilityAddTraits([.isButton])
        .accessibilityHint(isLoading ? String(localized: "Please wait") : "")
        .disabled(isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary: return PSColors.primaryGreen
        case .tertiary: return PSColors.textSecondary
        case .destructive: return .white
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return PSColors.primaryGreen
        case .secondary: return PSColors.primaryGreen.opacity(0.12)
        case .tertiary: return .clear
        case .destructive: return PSColors.expiredRed
        }
    }

    // Figma: shadow-lg shadow-green-500/30
    private var shadowColor: Color {
        switch style {
        case .primary: return PSColors.primaryGreen.opacity(0.3)
        case .destructive: return PSColors.expiredRed.opacity(0.3)
        default: return .clear
        }
    }

    /// Elevation level for ambient-adaptive shadow casting.
    /// Primary/destructive buttons float higher for more dramatic shadows.
    private var buttonElevation: FLElevation {
        switch style {
        case .primary, .destructive: return .z3
        case .secondary: return .z2
        case .tertiary: return .z0
        }
    }
}

// Figma: icon variant — bg-white border border-neutral-200 shadow-sm rounded-full w-12 h-12
struct PSIconButton: View {
    let icon: String
    var size: CGFloat = 44
    var tint: Color = PSColors.textSecondary
    var background: Color = PSColors.backgroundSecondary
    let action: () -> Void

    var body: some View {
        Button {
            PSHaptics.shared.lightTap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(PressableButtonStyle(density: .low))
        .accessibilityLabel(icon)
        .accessibilityAddTraits(.isButton)
        .psMinTouchTarget()
    }
}

#Preview {
    VStack(spacing: 16) {
        PSButton(title: "Save to Pantry", icon: "plus", action: {})
        PSButton(title: "Share Item", style: .secondary, action: {})
        PSButton(title: "View Recipes", style: .tertiary, action: {})
        PSButton(title: "Delete", style: .destructive, action: {})
        HStack {
            PSIconButton(icon: "camera.fill", action: {})
            PSIconButton(icon: "barcode.viewfinder", action: {})
            PSIconButton(icon: "bell.fill", tint: PSColors.primaryGreen, action: {})
        }
    }
    .padding()
}
