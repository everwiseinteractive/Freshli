import SwiftUI
import UserNotifications
import CoreLocation

// MARK: - Beautiful Permissions View
// Warm, friendly permission requests for Notifications (expiry alerts) and Location (community sharing).

struct OnboardingPermissionsView: View {
    let onComplete: () -> Void

    @State private var appeared = false
    @State private var notificationGranted: Bool?
    @State private var locationGranted: Bool?
    @State private var currentPermission: PermissionType = .notifications
    @State private var locationDelegate = PermissionLocationDelegate()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum PermissionType {
        case notifications
        case location
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Permission card
            VStack(spacing: PSSpacing.xxl) {
                permissionIcon
                permissionText
                permissionActions
            }
            .padding(PSSpacing.xxxl)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .elevation(.z3)
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)

            Spacer()

            // Skip button
            Button {
                PSHaptics.shared.lightTap()
                advanceOrComplete()
            } label: {
                Text(String(localized: "Maybe later"))
                    .font(.system(size: PSLayout.scaledFont(15), weight: .medium))
                    .foregroundStyle(PSColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .padding(.bottom, PSLayout.screenHeight * 0.05)
            .opacity(appeared ? 1 : 0)
        }
        .animation(PSMotion.springDefault, value: currentPermission)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(PSMotion.springBouncy.delay(0.2)) {
                appeared = true
            }
        }
    }

    // MARK: - Permission Icon

    @ViewBuilder
    private var permissionIcon: some View {
        let config = currentPermission == .notifications
            ? (icon: "bell.badge.fill", color: PSColors.secondaryAmber, bg: Color(hex: 0xFEF3C7))
            : (icon: "location.fill", color: PSColors.infoBlue, bg: Color(hex: 0xDBEAFE))

        ZStack {
            // Outer ring
            Circle()
                .fill(config.bg.opacity(0.5))
                .frame(width: PSLayout.scaled(120), height: PSLayout.scaled(120))

            // Inner circle with icon
            Circle()
                .fill(
                    LinearGradient(
                        colors: [config.color, config.color.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                .shadow(color: config.color.opacity(0.3), radius: 16, y: 6)
                .overlay {
                    Image(systemName: config.icon)
                        .font(.system(size: PSLayout.scaledFont(34), weight: .medium))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, options: .nonRepeating)
                }

            // Small decorative badge
            if currentPermission == .notifications {
                notificationDecorations
            } else {
                locationDecorations
            }
        }
        .id(currentPermission)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        ))
    }

    private var notificationDecorations: some View {
        Group {
            // Mini alarm clock
            Image(systemName: "alarm.fill")
                .font(.system(size: PSLayout.scaledFont(16)))
                .foregroundStyle(PSColors.secondaryAmber)
                .padding(PSSpacing.sm)
                .background(.white)
                .clipShape(Circle())
                .elevation(.z1)
                .offset(x: PSLayout.scaled(48), y: PSLayout.scaled(-30))

            // Mini food emoji
            Text("🍎")
                .font(.system(size: PSLayout.scaledFont(18)))
                .padding(PSSpacing.xxs)
                .background(.white)
                .clipShape(Circle())
                .elevation(.z1)
                .offset(x: PSLayout.scaled(-50), y: PSLayout.scaled(25))
        }
    }

    private var locationDecorations: some View {
        Group {
            // Sharing icon
            Image(systemName: "person.2.fill")
                .font(.system(size: PSLayout.scaledFont(14)))
                .foregroundStyle(PSColors.infoBlue)
                .padding(PSSpacing.sm)
                .background(.white)
                .clipShape(Circle())
                .elevation(.z1)
                .offset(x: PSLayout.scaled(50), y: PSLayout.scaled(-28))

            // Map pin
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: PSLayout.scaledFont(18)))
                .foregroundStyle(PSColors.primaryGreen)
                .padding(PSSpacing.xxs)
                .background(.white)
                .clipShape(Circle())
                .elevation(.z1)
                .offset(x: PSLayout.scaled(-48), y: PSLayout.scaled(28))
        }
    }

    // MARK: - Permission Text

    @ViewBuilder
    private var permissionText: some View {
        VStack(spacing: PSSpacing.md) {
            if currentPermission == .notifications {
                Text(String(localized: "Never Miss an Expiry Date"))
                    .font(.system(size: PSLayout.scaledFont(24), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "We'll gently remind you before food goes bad — so nothing gets wasted and your wallet stays happy."))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            } else {
                Text(String(localized: "Find Food Near You"))
                    .font(.system(size: PSLayout.scaledFont(24), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(String(localized: "See neighbors sharing food nearby and connect with your local Freshli community. Your exact location is never shared."))
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .id(currentPermission)
        .transition(.asymmetric(
            insertion: .offset(x: 30).combined(with: .opacity),
            removal: .offset(x: -30).combined(with: .opacity)
        ))
    }

    // MARK: - Permission Actions

    @ViewBuilder
    private var permissionActions: some View {
        let config = currentPermission == .notifications
            ? (title: String(localized: "Enable Notifications"), color: PSColors.secondaryAmber)
            : (title: String(localized: "Share My Location"), color: PSColors.infoBlue)

        Button {
            PSHaptics.shared.mediumTap()
            requestCurrentPermission()
        } label: {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: currentPermission == .notifications ? "bell.fill" : "location.fill")
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                Text(config.title)
                    .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: PSLayout.scaled(56))
            .background(config.color)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .shadow(color: config.color.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(PressableButtonStyle())
        .id(currentPermission)
        .transition(.asymmetric(
            insertion: .offset(y: 20).combined(with: .opacity),
            removal: .offset(y: -20).combined(with: .opacity)
        ))
    }

    // MARK: - Permission Logic

    private func requestCurrentPermission() {
        switch currentPermission {
        case .notifications:
            requestNotifications()
        case .location:
            requestLocation()
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationGranted = granted
                PSHaptics.shared.success()
                advanceOrComplete()
            }
        }
    }

    private func requestLocation() {
        locationDelegate.onResult = { granted in
            locationGranted = granted
            PSHaptics.shared.success()
            onComplete()
        }
        locationDelegate.request()
    }

    private func advanceOrComplete() {
        if currentPermission == .notifications {
            withAnimation(PSMotion.springDefault) {
                currentPermission = .location
            }
        } else {
            onComplete()
        }
    }
}

// MARK: - Location Permission Delegate

@MainActor
private class PermissionLocationDelegate: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onResult: ((Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            onResult?(true)
        case .denied, .restricted:
            onResult?(false)
        case .notDetermined:
            break // Waiting for user response
        @unknown default:
            break
        }
    }
}

#Preview {
    ZStack {
        PSColors.green50.ignoresSafeArea()
        OnboardingPermissionsView(onComplete: {})
    }
}
