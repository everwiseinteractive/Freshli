import SwiftUI
import SwiftData

struct DepletionInsightsView: View {
    @Query(filter: #Predicate<PantryItem> { !$0.isConsumed && !$0.isShared && !$0.isDonated })
    private var allItems: [PantryItem]

    @Environment(\.modelContext) private var modelContext
    @State private var depletionService = DepletionService()
    @State private var predictions: [DepletionPrediction] = []
    @State private var showingFeedbackItem: PantryItem? = nil
    @State private var feedbackItem: PantryItem? = nil

    private var likelyEmptyItems: [DepletionPrediction] {
        predictions.filter { $0.suggestion == .likelyEmpty }
    }

    private var runningLowItems: [DepletionPrediction] {
        predictions.filter { $0.suggestion == .runningLow }
    }

    private var plentifulItems: [DepletionPrediction] {
        predictions.filter { $0.suggestion == .plentiful }
    }

    private var hasAnyPredictions: Bool {
        !predictions.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasAnyPredictions {
                summaryCard
                    .padding(PSSpacing.md)
                    .transition(PSMotion.slideUp)

                ScrollView {
                    VStack(spacing: PSSpacing.lg) {
                        if !likelyEmptyItems.isEmpty {
                            sectionView(
                                title: "Likely Empty",
                                emoji: "🔴",
                                items: likelyEmptyItems,
                                color: PSColors.expiredRed
                            )
                        }

                        if !runningLowItems.isEmpty {
                            sectionView(
                                title: "Running Low",
                                emoji: "🟡",
                                items: runningLowItems,
                                color: PSColors.warningAmber
                            )
                        }

                        if !plentifulItems.isEmpty {
                            sectionView(
                                title: "Plentiful",
                                emoji: "🟢",
                                items: plentifulItems,
                                color: PSColors.freshGreen
                            )
                        }
                    }
                    .padding(PSSpacing.md)
                }
            } else {
                emptyState
            }
        }
        .background(PSColors.backgroundPrimary)
        .onAppear {
            refreshPredictions()
        }
        .onChange(of: allItems.count) { _, _ in
            refreshPredictions()
        }
        .sheet(item: $showingFeedbackItem) { item in
            feedbackSheetContent(for: item)
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let emptyCount = likelyEmptyItems.count + runningLowItems.count

        return VStack(spacing: PSSpacing.sm) {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PSColors.expiredRed)

                Text("\(emptyCount) item\(emptyCount == 1 ? "" : "s") may need attention")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)

                Spacer()
            }
            .padding(PSSpacing.md)
            .background(PSColors.expiredRed.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                    .strokeBorder(PSColors.expiredRed.opacity(0.2), lineWidth: 1)
            )
        }
        .modifier(PulseAnimationModifier())
    }

    // MARK: - Section View

    private func sectionView(
        title: String,
        emoji: String,
        items: [DepletionPrediction],
        color: Color
    ) -> some View {
        VStack(spacing: PSSpacing.md) {
            HStack(spacing: PSSpacing.sm) {
                Text(emoji)
                    .font(.system(size: 20))

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PSColors.textPrimary)

                Text("\(items.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)

                Spacer()
            }

            VStack(spacing: PSSpacing.sm) {
                ForEach(items) { prediction in
                    predictionRow(prediction, accentColor: color)
                }
            }
        }
        .padding(PSSpacing.md)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                .strokeBorder(PSColors.border, lineWidth: 1)
        )
    }

    // MARK: - Prediction Row

    private func predictionRow(_ prediction: DepletionPrediction, accentColor: Color) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: PSSpacing.sm) {
                // Category emoji
                if let item = allItems.first(where: { $0.id == prediction.itemId }) {
                    Text(item.category.emoji)
                        .font(.system(size: 18))
                        .frame(width: 32, alignment: .center)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(prediction.itemName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PSColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: PSSpacing.xs) {
                        timeLabel(for: prediction)
                            .font(.system(size: 13))
                            .foregroundStyle(PSColors.textSecondary)

                        confidenceIndicator(prediction.confidenceScore)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    moreButton(for: prediction)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingFeedbackItem = allItems.first(where: { $0.id == prediction.itemId })
            }

            Divider()
                .padding(.vertical, PSSpacing.sm)
                .padding(.leading, 44)
        }
        .padding(PSSpacing.sm)
    }

    // MARK: - Time Label

    private func timeLabel(for prediction: DepletionPrediction) -> some View {
        switch prediction.suggestion {
        case .likelyEmpty:
            return Text("Likely empty")
        case .runningLow:
            return Text("~\(prediction.estimatedDaysRemaining) day\(prediction.estimatedDaysRemaining == 1 ? "" : "s") left")
        case .plentiful:
            return Text("~\(prediction.estimatedDaysRemaining) day\(prediction.estimatedDaysRemaining == 1 ? "" : "s") left")
        case .unknown:
            return Text("No data")
        }
    }

    // MARK: - Confidence Indicator

    private func confidenceIndicator(_ score: Double) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Double(index) / 3.0 < score ? PSColors.warningAmber : PSColors.border.opacity(0.3))
                    .frame(width: 3, height: 6)
            }
        }
    }

    // MARK: - More Button

    private func moreButton(for prediction: DepletionPrediction) -> some View {
        Button(action: {
            showingFeedbackItem = allItems.first(where: { $0.id == prediction.itemId })
        }) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PSColors.textSecondary)
                .frame(width: 32, height: 32)
        }
    }

    // MARK: - Feedback Sheet

    private func feedbackSheetContent(for item: PantryItem) -> some View {
        VStack(spacing: PSSpacing.lg) {
            VStack(spacing: PSSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: PSSpacing.xs) {
                        HStack(spacing: PSSpacing.xs) {
                            Text(item.category.emoji)
                                .font(.system(size: 24))

                            Text(item.name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PSColors.textPrimary)
                        }

                        Text(item.category.displayName)
                            .font(.system(size: 14))
                            .foregroundStyle(PSColors.textSecondary)
                    }

                    Spacer()

                    Button(action: { showingFeedbackItem = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }
                .padding(PSSpacing.md)
            }

            Divider()

            VStack(spacing: PSSpacing.md) {
                Text("Help improve predictions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PSColors.textSecondary)

                PSButton(
                    title: "Mark as Consumed",
                    icon: "checkmark.circle.fill",
                    style: .primary,
                    size: .medium,
                    isFullWidth: true,
                    action: {
                        markAsConsumed(item)
                        showingFeedbackItem = nil
                    }
                )

                PSButton(
                    title: "Still Have It",
                    icon: "hand.thumbsup.fill",
                    style: .secondary,
                    size: .medium,
                    isFullWidth: true,
                    action: {
                        markAsStillHave(item)
                        showingFeedbackItem = nil
                    }
                )

                Button(action: { showingFeedbackItem = nil }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .padding(PSSpacing.md)

            Spacer()
        }
        .background(PSColors.backgroundPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: PSSpacing.lg) {
            Spacer()

            PSEmptyState(
                icon: "chart.line.uptrend.xyaxis",
                title: "No Data Yet",
                message: "Start recording consumed items to get personalized depletion predictions.",
                actionTitle: nil,
                action: nil
            )

            Spacer()
        }
        .padding(PSSpacing.md)
    }

    // MARK: - Actions

    private func markAsConsumed(_ item: PantryItem) {
        depletionService.recordConsumption(item: item, modelContext: modelContext)

        withAnimation(PSMotion.springDefault) {
            item.isConsumed = true
        }

        do {
            try modelContext.save()
            refreshPredictions()
        } catch {
            PSLogger.pantry.error("Failed to mark item as consumed: \(error.localizedDescription)")
        }
    }

    private func markAsStillHave(_ item: PantryItem) {
        // Create a consumption record with extended daysInPantry to adjust model upward
        let extendedDays = Calendar.current.dateComponents([.day], from: item.dateAdded, to: Date()).day ?? 0
        let record = ConsumptionRecord(
            itemName: item.name,
            category: item.categoryRaw,
            quantity: item.quantity,
            unit: item.unitRaw,
            consumedDate: Date().addingTimeInterval(86400 * 365),  // Far future
            daysInPantry: max(extendedDays + 30, 30),  // Add 30 days buffer
            householdSize: 2
        )

        modelContext.insert(record)

        do {
            try modelContext.save()
            refreshPredictions()
        } catch {
            PSLogger.pantry.error("Failed to update item feedback: \(error.localizedDescription)")
        }
    }

    private func refreshPredictions() {
        predictions = depletionService.predictionsForAllItems(items: allItems, modelContext: modelContext)
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimationModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1 : 0.8)
            .animation(
                Animation.easeInOut(duration: 2)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Preview

#Preview {
    DepletionInsightsView()
        .modelContainer(for: [PantryItem.self, ConsumptionRecord.self], inMemory: true)
}
