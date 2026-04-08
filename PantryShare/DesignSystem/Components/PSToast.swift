import SwiftUI

// MARK: - Toast Type

enum PSToastType {
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
        case .itemConsumed(let name): return String(localized: "\(name) consumed — food saved!")
        case .itemShared(let name): return String(localized: "\(name) shared with community")
        case .itemDonated(let name): return String(localized: "\(name) marked for donation")
        case .itemDeleted(let name): return String(localized: "\(name) removed from pantry")
        case .itemAdded(let name): return String(localized: "\(name) added to pantry")
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
        case .success, .itemConsumed, .itemAdded: return PSColors.primaryGreen
        case .info, .itemShared: return PSColors.infoBlue
        case .warning: return PSColors.warningAmber
        case .error, .itemDeleted: return PSColors.expiredRed
        case .itemDonated: return PSColors.accentTeal
        }
    }
}

// MARK: - Toast Manager

@Observable
final class PSToastManager {
    var currentToast: PSToastType?
    var isShowing = false

    private var dismissTask: Task<Void, Never>?

    func show(_ toast: PSToastType, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()

        withAnimation(PSMotion.springBouncy) {
            currentToast = toast
            isShowing = true
        }

        PSHaptics.shared.lightTap()

        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(PSMotion.springQuick) {
                isShowing = false
            }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            currentToast = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(PSMotion.springQuick) {
            isShowing = false
        }
    }
}

// MARK: - Toast View

struct PSToastView: View {
    let toast: PSToastType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            Image(systemName: toast.icon)
                .font(.system(size: PSLayout.scaledFont(18), weight: .semibold))
                .foregroundStyle(toast.color)
                .symbolEffect(.bounce, value: true)

            Text(toast.message)
                .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                .foregroundStyle(PSColors.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, PSSpacing.xl)
        .padding(.vertical, PSSpacing.lg)
        .background {
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(toast.color.opacity(0.15), lineWidth: 1)
        }
        .padding(.horizontal, PSSpacing.screenHorizontal)
    }
}

// MARK: - Toast Overlay Modifier

struct PSToastOverlay: ViewModifier {
    let manager: PSToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if manager.isShowing, let toast = manager.currentToast {
                PSToastView(toast: toast)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                    .padding(.bottom, PSLayout.scaled(100))
                    .zIndex(999)
            }
        }
    }
}

extension View {
    func toastOverlay(manager: PSToastManager) -> some View {
        modifier(PSToastOverlay(manager: manager))
    }
}
