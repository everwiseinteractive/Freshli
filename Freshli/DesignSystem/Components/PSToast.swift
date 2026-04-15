import SwiftUI

// MARK: - Toast Type

enum FLToastType {
    case success(String)
    case info(String)
    case warning(String)
    case error(String)
    case itemConsumed(String)
    case itemShared(String)
    case itemDonated(String)
    case itemDeleted(String)
    case itemAdded(String)

    var message: String {
        switch self {
        case .success(let msg), .info(let msg), .warning(let msg), .error(let msg):
            return msg
        case .itemConsumed(let name):
            // Mission-aligned rotating impact phrase — every rescue feels
            // meaningful because the number is real and the framing alternates
            // between planet wins, people wins, and collective milestones.
            let total = CollectiveImpactService.shared.totalItemsRescued
            return FreshliBrand.impactPhrase(itemName: name, totalRescued: total)
        case .itemShared(let name): return String(localized: "\(name) shared — a neighbour just got lucky 🤝")
        case .itemDonated(let name): return String(localized: "\(name) donated — someone will eat well tonight 💚")
        case .itemDeleted(let name): return String(localized: "\(name) removed from pantry")
        case .itemAdded(let name): return String(localized: "\(name) added — one item closer to a zero-waste week 🌱")
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .itemConsumed: return "fork.knife"
        case .itemShared: return "hand.raised.fill"
        case .itemDonated: return "heart.fill"
        case .itemDeleted: return "trash.fill"
        case .itemAdded: return "plus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success, .itemConsumed, .itemAdded: return FLColors.primaryGreen
        case .info, .itemShared: return FLColors.infoBlue
        case .warning: return FLColors.warningAmber
        case .error, .itemDeleted: return FLColors.expiredRed
        case .itemDonated: return FLColors.accentTeal
        }
    }
}

// MARK: - Toast Manager

@Observable @MainActor
final class FLToastManager {
    var currentToast: FLToastType?
    var isShowing = false

    private var dismissTask: Task<Void, Never>?

    func show(_ toast: FLToastType, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()

        withAnimation(FLMotion.springBouncy) {
            currentToast = toast
            isShowing = true
        }

        FLHaptics.shared.lightTap()

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(FLMotion.springQuick) {
                isShowing = false
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            currentToast = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(FLMotion.springQuick) {
            isShowing = false
        }
    }
}

// MARK: - Toast View

struct FLToastView: View {
    let toast: FLToastType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: FLSpacing.md) {
            Image(systemName: toast.icon)
                .font(.system(size: FLLayout.scaledFont(18), weight: .semibold))
                .foregroundStyle(toast.color)
                .symbolEffect(.bounce, value: true)

            Text(toast.message)
                .font(.system(size: FLLayout.scaledFont(15), weight: .semibold))
                .foregroundStyle(FLColors.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, FLSpacing.xl)
        .padding(.vertical, FLSpacing.lg)
        // Liquid Glass (iOS 26) — toast refracts content behind it instead of
        // presenting a flat translucent pane.
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous))
        .highContrastGlass(cornerRadius: FLSpacing.radiusLg)
        .overlay {
            RoundedRectangle(cornerRadius: FLSpacing.radiusLg, style: .continuous)
                .strokeBorder(toast.color.opacity(0.15), lineWidth: 1)
        }
        .elevation(.z3)
        .padding(.horizontal, FLSpacing.screenHorizontal)
    }
}

// MARK: - Toast Overlay Modifier

struct FLToastOverlay: ViewModifier {
    let manager: FLToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if manager.isShowing, let toast = manager.currentToast {
                FLToastView(toast: toast)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                    .padding(.bottom, FLLayout.scaled(100))
                    .zIndex(999)
            }
        }
    }
}

extension View {
    func toastOverlay(manager: FLToastManager) -> some View {
        modifier(FLToastOverlay(manager: manager))
    }
}

// MARK: - Backward Compatibility
typealias PSToastManager = FLToastManager
typealias PSToastType = FLToastType
