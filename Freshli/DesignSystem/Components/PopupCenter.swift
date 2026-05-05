import SwiftUI
import UIKit
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - Popup System
//
// Every full-screen popup in Freshli (Celebration, Recipe Match, First
// Item Added, Achievement Unlock, Streak, Weekly Recap, etc.) routes
// through this single system. It guarantees four things that the prior
// `ZStack-overlay-on-root` approach could not:
//
//   1. **Top-most rendering** — popups appear ABOVE sheets, fullScreenCovers,
//      system alerts, and the keyboard. The overlay lives in its own
//      transparent UIWindow at level `.alert + 1`, so any modal presented
//      from anywhere in the app renders below it.
//   2. **Animated entrance + exit** — every popup runs the same staggered
//      cascade (background → icon bounce → title slide → subtitle fade →
//      CTA rise) honoring Reduce Motion.
//   3. **Clear acknowledge button** — every popup has exactly one CTA
//      that the user must tap. No swipe-to-dismiss. No tap-outside-to-
//      dismiss. The CTA owns the dismissal so the user always
//      acknowledges the message.
//   4. **Centred, no cutoffs, perfect on every device** — uses adaptive
//      sizing tied to the active window scene's safe area. Works at
//      iPhone SE through 17 Pro Max, iPad mini through Pro, all
//      orientations, AX1–AX5 Dynamic Type.
//
// PopupCenter is a singleton so any feature can call
// `PopupCenter.shared.present(.celebration(...))` without worrying about
// passing a presenter through view hierarchies. Multiple popups queue
// FIFO and present sequentially with a 400ms gap.
// ══════════════════════════════════════════════════════════════════

// MARK: - Popup data

/// A single popup descriptor. All Freshli popups conform to this shape
/// — there is one renderer (`PopupRootView`) that handles every variant.
public struct Popup: Identifiable, Sendable {
    public let id = UUID()
    public let icon: String                 // SF Symbol name
    public let title: String
    public let message: String
    public let primaryCTA: String           // Always required — the acknowledge button
    public let backgroundTint: PopupTint
    public let confettiCount: Int           // 0 = no confetti
    public let intensity: PopupIntensity
    public let onAcknowledge: @MainActor @Sendable () -> Void

    public init(
        icon: String,
        title: String,
        message: String,
        primaryCTA: String = String(localized: "Continue"),
        backgroundTint: PopupTint = .green,
        confettiCount: Int = 24,
        intensity: PopupIntensity = .standard,
        onAcknowledge: @MainActor @Sendable @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.primaryCTA = primaryCTA
        self.backgroundTint = backgroundTint
        self.confettiCount = confettiCount
        self.intensity = intensity
        self.onAcknowledge = onAcknowledge
    }
}

public enum PopupIntensity: Sendable {
    case low, standard, high
}

public enum PopupTint: Sendable {
    case green, amber, blue, purple, gold, red

    var background: Color {
        switch self {
        case .green:  return Color(red: 0.133, green: 0.773, blue: 0.369)   // #22C55E
        case .amber:  return Color(red: 0.961, green: 0.620, blue: 0.043)   // #F59E0B
        case .blue:   return Color(red: 0.231, green: 0.510, blue: 0.965)   // #3B82F6
        case .purple: return Color(red: 0.553, green: 0.361, blue: 0.965)   // #8B5CF6
        case .gold:   return Color(red: 1.000, green: 0.820, blue: 0.000)   // #FFD100
        case .red:    return Color(red: 0.831, green: 0.094, blue: 0.239)   // #D4183D
        }
    }

    var pulseColor: Color {
        background.opacity(0.6)
    }

    var iconBackground: Color {
        background.opacity(0.85)
    }

    var ctaTextColor: Color {
        switch self {
        case .gold: return .black
        default:    return background
        }
    }
}

// MARK: - PopupCenter (singleton coordinator)

@Observable @MainActor
public final class PopupCenter {
    public static let shared = PopupCenter()

    private(set) var current: Popup?
    private var queue: [Popup] = []
    private let logger = Logger(subsystem: "com.freshli.app", category: "PopupCenter")

    /// The dedicated overlay window. Created lazily on first present
    /// and torn down when the queue empties so it doesn't intercept
    /// hit-testing when no popup is showing.
    private var overlayWindow: UIWindow?

    private init() {}

    // MARK: - Public API

    public func present(_ popup: Popup) {
        if current == nil {
            show(popup)
        } else {
            queue.append(popup)
            logger.debug("Popup queued (queue depth \(self.queue.count))")
        }
    }

    public func dismiss() {
        guard let dismissed = current else { return }
        logger.debug("Dismissing popup \(dismissed.id.uuidString, privacy: .public)")

        // Run the user's acknowledge callback BEFORE animating out, so any
        // navigation triggered by it happens with the popup still visible
        // (smoother transition).
        dismissed.onAcknowledge()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            current = nil
        }

        // Tear down or move on to the next queued popup
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(380))
            guard let self else { return }
            if let next = self.queue.first {
                self.queue.removeFirst()
                self.show(next)
            } else {
                self.tearDownWindow()
            }
        }
    }

    public func dismissAll() {
        queue.removeAll()
        if current != nil { dismiss() }
    }

    // MARK: - Internal

    private func show(_ popup: Popup) {
        ensureWindow()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            current = popup
        }
        logger.info("Presenting popup \(popup.id.uuidString, privacy: .public): \(popup.title, privacy: .public)")
    }

    /// Build (or reuse) the overlay window that sits above all sheets,
    /// fullScreenCovers, and the keyboard. Must run on the active scene.
    private func ensureWindow() {
        guard overlayWindow == nil else { return }
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else {
            logger.warning("No active UIWindowScene — popup cannot present.")
            return
        }

        let window = PassThroughWindow(windowScene: windowScene)
        window.backgroundColor = .clear
        window.windowLevel = .alert + 1
        window.rootViewController = UIHostingController(rootView: PopupRootView(center: self))
        window.rootViewController?.view.backgroundColor = .clear
        window.isHidden = false
        overlayWindow = window
    }

    private func tearDownWindow() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }
}

// MARK: - PassThroughWindow
//
// A UIWindow that lets touches fall through to the windows below when no
// popup view is in the way. Without this, the overlay window — even when
// transparent — would swallow every tap in the app.

private final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        // The hosting controller's root view is transparent; if the hit
        // landed on it directly (no popup child intercepted), pass the
        // touch through to the next window.
        return hit === rootViewController?.view ? nil : hit
    }
}

// MARK: - PopupRootView

private struct PopupRootView: View {
    @Bindable var center: PopupCenter

    var body: some View {
        ZStack {
            if let popup = center.current {
                PopupView(popup: popup)
                    .id(popup.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 1.06))
                    ))
            }
        }
    }
}

// MARK: - PopupView (the single source of visual truth)

private struct PopupView: View {
    let popup: Popup

    @State private var showBackground = false
    @State private var showIcon = false
    @State private var showTitle = false
    @State private var showMessage = false
    @State private var showCTA = false
    @State private var iconBounce = 0
    @State private var ctaScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Layer 1: Vibrant solid backdrop covering the full screen
                // including safe areas. Tap-blocked — the user MUST press
                // the acknowledge button.
                popup.backgroundTint.background
                    .ignoresSafeArea()
                    .opacity(showBackground ? 1 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture { /* swallow taps */ }

                // Layer 2: Centred content stack with adaptive sizing.
                // The VStack auto-sizes; we cap maximum width on iPad so
                // the content stays visually balanced without stretching
                // edge-to-edge on a 13" canvas.
                VStack(spacing: spacing(for: proxy.size)) {
                    Spacer(minLength: topSpacer(for: proxy.size))

                    iconBlock(size: iconSize(for: proxy.size))
                        .opacity(showIcon ? 1 : 0)
                        .scaleEffect(showIcon ? 1.0 : 0.4)

                    titleBlock
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 18)

                    messageBlock
                        .opacity(showMessage ? 1 : 0)
                        .offset(y: showMessage ? 0 : 14)

                    Spacer(minLength: 16)

                    ctaBlock
                        .opacity(showCTA ? 1 : 0)
                        .offset(y: showCTA ? 0 : 32)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 24, 40))
                }
                .frame(maxWidth: contentMaxWidth(for: proxy.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, horizontalPadding(for: proxy.size))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(popup.title). \(popup.message)")
            .accessibilityAddTraits(.isModal)
            .onAppear { runEntrance() }
        }
    }

    // MARK: - Subviews

    private func iconBlock(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(popup.backgroundTint.iconBackground.opacity(0.35))
                .frame(width: size * 1.45, height: size * 1.45)
                .blur(radius: 30)

            Circle()
                .fill(popup.backgroundTint.iconBackground)
                .frame(width: size, height: size)
                .shadow(color: popup.backgroundTint.background.opacity(0.5), radius: 20, y: 8)
                .overlay {
                    Image(systemName: popup.icon)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: iconBounce)
                        .accessibilityHidden(true)
                }
        }
    }

    private var titleBlock: some View {
        Text(popup.title)
            .font(.system(.largeTitle, design: .rounded, weight: .black))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.7)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var messageBlock: some View {
        Text(popup.message)
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .minimumScaleFactor(0.85)
            .lineLimit(6)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var ctaBlock: some View {
        Button(action: tapAcknowledge) {
            Text(popup.primaryCTA)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(popup.backgroundTint.ctaTextColor)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.horizontal, 24)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
        .scaleEffect(ctaScale)
        .accessibilityHint(String(localized: "Acknowledges and dismisses this message"))
    }

    // MARK: - Sizing helpers

    private func iconSize(for size: CGSize) -> CGFloat {
        // Adaptive icon: smaller on compact-width (SE) so title still fits.
        let base = min(size.width, size.height)
        if base < 380 { return 92 }       // iPhone SE
        if base < 430 { return 112 }      // iPhone 16/17, Pro
        if base < 768 { return 128 }      // iPhone Pro Max
        return 156                        // iPad
    }

    private func spacing(for size: CGSize) -> CGFloat {
        size.height < 700 ? 18 : 26
    }

    private func topSpacer(for size: CGSize) -> CGFloat {
        // Push content slightly above optical centre to accommodate
        // longer titles on AX5 dynamic type.
        size.height * 0.10
    }

    private func contentMaxWidth(for size: CGSize) -> CGFloat {
        // Cap on iPad so the popup stays visually balanced.
        size.width > 600 ? 520 : .infinity
    }

    private func horizontalPadding(for size: CGSize) -> CGFloat {
        size.width < 380 ? 22 : 28
    }

    // MARK: - Entrance cascade

    private func runEntrance() {
        if reduceMotion {
            showBackground = true
            showIcon = true
            showTitle = true
            showMessage = true
            showCTA = true
            return
        }

        withAnimation(.easeOut(duration: 0.32)) { showBackground = true }
        withAnimation(.spring(duration: 0.55, bounce: 0.42).delay(0.12)) { showIcon = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(380))
            iconBounce += 1
        }
        withAnimation(.spring(duration: 0.50, bounce: 0.25).delay(0.30)) { showTitle = true }
        withAnimation(.spring(duration: 0.48, bounce: 0.18).delay(0.46)) { showMessage = true }
        withAnimation(.spring(duration: 0.55, bounce: 0.32).delay(0.62)) { showCTA = true }
    }

    private func tapAcknowledge() {
        // Quick scale-down for tactile feedback, then dismiss.
        if reduceMotion {
            PopupCenter.shared.dismiss()
            return
        }
        withAnimation(.spring(duration: 0.12, bounce: 0)) { ctaScale = 0.94 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.spring(duration: 0.18, bounce: 0.2)) { ctaScale = 1.0 }
            PopupCenter.shared.dismiss()
        }
    }
}
