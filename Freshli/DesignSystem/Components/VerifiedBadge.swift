import SwiftUI

// ══════════════════════════════════════════════════════════════════
// MARK: - VerifiedBadge
//
// Single source of truth for the "officially verified" badge that
// sits next to a display name throughout the app. Used wherever a
// user identity is rendered:
//
//   • Community feed listing cards
//   • Listing detail view
//   • My Listings cards
//   • Profile header
//   • Comments / claim chips
//   • Family-sharing roster
//
// Visual design: a filled `checkmark.seal.fill` SF Symbol in
// `PSColors.primaryGreen` (matches Freshli's brand and stays
// readable in light + dark + Increase Contrast). Sized via
// `relativeTo:` so it scales with the adjacent text under
// Dynamic Type.
//
// Accessibility: `accessibilityLabel("Verified")` so VoiceOver
// announces the badge in context — "Sarah J. Verified."
//
// Privacy / abuse-resistance: callers only ever pass the
// authoritative `isVerified` boolean from `profiles.is_verified`.
// There is NO client-side path for a user to claim verification —
// the column is admin-set in the database.
// ══════════════════════════════════════════════════════════════════

struct VerifiedBadge: View {
    /// Whether to actually render. Convenience so callers can write
    /// `VerifiedBadge(isVerified: profile.isVerified ?? false)` once
    /// and have it disappear for unverified users.
    let isVerified: Bool

    /// Font shape we're sizing against — pass the same `Font` you
    /// gave the adjacent display-name `Text` so the badge tracks
    /// Dynamic Type. Defaults to `.callout`.
    var relativeTo: Font.TextStyle = .callout

    /// Visual weight. `.strong` (default) for prominent name rows,
    /// `.subtle` for compact lists where the badge shouldn't dominate.
    var emphasis: Emphasis = .strong

    enum Emphasis {
        case strong   // primary green, fully opaque
        case subtle   // primary green at 0.85 opacity, slightly smaller
    }

    var body: some View {
        if isVerified {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(emphasis == .strong ? relativeTo : smallerStyle, design: .rounded))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, PSColors.primaryGreen)
                .opacity(emphasis == .strong ? 1.0 : 0.85)
                .accessibilityLabel(String(localized: "Verified"))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    /// Pick the next text style down so the subtle variant doesn't
    /// crowd the layout. SF Symbols look natural at one notch smaller
    /// than the surrounding text.
    private var smallerStyle: Font.TextStyle {
        switch relativeTo {
        case .largeTitle: return .title
        case .title:      return .title2
        case .title2:     return .title3
        case .title3:     return .headline
        case .headline:   return .subheadline
        case .subheadline: return .footnote
        case .body:       return .callout
        case .callout:    return .footnote
        case .footnote:   return .caption
        case .caption:    return .caption2
        case .caption2:   return .caption2
        @unknown default: return .footnote
        }
    }
}

// MARK: - Inline-with-name helper
//
// A convenience that lays out a display name + the badge in a
// single HStack with the right spacing and `lineLimit(1)` so a
// long name truncates before the badge. Use this anywhere you'd
// otherwise write `Text(name)` and want verification to follow.

struct VerifiedNameLabel: View {
    let name: String
    let isVerified: Bool
    var font: Font = .system(.callout, weight: .semibold)
    var relativeTo: Font.TextStyle = .callout

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(font)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isStaticText)
            VerifiedBadge(isVerified: isVerified, relativeTo: relativeTo)
        }
        // VoiceOver: combine name + verified into one announcement
        // so users hear "Sarah Johnson, verified" instead of the two
        // labels in sequence.
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Strong + subtle") {
    VStack(alignment: .leading, spacing: 16) {
        VerifiedNameLabel(
            name: "Alderframe Studio",
            isVerified: true,
            font: .system(.title3, weight: .bold),
            relativeTo: .title3
        )
        VerifiedNameLabel(
            name: "Sarah Johnson",
            isVerified: true,
            font: .system(.body, weight: .semibold)
        )
        VerifiedNameLabel(
            name: "Marcus Tan",
            isVerified: false,
            font: .system(.body, weight: .semibold)
        )
        HStack {
            Text("Subtle:")
            VerifiedBadge(isVerified: true, relativeTo: .footnote, emphasis: .subtle)
        }
    }
    .padding()
}
