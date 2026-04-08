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

    var body: some View {
        Button {
            // Haptic feedback based on button style
            switch style {
            case .primary, .secondary, .tertiary:
                PSHaptics.shared.lightTap()
            case .destructive:
                PSHaptics.shared.heavyTap()
            }
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
            // Figma: shadow-lg = 0 10px 15px -3px rgb(0 0 0 / 0.1)
            .shadow(color: shadowColor, radius: 10, x: 0, y: 10)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(title)
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
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(icon)
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
