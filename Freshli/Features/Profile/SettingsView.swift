import SwiftUI
import UserNotifications
import os

// MARK: - Settings View
// Opened from Profile gear button. Provides app-level settings.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncService.self) private var syncService
    @Environment(NetworkMonitor.self) private var networkMonitor
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("expiryReminderDays") private var expiryReminderDays = 3
    @Environment(\.accessibilityReduceMotion) private var a11yReduceMotion

    @State private var appeared = false
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    private let logger = Logger(subsystem: "com.freshli.app", category: "SettingsView")

    var body: some View {
        List {
            // MARK: - Appearance
            Section {
                settingsToggle(
                    icon: "moon.fill",
                    title: String(localized: "Dark Mode"),
                    tint: Color(hex: 0x6366F1),
                    isOn: $isDarkMode
                )
                settingsToggle(
                    icon: "wind",
                    title: String(localized: "Reduce Motion"),
                    tint: PSColors.accentTeal,
                    isOn: $reduceMotion
                )
            } header: {
                Text(String(localized: "Appearance"))
            }

            // MARK: - Notifications
            Section {
                if notificationAuthStatus == .denied {
                    // System permission denied — guide user to OS Settings
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.expiredRed)
                            .frame(width: 28, height: 28)
                            .background(PSColors.expiredRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Notifications Blocked"))
                                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                            Text(String(localized: "Tap to enable in iOS Settings"))
                                .font(.system(size: PSLayout.scaledFont(12)))
                                .foregroundStyle(PSColors.textTertiary)
                        }
                        Spacer()
                        Button {
                            openNotificationSettings()
                        } label: {
                            Text(String(localized: "Open Settings"))
                                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                                .foregroundStyle(PSColors.primaryGreen)
                        }
                    }
                } else {
                    // Authorized or not yet determined — show toggle
                    settingsToggle(
                        icon: "bell.badge.fill",
                        title: String(localized: "Expiry Reminders"),
                        tint: PSColors.secondaryAmber,
                        isOn: $notificationsEnabled
                    )
                    .onChange(of: notificationsEnabled) { _, enabled in
                        guard enabled else { return }
                        // If permission not yet asked, request it now
                        if notificationAuthStatus == .notDetermined {
                            Task {
                                let service = NotificationService()
                                await service.requestAuthorization()
                                let settings = await UNUserNotificationCenter.current().notificationSettings()
                                notificationAuthStatus = settings.authorizationStatus
                                // If denied, revert the toggle
                                if settings.authorizationStatus == .denied {
                                    notificationsEnabled = false
                                }
                            }
                        }
                    }

                    // Reminder timing — only shown when notifications are on and authorized
                    if notificationsEnabled && notificationAuthStatus == .authorized {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.badge.fill")
                                .font(.system(size: PSLayout.scaledFont(16)))
                                .foregroundStyle(PSColors.secondaryAmber)
                                .frame(width: 28, height: 28)
                                .background(PSColors.secondaryAmber.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            Text(String(localized: "Remind me"))
                                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                            Spacer()
                            Picker("", selection: $expiryReminderDays) {
                                Text(String(localized: "1 day before")).tag(1)
                                Text(String(localized: "2 days before")).tag(2)
                                Text(String(localized: "3 days before")).tag(3)
                                Text(String(localized: "5 days before")).tag(5)
                                Text(String(localized: "1 week before")).tag(7)
                            }
                            .labelsHidden()
                            .tint(PSColors.primaryGreen)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Notifications"))
            } footer: {
                if notificationAuthStatus == .denied {
                    Text(String(localized: "Freshli needs notification permission to alert you before food expires."))
                }
            }

            // MARK: - About
            Section {
                NavigationLink {
                    FreshliAboutView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "leaf.circle.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.primaryGreen)
                            .frame(width: 28, height: 28)
                            .background(PSColors.primaryGreen.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(String(localized: "About Freshli"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        Spacer()
                    }
                }
                NavigationLink {
                    FreshliPrivacyPolicyView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(Color(hex: 0x6366F1))
                            .frame(width: 28, height: 28)
                            .background(Color(hex: 0x6366F1).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(String(localized: "Privacy Policy"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        Spacer()
                    }
                }
                NavigationLink {
                    FreshliTermsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: PSLayout.scaledFont(16)))
                            .foregroundStyle(PSColors.accentTeal)
                            .frame(width: 28, height: 28)
                            .background(PSColors.accentTeal.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(String(localized: "Terms of Service"))
                            .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                        Spacer()
                    }
                }
                settingsRow(
                    icon: "app.badge",
                    title: String(localized: "Version"),
                    detail: (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") + " (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))"
                )
            } header: {
                Text(String(localized: "About"))
            }

            // MARK: - Data
            Section {
                settingsRow(icon: "arrow.triangle.2.circlepath", title: String(localized: "Sync Status"), detail: syncStatusText)
            } header: {
                Text(String(localized: "Data"))
            }

            #if DEBUG
            // MARK: - Debug (only in debug builds)
            Section {
                NavigationLink {
                    ImpactDiagnosticView()
                } label: {
                    Label {
                        Text("Impact Diagnostics")
                            .font(.system(size: 15, weight: .medium))
                    } icon: {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(Color.orange)
                    }
                }
            } header: {
                Text("Debug")
            }
            #endif
        }
        .navigationTitle(String(localized: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Done")) { dismiss() }
                    .fontWeight(.semibold)
                    .foregroundStyle(PSColors.primaryGreen)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .task {
            // Always re-check the OS permission state when this screen appears,
            // in case the user changed it in the system Settings app.
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationAuthStatus = settings.authorizationStatus
        }
        .onAppear {
            logger.info("SettingsView appeared")
            let base: Animation = (a11yReduceMotion || reduceMotion)
                ? .easeOut(duration: 0.2)
                : PSMotion.springDefault.delay(0.05)
            withAnimation(base) {
                appeared = true
            }
        }
    }

    // MARK: - Computed Properties

    private var syncStatusText: String {
        // Check offline status first
        if networkMonitor.isConnected == false {
            return String(localized: "Offline")
        }
        // Check if syncing
        if syncService.isSyncing == true {
            return String(localized: "Syncing...")
        }
        // Check pending items
        let pendingCount = OfflineSyncQueue.shared.pendingCount
        if pendingCount > 0 {
            return String(localized: "\(pendingCount) pending")
        }
        // Default: up to date
        return String(localized: "Up to date")
    }

    // MARK: - Actions

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Row Helpers

    private func settingsToggle(icon: String, title: String, tint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(16)))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(title)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
            Spacer()
            Toggle("", isOn: Binding(
                get: { isOn.wrappedValue },
                set: { newValue in
                    PSHaptics.shared.selection()
                    isOn.wrappedValue = newValue
                }
            ))
                .labelsHidden()
                .tint(PSColors.primaryGreen)
        }
    }

    private func settingsRow(icon: String, title: String, detail: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: PSLayout.scaledFont(16)))
                .foregroundStyle(PSColors.textSecondary)
                .frame(width: 28, height: 28)
                .background(PSColors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(title)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: PSLayout.scaledFont(14)))
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
    }

    private func settingsLink(icon: String, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(16)))
                    .foregroundStyle(PSColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(title)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(PSColors.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                    .foregroundStyle(PSColors.textTertiary)
            }
        }
    }
}
