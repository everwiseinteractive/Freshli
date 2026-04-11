import SwiftUI

// MARK: - FreshliButton
//
// The one button to rule them all. Designed to an Apple Design Award
// standard and kept in lock-step with the Figma design system
// (file gXx6DiPSJdbj4ahzkzNxW6 · page "03 — FreshliButton").
//
//   • 4 variants: primary, secondary, destructive, mission
//   • 4 states (driven by SwiftUI):
//       default   — the baseline
//       pressed   — scale 0.96, opacity 0.92, signature spring
//       disabled  — opacity 0.4, disabled(true)
//       loading   — shows an inline spinner next to the label, blocks taps
//   • Haptic on touch-DOWN (not touch-up) so the response feels instant,
//     via a long-press gesture layered under the button's tap.
//   • Supports leading/trailing SF Symbol icons, full-width sizing, and
//     an optional async action (with automatic loading state management).
//
// Usage:
//
//   FreshliButton("Start Cooking", systemImage: "flame.fill") {
//       // sync action
//   }
//
//   FreshliButton("Rescue Now", variant: .mission, isFullWidth: true) {
//       await viewModel.performRescue()
//   }
//
//   FreshliButton("Delete", variant: .destructive, icon: "trash") {
//       showDeleteConfirmation = true
//   }

enum FreshliButtonVariant {
    case primary
    case secondary
    case destructive
    case mission
}

enum FreshliButtonSize {
    case small      // 40pt tall
    case medium     // 48pt tall
    case large      // 56pt tall — the default
    case extraLarge // 64pt tall — hero CTAs

    var height: CGFloat {
        switch self {
        case .small:      return 40
        case .medium:     return 48
        case .large:      return 56
        case .extraLarge: return 64
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small:      return 13
        case .medium:     return 15
        case .large:      return 16
        case .extraLarge: return 18
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small:      return 13
        case .medium:     return 15
        case .large:      return 17
        case .extraLarge: return 20
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small:      return 12
        case .medium:     return 14
        case .large:      return 18
        case .extraLarge: return 20
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small:      return 14
        case .medium:     return 18
        case .large:      return 22
        case .extraLarge: return 26
        }
    }
}

// MARK: - Main Button

struct FreshliButton: View {
    // MARK: - Inputs

    let label: String
    var systemImage: String? = nil
    var trailingSymbol: String? = nil
    var variant: FreshliButtonVariant = .primary
    var size: FreshliButtonSize = .large
    var isFullWidth: Bool = false
    var isDisabled: Bool = false
    var syncAction: (() -> Void)? = nil
    var asyncAction: (() async -> Void)? = nil

    // MARK: - Internal state

    @State private var isLoading: Bool = false
    @State private var isPressed: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initializers (ergonomic API)

    /// Sync action initializer.
    init(
        _ label: String,
        systemImage: String? = nil,
        trailingSymbol: String? = nil,
        variant: FreshliButtonVariant = .primary,
        size: FreshliButtonSize = .large,
        isFullWidth: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.trailingSymbol = trailingSymbol
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.isDisabled = isDisabled
        self.syncAction = action
        self.asyncAction = nil
    }

    /// Async action initializer — automatically manages the loading state
    /// while the action runs. Re-enables once the action resolves.
    init(
        _ label: String,
        systemImage: String? = nil,
        trailingSymbol: String? = nil,
        variant: FreshliButtonVariant = .primary,
        size: FreshliButtonSize = .large,
        isFullWidth: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () async -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.trailingSymbol = trailingSymbol
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.isDisabled = isDisabled
        self.syncAction = nil
        self.asyncAction = action
    }

    // MARK: - Body

    var body: some View {
        Button(action: handleTap) {
            content
                .frame(height: size.height)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, size.horizontalPadding)
                .background(backgroundFill)
                .overlay(borderOverlay)
                .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
                .shadow(
                    color: shadowColor,
                    radius: isPressed ? shadowRadius * 0.6 : shadowRadius,
                    x: 0,
                    y: isPressed ? shadowOffsetY * 0.5 : shadowOffsetY
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.4 : (isLoading ? 0.85 : 1.0))
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(
            reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
            value: isPressed
        )
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.2),
            value: isLoading
        )
        // Press tracking — gives us a pressed scale/opacity state. We
        // use a simultaneous long-press so the button's tap still works.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isPressed && !isDisabled && !isLoading else { return }
                    isPressed = true
                    // Haptic fires on touch-DOWN for instant responsiveness
                    PSHaptics.shared.lightTap()
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .accessibilityLabel(label)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        HStack(spacing: size == .small ? 6 : 10) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(foregroundColor)
                    .transition(.opacity)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconSize, weight: .semibold))
                    .foregroundStyle(foregroundColor)
                    .transition(.opacity)
            }
            Text(label)
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let trailingSymbol, !isLoading {
                Image(systemName: trailingSymbol)
                    .font(.system(size: size.iconSize - 2, weight: .bold))
                    .foregroundStyle(foregroundColor.opacity(0.85))
            }
        }
    }

    // MARK: - Action Handling

    private func handleTap() {
        guard !isDisabled && !isLoading else { return }
        PSHaptics.shared.mediumTap()

        if let syncAction {
            syncAction()
        } else if let asyncAction {
            Task { @MainActor in
                withAnimation { isLoading = true }
                await asyncAction()
                withAnimation { isLoading = false }
            }
        }
    }

    // MARK: - Variant Styling (matches Figma spec 1:1)

    @ViewBuilder
    private var backgroundFill: some View {
        switch variant {
        case .primary:
            LinearGradient(
                colors: [PSColors.primaryGreen, Color(hex: 0x16A34A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            Color.white
        case .destructive:
            Color(hex: 0xFEE2E2)
        case .mission:
            LinearGradient(
                colors: [
                    FreshliBrand.missionAccentLight,
                    FreshliBrand.missionAccent,
                    FreshliBrand.planetBlue.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
        switch variant {
        case .primary:
            EmptyView()
        case .secondary:
            shape.strokeBorder(PSColors.primaryGreen, lineWidth: 1.5)
        case .destructive:
            EmptyView()
        case .mission:
            shape.strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary, .mission: return .white
        case .secondary:         return PSColors.primaryGreen
        case .destructive:       return Color(hex: 0xDC2626)
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .primary:     return PSColors.primaryGreen.opacity(0.35)
        case .secondary:   return .black.opacity(0.05)
        case .destructive: return Color(hex: 0xDC2626).opacity(0.15)
        case .mission:     return FreshliBrand.missionAccent.opacity(0.40)
        }
    }

    private var shadowRadius: CGFloat {
        switch variant {
        case .primary:     return 14
        case .secondary:   return 8
        case .destructive: return 10
        case .mission:     return 24
        }
    }

    private var shadowOffsetY: CGFloat {
        switch variant {
        case .primary:     return 6
        case .secondary:   return 4
        case .destructive: return 5
        case .mission:     return 10
        }
    }

    private var accessibilityHint: String {
        if isLoading     { return "Loading. Please wait." }
        if isDisabled    { return "Disabled" }
        switch variant {
        case .primary, .mission: return "Double tap to \(label.lowercased())"
        case .secondary:         return "Double tap for \(label.lowercased())"
        case .destructive:       return "Double tap to \(label.lowercased()). This action cannot be undone."
        }
    }
}

// MARK: - Preview

#Preview("All variants × states") {
    ScrollView {
        VStack(spacing: 24) {
            Group {
                Text("PRIMARY")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                FreshliButton("Start Cooking", systemImage: "flame.fill") { }
                FreshliButton("Rescue Now", systemImage: "leaf.fill", isFullWidth: true) { }
                FreshliButton("Disabled", isDisabled: true) { }
            }

            Divider()

            Group {
                Text("SECONDARY")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                FreshliButton("Share", systemImage: "hand.raised", variant: .secondary) { }
                FreshliButton("Save it for Later", systemImage: "snowflake", variant: .secondary, isFullWidth: true) { }
            }

            Divider()

            Group {
                Text("DESTRUCTIVE")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                FreshliButton("Delete Item", systemImage: "trash", variant: .destructive, isFullWidth: true) { }
            }

            Divider()

            Group {
                Text("MISSION")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                FreshliButton("Rescue This Now", systemImage: "sparkles", variant: .mission, size: .extraLarge, isFullWidth: true) { }
                FreshliButton("Cook Hands-Free", systemImage: "waveform", trailingSymbol: "chevron.right", variant: .mission, isFullWidth: true) { }
            }

            Divider()

            Group {
                Text("SIZES")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                FreshliButton("Small", size: .small) { }
                FreshliButton("Medium", size: .medium) { }
                FreshliButton("Large", size: .large) { }
                FreshliButton("Extra Large", size: .extraLarge) { }
            }

            Divider()

            Group {
                Text("ASYNC (loading state)")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                FreshliButton("Save to Pantry", systemImage: "plus.circle.fill", isFullWidth: true) {
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
        .padding()
    }
    .background(PSColors.backgroundSecondary)
}
