import SwiftUI

// MARK: - Freshli Legal Hub
// In-app Privacy Policy, Terms of Service, and About screen.
// Opened from Settings → About section.

// MARK: - About & Legal Router

struct FreshliAboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    private let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                // App identity hero
                heroSection

                // Legal document links
                legalLinks

                // App credits
                creditsSection
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.bottom, PSSpacing.xxxl)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle("About Freshli")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: PSSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, PSColors.accentTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: PSLayout.scaled(96), height: PSLayout.scaled(96))
                    .shadow(color: PSColors.primaryGreen.opacity(0.35), radius: 20, y: 8)

                Image(systemName: "leaf.fill")
                    .font(.system(size: PSLayout.scaledFont(44)))
                    .foregroundStyle(.white)
            }

            VStack(spacing: PSSpacing.xs) {
                Text("Freshli")
                    .font(.system(size: PSLayout.scaledFont(28), weight: .bold, design: .rounded))
                    .foregroundStyle(PSColors.textPrimary)

                Text("Never waste. Always fresh.")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: PSLayout.scaledFont(12)))
                    .foregroundStyle(PSColors.textTertiary)
                    .padding(.top, PSSpacing.xxs)
            }
        }
        .padding(.top, PSSpacing.xl)
    }

    // MARK: - Legal Links

    private var legalLinks: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Legal")
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                .foregroundStyle(PSColors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PSSpacing.xs)

            NavigationLink {
                FreshliPrivacyPolicyView()
            } label: {
                legalRow(icon: "hand.raised.fill", iconColor: Color(hex: 0x6366F1), title: "Privacy Policy")
            }

            NavigationLink {
                FreshliTermsView()
            } label: {
                legalRow(icon: "doc.text.fill", iconColor: PSColors.accentTeal, title: "Terms of Service")
            }

            NavigationLink {
                FreshliOpenSourceView()
            } label: {
                legalRow(icon: "chevron.left.forwardslash.chevron.right", iconColor: Color(hex: 0xF59E0B), title: "Open Source Licenses")
            }
        }
    }

    private func legalRow(icon: String, iconColor: Color, title: String) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                Image(systemName: icon)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: PSLayout.scaledFont(16), weight: .medium))
                .foregroundStyle(PSColors.textPrimary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                .strokeBorder(PSColors.border, lineWidth: 0.5)
        )
    }

    // MARK: - Credits

    private var creditsSection: some View {
        VStack(spacing: PSSpacing.md) {
            Text("Made with ♥ to fight food waste")
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)

            Text("© \(Calendar.current.component(.year, from: Date())) Freshli. All rights reserved.")
                .font(.system(size: PSLayout.scaledFont(11)))
                .foregroundStyle(PSColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, PSSpacing.lg)
    }
}

// MARK: - Privacy Policy

struct FreshliPrivacyPolicyView: View {
    var body: some View {
        FreshliLegalDocumentView(
            title: "Privacy Policy",
            lastUpdated: "January 2025",
            icon: "hand.raised.fill",
            iconColor: Color(hex: 0x6366F1),
            sections: [
                LegalSection(
                    heading: "Our Commitment to Your Privacy",
                    body: "At Freshli, your privacy is fundamental to everything we build. We collect only what is necessary to make Freshli work beautifully for you, and we never sell your data to third parties."
                ),
                LegalSection(
                    heading: "Information We Collect",
                    body: "• Pantry data you enter (food items, quantities, expiry dates)\n• Account information if you create an account (name, email)\n• Usage analytics to improve the app experience\n• Device identifiers for crash reporting\n\nWe do NOT collect your location beyond what you explicitly provide for community features."
                ),
                LegalSection(
                    heading: "How We Use Your Data",
                    body: "Your pantry data powers your personalized expiry alerts, recipe suggestions, and impact statistics. We use anonymised usage analytics to understand which features are helpful. We never use your personal food data for advertising."
                ),
                LegalSection(
                    heading: "Data Storage & Security",
                    body: "Your data is stored locally on your device using SwiftData, and optionally synced to our secure Supabase cloud backend. All data in transit is encrypted with TLS 1.3. Cloud data is encrypted at rest."
                ),
                LegalSection(
                    heading: "Sharing With Third Parties",
                    body: "We do not sell, trade, or transfer your personal information to outside parties. We may share anonymised, aggregated data (e.g. \"Freshli users collectively saved X tonnes of food\") with environmental partners."
                ),
                LegalSection(
                    heading: "Your Rights",
                    body: "You can export, correct, or delete your data at any time from the Profile screen. If you delete your account, all cloud data is permanently erased within 30 days.\n\nFor GDPR and CCPA requests, contact: privacy@freshli.app"
                ),
                LegalSection(
                    heading: "Cookies & Tracking",
                    body: "The Freshli app does not use browser cookies. We use Apple's App Tracking Transparency framework — you will be asked before any cross-app tracking occurs. You can always change this in iOS Settings → Privacy."
                ),
                LegalSection(
                    heading: "Children's Privacy",
                    body: "Freshli is not directed at children under 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with personal data, please contact us immediately."
                ),
                LegalSection(
                    heading: "Contact Us",
                    body: "Questions about privacy? We're human and we're happy to help.\n\nEmail: privacy@freshli.app\nWebsite: freshli.app/privacy"
                ),
            ]
        )
    }
}

// MARK: - Terms of Service

struct FreshliTermsView: View {
    var body: some View {
        FreshliLegalDocumentView(
            title: "Terms of Service",
            lastUpdated: "January 2025",
            icon: "doc.text.fill",
            iconColor: PSColors.accentTeal,
            sections: [
                LegalSection(
                    heading: "Acceptance of Terms",
                    body: "By using Freshli, you agree to these Terms of Service. If you do not agree, please do not use the app. We may update these terms and will notify you of material changes."
                ),
                LegalSection(
                    heading: "Your Account",
                    body: "You are responsible for maintaining the security of your account credentials. You may not use Freshli for any illegal or unauthorized purpose. One account per person — multiple accounts are prohibited."
                ),
                LegalSection(
                    heading: "Community Sharing Rules",
                    body: "When sharing food with the community:\n• Only share food that is safe, properly stored, and accurately described\n• Do not share food you know to be expired, contaminated, or misrepresented\n• Be honest about allergen information\n• You are responsible for the safety of food you share\n\nFreshli is not liable for food shared between community members."
                ),
                LegalSection(
                    heading: "Prohibited Conduct",
                    body: "You agree not to:\n• Impersonate other users or create fake accounts\n• Post false or misleading food information\n• Attempt to reverse-engineer or hack the app\n• Use Freshli for commercial food selling (community sharing only)\n• Violate any applicable local food safety laws"
                ),
                LegalSection(
                    heading: "Intellectual Property",
                    body: "The Freshli app, its design, logo, and original content are owned by Freshli. You retain ownership of any content you create. By sharing content in the community, you grant Freshli a license to display it within the app."
                ),
                LegalSection(
                    heading: "Disclaimer of Warranties",
                    body: "Freshli is provided \"as is\" without warranty of any kind. We do not warrant that the app will be uninterrupted or error-free. Recipe and nutritional information is provided for general guidance only."
                ),
                LegalSection(
                    heading: "Limitation of Liability",
                    body: "To the maximum extent permitted by law, Freshli shall not be liable for any indirect, incidental, or consequential damages arising from your use of the app or community features."
                ),
                LegalSection(
                    heading: "Termination",
                    body: "We may suspend or terminate your account if you violate these terms. You may delete your account at any time from the Profile screen. Upon termination, your community listings will be removed."
                ),
                LegalSection(
                    heading: "Contact",
                    body: "Legal questions: legal@freshli.app\nWebsite: freshli.app/terms"
                ),
            ]
        )
    }
}

// MARK: - Open Source Licenses

struct FreshliOpenSourceView: View {
    private let licenses: [(name: String, license: String, url: String)] = [
        ("Supabase Swift", "Apache 2.0", "github.com/supabase/supabase-swift"),
        ("Swift Algorithms", "Apache 2.0", "github.com/apple/swift-algorithms"),
        ("swift-clocks", "MIT", "github.com/pointfreeco/swift-clocks"),
        ("swift-async-algorithms", "Apache 2.0", "github.com/apple/swift-async-algorithms"),
    ]

    var body: some View {
        List(licenses, id: \.name) { lib in
            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(lib.name)
                    .font(.system(size: PSLayout.scaledFont(15), weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(lib.license)
                    .font(.system(size: PSLayout.scaledFont(13)))
                    .foregroundStyle(PSColors.primaryGreen)
                Text(lib.url)
                    .font(.system(size: PSLayout.scaledFont(11)))
                    .foregroundStyle(PSColors.textTertiary)
            }
            .padding(.vertical, PSSpacing.xs)
        }
        .navigationTitle("Open Source")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable Legal Document Renderer

private struct LegalSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

private struct FreshliLegalDocumentView: View {
    let title: String
    let lastUpdated: String
    let icon: String
    let iconColor: Color
    let sections: [LegalSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PSSpacing.xxl) {
                // Document header
                HStack(spacing: PSSpacing.lg) {
                    ZStack {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                            .fill(iconColor.opacity(0.12))
                            .frame(width: PSLayout.scaled(52), height: PSLayout.scaled(52))
                        Image(systemName: icon)
                            .font(.system(size: PSLayout.scaledFont(24)))
                            .foregroundStyle(iconColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: PSLayout.scaledFont(20), weight: .bold))
                            .foregroundStyle(PSColors.textPrimary)
                        Text("Last updated: \(lastUpdated)")
                            .font(.system(size: PSLayout.scaledFont(12)))
                            .foregroundStyle(PSColors.textSecondary)
                    }
                }
                .padding(PSSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PSColors.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                        .strokeBorder(iconColor.opacity(0.15), lineWidth: 1)
                )

                // Sections
                VStack(alignment: .leading, spacing: PSSpacing.xl) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: PSSpacing.sm) {
                            Text(section.heading)
                                .font(.system(size: PSLayout.scaledFont(15), weight: .bold))
                                .foregroundStyle(PSColors.textPrimary)

                            Text(section.body)
                                .font(.system(size: PSLayout.scaledFont(14), weight: .regular))
                                .foregroundStyle(PSColors.textSecondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Footer
                Text("Questions? Contact us at support@freshli.app")
                    .font(.system(size: PSLayout.scaledFont(12)))
                    .foregroundStyle(PSColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, PSSpacing.lg)
            }
            .padding(.horizontal, PSLayout.adaptiveHorizontalPadding)
            .padding(.vertical, PSSpacing.lg)
            .padding(.bottom, PSSpacing.xxxl)
        }
        .background(PSColors.backgroundSecondary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
