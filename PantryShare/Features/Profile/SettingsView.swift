import SwiftUI

// MARK: - Settings View
// Opened from Profile gear button. Provides app-level settings.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("reduceMotion") private var reduceMotion = false

    @State private var appeared = false

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
                settingsRow(icon: "doc.text", title: String(localized: "Privacy Policy"), detail: nil)
                settingsRow(icon: "doc.plaintext", title: String(localized: "Terms of Service"), detail: nil)
            } header: {
                Text(String(localized: "About"))
            }

            // MARK: - Data
            Section {
                settingsRow(icon: "arrow.triangle.2.circlepath", title: String(localized: "Sync Status"), detail: String(localized: "Up to date"))
            } header: {
                Text(String(localized: "Data"))
            }
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
            withAnimation(PSMotion.springDefault.delay(0.05)) {
                appeared = true
            }
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
}
