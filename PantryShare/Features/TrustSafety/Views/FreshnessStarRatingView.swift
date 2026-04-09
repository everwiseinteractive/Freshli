import SwiftUI

/// High-gloss "Freshness Star" rating view for reviewing successful pickups.
/// Glassmorphism styled with animated star selection.
struct FreshnessStarRatingView: View {
    @Binding var rating: Int
    let maxRating: Int = 5
    var isInteractive: Bool = true
    var size: CGFloat = 28

    @State private var hoverRating: Int = 0

    var body: some View {
        HStack(spacing: PSSpacing.xs) {
            ForEach(1...maxRating, id: \.self) { star in
                starImage(for: star)
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(starColor(for: star))
                    .symbolEffect(.bounce, value: rating == star)
                    .scaleEffect(effectiveRating >= star ? 1.0 : 0.85)
                    .animation(PSMotion.springBouncy, value: effectiveRating)
                    .onTapGesture {
                        guard isInteractive else { return }
                        PSHaptics.shared.lightTap()
                        withAnimation(PSMotion.springBouncy) {
                            rating = star
                        }
                    }
                    .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(rating) of \(maxRating) stars")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                if rating < maxRating { rating += 1 }
            case .decrement:
                if rating > 1 { rating -= 1 }
            @unknown default:
                break
            }
        }
    }

    private var effectiveRating: Int {
        hoverRating > 0 ? hoverRating : rating
    }

    private func starImage(for star: Int) -> Image {
        if effectiveRating >= star {
            Image(systemName: "leaf.fill")
        } else {
            Image(systemName: "leaf")
        }
    }

    private func starColor(for star: Int) -> Color {
        guard effectiveRating >= star else {
            return PSColors.textTertiary.opacity(0.5)
        }
        // Gradient from amber (1 star) to green (5 stars)
        let ratio = Double(effectiveRating) / Double(maxRating)
        if ratio <= 0.4 {
            return PSColors.warningAmber
        } else if ratio <= 0.6 {
            return Color(hex: 0x84CC16) // lime
        } else {
            return PSColors.primaryGreen
        }
    }
}

// MARK: - Display-Only Rating

struct FreshnessStarDisplay: View {
    let rating: Double
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starName(for: star))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(starDisplayColor)
            }
        }
    }

    private func starName(for star: Int) -> String {
        if rating >= Double(star) {
            "leaf.fill"
        } else if rating >= Double(star) - 0.5 {
            "leaf.fill" // SwiftUI doesn't have half-leaf, use fill
        } else {
            "leaf"
        }
    }

    private var starDisplayColor: Color {
        if rating <= 2.0 {
            PSColors.warningAmber
        } else if rating <= 3.5 {
            Color(hex: 0x84CC16)
        } else {
            PSColors.primaryGreen
        }
    }
}

// MARK: - Review Card (Glassmorphism)

struct FreshnessReviewCard: View {
    let review: FreshnessReview
    let reviewerName: String

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: PSSpacing.md) {
            // Header
            HStack(spacing: PSSpacing.sm) {
                // Avatar placeholder
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(reviewerName.prefix(1)).uppercased())
                            .font(PSTypography.calloutMedium)
                            .foregroundStyle(PSColors.primaryGreen)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(reviewerName)
                        .font(PSTypography.calloutMedium)
                        .foregroundStyle(PSColors.textPrimary)

                    Text(review.createdAt, style: .relative)
                        .font(PSTypography.caption2)
                        .foregroundStyle(PSColors.textTertiary)
                }

                Spacer()

                FreshnessStarDisplay(rating: Double(review.clampedRating), size: 14)
            }

            // Comment
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(PSTypography.body)
                    .foregroundStyle(PSColors.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(PSSpacing.cardPadding)
        .glassCardStyle()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(PSMotion.springDefault.delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Review Summary Card

struct FreshnessReviewSummaryCard: View {
    let summary: ReviewSummary

    var body: some View {
        PSGlassCard {
            VStack(spacing: PSSpacing.lg) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                        Text("Freshness Rating")
                            .font(PSTypography.footnoteMedium)
                            .foregroundStyle(PSColors.textSecondary)

                        HStack(alignment: .firstTextBaseline, spacing: PSSpacing.xs) {
                            Text(String(format: "%.1f", summary.averageRating))
                                .font(PSTypography.statLarge)
                                .foregroundStyle(PSColors.textPrimary)

                            Text("/ 5")
                                .font(PSTypography.callout)
                                .foregroundStyle(PSColors.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: PSSpacing.xxs) {
                        FreshnessStarDisplay(rating: summary.averageRating, size: 18)

                        Text("\(summary.totalReviews) review\(summary.totalReviews == 1 ? "" : "s")")
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }

                // Distribution bars
                if !summary.ratingDistribution.isEmpty {
                    VStack(spacing: PSSpacing.xs) {
                        ForEach((1...5).reversed(), id: \.self) { star in
                            ratingBar(star: star, count: summary.ratingDistribution[star] ?? 0)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func ratingBar(star: Int, count: Int) -> some View {
        let fraction: Double = summary.totalReviews > 0
            ? Double(count) / Double(summary.totalReviews)
            : 0

        HStack(spacing: PSSpacing.sm) {
            Text("\(star)")
                .font(PSTypography.caption1Medium)
                .foregroundStyle(PSColors.textSecondary)
                .frame(width: 12, alignment: .trailing)

            Image(systemName: "leaf.fill")
                .font(.system(size: 10))
                .foregroundStyle(PSColors.primaryGreen.opacity(0.6))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(PSColors.backgroundTertiary)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(PSColors.primaryGreen)
                        .frame(width: proxy.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)

            Text("\(count)")
                .font(PSTypography.caption2)
                .foregroundStyle(PSColors.textTertiary)
                .frame(width: 24, alignment: .trailing)
        }
    }
}

// MARK: - Submit Review Sheet

struct SubmitFreshnessReviewView: View {
    let listingId: UUID
    let revieweeId: UUID
    let revieweeName: String
    let onComplete: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var safetyService = SafetyService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    // Hero
                    VStack(spacing: PSSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(PSColors.primaryGreen.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: "leaf.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(PSColors.primaryGreen)
                                .symbolEffect(.pulse, isActive: isSubmitting)
                        }

                        VStack(spacing: PSSpacing.xs) {
                            Text("Rate Your Pickup")
                                .font(PSTypography.title2)
                                .foregroundStyle(PSColors.textPrimary)

                            Text("How was your experience with \(revieweeName)?")
                                .font(PSTypography.body)
                                .foregroundStyle(PSColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, PSSpacing.xxl)

                    // Rating
                    VStack(spacing: PSSpacing.md) {
                        FreshnessStarRatingView(rating: $rating, size: 36)

                        if rating > 0 {
                            Text(ratingLabel)
                                .font(PSTypography.calloutMedium)
                                .foregroundStyle(PSColors.primaryGreen)
                                .transition(PSMotion.fadeSlide)
                        }
                    }

                    // Comment
                    VStack(alignment: .leading, spacing: PSSpacing.sm) {
                        Text("Comments (optional)")
                            .font(PSTypography.footnoteMedium)
                            .foregroundStyle(PSColors.textSecondary)

                        TextField(String(localized: "Share details about the pickup..."), text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                            .font(PSTypography.body)
                            .padding(PSSpacing.md)
                            .background(PSColors.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    }
                    .padding(.horizontal, PSSpacing.screenHorizontal)

                    Spacer(minLength: PSSpacing.xxxl)

                    // Submit
                    PSButton(
                        title: String(localized: "Submit Review"),
                        icon: "leaf.fill",
                        isLoading: isSubmitting
                    ) {
                        submitReview()
                    }
                    .disabled(rating == 0)
                    .opacity(rating == 0 ? 0.5 : 1)
                    .padding(.horizontal, PSSpacing.screenHorizontal)
                    .padding(.bottom, PSSpacing.xxxl)
                }
            }
            .background(PSColors.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: String(localized: "Poor")
        case 2: String(localized: "Below Average")
        case 3: String(localized: "Good")
        case 4: String(localized: "Great")
        case 5: String(localized: "Excellent!")
        default: ""
        }
    }

    private func submitReview() {
        guard rating > 0, !isSubmitting else { return }
        isSubmitting = true
        PSHaptics.shared.mediumTap()

        Task {
            // Reviewer ID would come from AuthManager in real usage
            let input = CreateReviewInput(
                reviewerId: UUID(), // Placeholder — inject from auth
                revieweeId: revieweeId,
                listingId: listingId,
                freshnessRating: rating,
                comment: comment.isEmpty ? nil : comment
            )

            let success = await safetyService.submitReview(input)
            isSubmitting = false

            if success {
                PSHaptics.shared.success()
                onComplete(true)
                dismiss()
            } else {
                PSHaptics.shared.error()
                onComplete(false)
            }
        }
    }
}

#Preview("Rating Interactive") {
    struct PreviewWrapper: View {
        @State var rating = 3
        var body: some View {
            VStack(spacing: 30) {
                FreshnessStarRatingView(rating: $rating, size: 36)
                FreshnessStarDisplay(rating: 4.3)

                FreshnessReviewSummaryCard(summary: ReviewSummary(
                    averageRating: 4.3,
                    totalReviews: 47,
                    ratingDistribution: [1: 2, 2: 3, 3: 5, 4: 15, 5: 22]
                ))
            }
            .padding()
        }
    }
    return PreviewWrapper()
}
