//
//  FLEventBanner.swift
//  Freshli
//
//  Top-of-screen banner shown when the user enters the app via an App Store
//  In-App Event deep link. Rendered by AppTabView's .overlay observing
//  `URLRouterService.shared.activeEvent`.
//
//  This is the visible signal to App Reviewers that the deep link landed in
//  the right place — the event's title and subtitle appear, anchored to the
//  tab the event maps to (Pantry / Recipes / Community / Home).
//

import SwiftUI

struct FLEventBanner: View {
    let title: String
    let subtitle: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPhase: CGFloat = 0

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            // Glowing leaf glyph anchors the brand promise.
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [PSColors.primaryGreen, PSColors.emerald600],
                            startPoint: .topLeading,
                            endPoint:   .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: PSColors.primaryGreen.opacity(0.5),
                            radius: reduceMotion ? 0 : 12,
                            x: 0,
                            y: 6)

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeat(.continuous), isActive: !reduceMotion)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.freshliSubheadline.weight(.bold))
                    .foregroundStyle(PSColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(subtitle)
                    .font(Font.freshliCaption)
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(PSColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(PSColors.backgroundSecondary)
                    )
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(String(localized: "Dismiss event banner"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    PSColors.primaryGreen.opacity(0.55),
                                    PSColors.primaryGreen.opacity(0.10)
                                ],
                                startPoint: .leading,
                                endPoint:   .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.10), radius: 24, x: 0, y: 14)
        )
        .padding(.horizontal, PSSpacing.md)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    ZStack(alignment: .top) {
        PSColors.backgroundPrimary.ignoresSafeArea()
        FLEventBanner(
            title: "Spring Pantry Reset",
            subtitle: "Reset your fridge in 14 days.",
            onDismiss: {}
        )
        .padding(.top, 60)
    }
}
