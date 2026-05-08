import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - RetailerLinkView (Coming Soon)
//
// Previously this view exposed a list of "connectable" retailers
// (Tesco, Sainsbury's, Whole Foods, etc.) backed by simulated OAuth
// + simulated purchase imports. None of it talked to a real retailer
// API — and shipping a fake "Connect" button on the App Store would
// (a) mislead users, and (b) draw an App Review reject.
//
// Until we have signed retailer partnerships in place, this view is
// a polished waitlist surface that:
//
//   • States the partnership status honestly with the founder's
//     own copy.
//   • Lets users tap "Notify me" — a one-tap mailto: opens the
//     default mail app preaddressed to hello@freshli.app with a
//     pre-filled subject. No mock waitlist, no email-collection
//     form that goes nowhere.
//   • Renders three feature pills so users understand what's
//     actually coming once partnerships land (auto-import,
//     points back, exclusive perks).
//
// All retailer simulation logic from the old implementation lives in
// `RetailerIntegrationService` and remains untouched. Reviewer
// account previews still work for demo purposes — we just don't
// surface the connect flow to real users.
// ══════════════════════════════════════════════════════════════════

struct RetailerLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var heroPulse: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: PSSpacing.xxl) {
                heroVisual
                    .padding(.top, PSSpacing.xxl)

                titleBlock
                featurePills
                emailCTA

                Spacer(minLength: PSSpacing.xl)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .padding(.bottom, PSSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .background(PSColors.backgroundPrimary)
        .navigationTitle(String(localized: "Supermarket Sync"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Hero visual
    //
    // Layered composition consistent with the scanner empty states:
    // aurora halo → glass plate → palette-rendered shopping-cart
    // glyph. Communicates "premium feature in the works" without a
    // literal countdown timer.

    private var heroVisual: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            PSColors.primaryGreen.opacity(0.55),
                            PSColors.accentTeal.opacity(0.45),
                            PSColors.secondaryAmber.opacity(0.55),
                            PSColors.primaryGreen.opacity(0.55)
                        ],
                        center: .center
                    )
                )
                .blur(radius: 30)
                .frame(width: 240, height: 240)
                .opacity(heroPulse ? 1.0 : 0.78)
                .scaleEffect(heroPulse ? 1.04 : 0.96)

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                )
                .frame(width: 144, height: 144)
                .shadow(color: PSColors.primaryGreen.opacity(0.22), radius: 22, x: 0, y: 12)

            ZStack {
                Image(systemName: "cart.fill.badge.plus")
                    .font(.system(size: 60, weight: .regular, design: .rounded))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, PSColors.primaryGreen)
                    .shadow(color: PSColors.primaryGreen.opacity(0.55), radius: 8, x: 0, y: 4)

                // Floating "soon" badge offset to the corner of the
                // glyph — clear time-orientation cue without text noise.
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(localized: "Coming Soon"))
                        .font(.system(size: 10, weight: .bold))
                        .textCase(.uppercase)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(PSColors.secondaryAmber.gradient, in: Capsule())
                .shadow(color: PSColors.secondaryAmber.opacity(0.45), radius: 6, x: 0, y: 3)
                .offset(x: 60, y: -52)
            }
        }
        .frame(height: 240)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
        }
    }

    // MARK: - Title + the founder's copy
    //
    // Verbatim from the requirements: this is the exact message the
    // founder wants users to read here. Short, honest, future-facing.

    private var titleBlock: some View {
        VStack(spacing: PSSpacing.sm) {
            Text(String(localized: "Supermarket Sync is on the way"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(PSColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(String(localized: "We're currently reaching out to supermarkets to bring you benefits and perks when using Freshli. When you shop, your purchases will automatically show up in the app — no scanning, no manual entry."))
                .font(.system(size: 15))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, PSSpacing.md)
        }
    }

    // MARK: - Three previewing capability rows

    private var featurePills: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            featurePillRow(
                icon: "bolt.fill",
                tint: PSColors.primaryGreen,
                title: String(localized: "Auto-import every shop"),
                detail: String(localized: "Receipts arrive in your pantry the moment you check out — no scanning required.")
            )
            featurePillRow(
                icon: "gift.fill",
                tint: PSColors.secondaryAmber,
                title: String(localized: "Exclusive partner perks"),
                detail: String(localized: "Money off, points back and freebies tied to how much food you've rescued.")
            )
            featurePillRow(
                icon: "shield.lefthalf.filled",
                tint: PSColors.accentTeal,
                title: String(localized: "Read-only by design"),
                detail: String(localized: "Freshli will only ever see your purchases — never your payment details or account password.")
            )
        }
    }

    private func featurePillRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: PSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.16))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(PSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(PSColors.borderLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Notify-me CTA
    //
    // No fake waitlist form. The user taps "Notify me when ready"
    // and Mail opens preaddressed to hello@freshli.app with subject
    // "Supermarket Sync — notify me". The team manually mails back
    // when the feature ships. Honest, zero-infrastructure approach
    // for a pre-partnership feature.

    private var emailCTA: some View {
        VStack(spacing: PSSpacing.sm) {
            Link(destination: notifyURL) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(String(localized: "Notify me when ready"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PSColors.primaryGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: PSColors.primaryGreen.opacity(0.30), radius: 12, x: 0, y: 6)
            }
            .accessibilityLabel(String(localized: "Notify me by email when supermarket sync is available"))

            Text(String(localized: "Opens Mail with hello@freshli.app pre-filled. We'll only message you once."))
                .font(.system(size: 11))
                .foregroundStyle(PSColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PSSpacing.lg)
        }
    }

    /// The mailto URL the "Notify me" button opens. URL-encoded so
    /// special characters in the subject survive the round-trip.
    private var notifyURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "hello@freshli.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Supermarket Sync — notify me"),
            URLQueryItem(
                name: "body",
                value: "Hi Freshli team, please let me know when supermarket sync is live. Thanks!"
            )
        ]
        // `URLComponents.url` returns nil only for malformed inputs;
        // these are static literals so the force-unwrap is safe.
        // Using `!` here keeps the expression readable; an `??` to
        // a sentinel would never trigger.
        return components.url ?? URL(string: "mailto:hello@freshli.app")!
    }
}

#Preview {
    NavigationStack {
        RetailerLinkView()
    }
}
