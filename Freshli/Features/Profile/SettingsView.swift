import SwiftUI
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
    @Environment(\.accessibilityReduceMotion) private var a11yReduceMotion

    @State private var appeared = false

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
                settingsToggle(
                    icon: "bell.badge.fill",
                    title: String(localized: "Expiry Reminders"),
                    tint: PSColors.secondaryAmber,
                    isOn: $notificationsEnabled
                )
            } header: {
                Text(String(localized: "Notifications"))
            }

            // MARK: - About
            Section {
                settingsRow(icon: "info.circle", title: String(localized: "Version"), detail: "1.0.0")
                settingsLink(icon: "doc.text", title: String(localized: "Privacy Policy"), url: "https://freshli.app/privacy")
                settingsLink(icon: "doc.plaintext", title: String(localized: "Terms of Service"), url: "https://freshli.app/terms")
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
