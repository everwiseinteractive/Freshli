import SwiftUI
import SwiftData

// MARK: - FreshliConfirmPredictionView

/// An inline card that appears on predicted-urgent items, offering
/// "Refill" or "Mark Consumed" actions that instantly update Supabase.
struct FreshliConfirmPredictionView: View {
    let prediction: FreshliPrediction
    let item: FreshliItem

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(SyncService.self) private var syncService
    @Environment(PSToastManager.self) private var toastManager

    @State private var predictionService: FreshliPredictionService?
    @State private var showRefillSheet = false
    @State private var refillQuantity: Double = 1.0
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: PSSpacing.sm) {
            // Prediction insight
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: predictionIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(predictionColor)
                    .frame(width: 28, height: 28)
                    .background(predictionColor.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: PSSpacing.xxxs) {
                    Text(predictionTitle)
                        .font(PSTypography.subheadlineMedium)
                        .foregroundStyle(PSColors.textPrimary)

                    if let patternText = usagePatternText {
                        Text(patternText)
                            .font(PSTypography.caption1)
                            .foregroundStyle(PSColors.textTertiary)
                    }
                }

                Spacer()

                if prediction.confidenceScore >= 0.5 {
                    PSBadge(
                        text: "\(Int(prediction.confidenceScore * 100))%",
                        style: .subtle
                    )
                }
            }

            // Action buttons
            HStack(spacing: PSSpacing.sm) {
                // Refill button
                Button {
                    PSHaptics.shared.lightTap()
                    showRefillSheet = true
                } label: {
                    HStack(spacing: PSSpacing.xs) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Refill")
                            .font(PSTypography.subheadlineMedium)
                    }
                    .foregroundStyle(PSColors.primaryGreen)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(PSColors.primaryGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                }
                .disabled(isProcessing)

                // Mark Consumed button
                Button {
                    Task { await confirmConsumed() }
                } label: {
                    HStack(spacing: PSSpacing.xs) {
                        if isProcessing {
                            ProgressView()
                                .tint(PSColors.textSecondary)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text("Consumed")
                            .font(PSTypography.subheadlineMedium)
                    }
                    .foregroundStyle(PSColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
                }
                .disabled(isProcessing)
            }
        }
        .padding(PSSpacing.md)
        .background(predictionColor.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd)
                .stroke(predictionColor.opacity(0.15), lineWidth: 0.5)
        )
        .sheet(isPresented: $showRefillSheet) {
            refillSheet
        }
    }

    // MARK: - Refill Sheet

    private var refillSheet: some View {
        NavigationStack {
            VStack(spacing: PSSpacing.xl) {
                VStack(spacing: PSSpacing.sm) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(PSColors.primaryGreen)

                    Text("Refill \(item.name)")
                        .font(PSTypography.title3)
                        .foregroundStyle(PSColors.textPrimary)

                    Text("Set the new quantity after restocking")
                        .font(PSTypography.callout)
                        .foregroundStyle(PSColors.textSecondary)
                }
                .padding(.top, PSSpacing.xl)

                // Quantity stepper
                VStack(spacing: PSSpacing.sm) {
                    Text("\(formatQuantity(refillQuantity)) \(item.unit.displayName)")
                        .font(PSTypography.statMedium)
                        .foregroundStyle(PSColors.textPrimary)

                    HStack(spacing: PSSpacing.lg) {
                        PSIconButton(icon: "minus", size: 44, tint: PSColors.textSecondary, background: PSColors.backgroundSecondary) {
                            PSHaptics.shared.lightTap()
                            refillQuantity = max(0.5, refillQuantity - stepSize)
                        }

                        Slider(value: $refillQuantity, in: 0.5...maxQuantity, step: stepSize)
                            .tint(PSColors.primaryGreen)

                        PSIconButton(icon: "plus", size: 44, tint: PSColors.primaryGreen, background: PSColors.primaryGreen.opacity(0.12)) {
                            PSHaptics.shared.lightTap()
                            refillQuantity = min(maxQuantity, refillQuantity + stepSize)
                        }
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)

                Spacer()

                PSButton(title: "Confirm Refill", icon: "arrow.counterclockwise", style: .primary, size: .large) {
                    Task { await confirmRefill() }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.bottom, PSSpacing.xl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) {
                        showRefillSheet = false
                    }
                    .foregroundStyle(PSColors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            refillQuantity = item.quantity > 0 ? item.quantity : 1.0
        }
    }

    // MARK: - Actions

    private func confirmConsumed() async {
        isProcessing = true
        defer { isProcessing = false }

        PSHaptics.shared.mediumTap()

        let itemName = item.name
        let itemId = item.id

        // Record consumption and mark consumed locally
        if let service = predictionService {
            await service.confirmConsumed(item: item, modelContext: modelContext)
        } else {
            item.isConsumed = true
            do {
                try modelContext.save()
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
                return
            }
        }

        toastManager.show(.itemConsumed(itemName))

        // Push to Supabase
        if let userId = authManager.currentUserId {
            await syncService.pushFreshliItem(item, userId: userId)
            await syncService.recordImpactEvent(
                userId: userId,
                eventType: "consumed",
                itemName: itemName,
                moneySaved: 3.50,
                co2Avoided: 2.5
            )
        }
    }

    private func confirmRefill() async {
        isProcessing = true
        defer {
            isProcessing = false
            showRefillSheet = false
        }

        PSHaptics.shared.mediumTap()

        let itemName = item.name

        if let service = predictionService {
            await service.confirmRefill(item: item, newQuantity: refillQuantity, modelContext: modelContext)
        } else {
            item.quantity = refillQuantity
            item.dateAdded = Date()
            do {
                try modelContext.save()
            } catch {
                toastManager.show(.error("Something went wrong. Please try again."))
                PSHaptics.shared.warning()
                return
            }
        }

        toastManager.show(.success("\(itemName) refilled"))

        // Push update to Supabase
        if let userId = authManager.currentUserId {
            await syncService.pushFreshliItem(item, userId: userId)
        }
    }

    // MARK: - Computed Properties

    private var predictionIcon: String {
        switch prediction.reason {
        case .expiryBeforeDepletion: return "clock.badge.exclamationmark"
        case .depletionBeforeExpiry: return "chart.line.downtrend.xyaxis"
        case .bothSameDay: return "exclamationmark.triangle"
        case .noHistory: return "sparkles"
        }
    }

    private var predictionColor: Color {
        if prediction.isUrgent {
            return PSColors.expiredRed
        } else if prediction.isRunningLow {
            return PSColors.warningAmber
        } else {
            return PSColors.infoBlue
        }
    }

    private var predictionTitle: String {
        let days = prediction.estimatedDaysRemaining
        switch prediction.reason {
        case .expiryBeforeDepletion:
            if days <= 0 { return String(localized: "Predicted expired") }
            return String(localized: "Expires in ~\(days) day\(days == 1 ? "" : "s")")
        case .depletionBeforeExpiry:
            if days <= 0 { return String(localized: "Predicted empty") }
            return String(localized: "~\(days) day\(days == 1 ? "" : "s") of supply left")
        case .bothSameDay:
            return String(localized: "Runs out & expires soon")
        case .noHistory:
            return String(localized: "Low confidence estimate")
        }
    }

    private var usagePatternText: String? {
        guard prediction.sampleCount > 0 else { return nil }
        let rate = prediction.sampleCount
        return String(localized: "Based on \(rate) past usage\(rate == 1 ? "" : "s")")
    }

    private var stepSize: Double {
        switch item.unit {
        case .grams, .milliliters: return 50
        case .kilograms, .liters: return 0.25
        case .ounces: return 1
        case .pounds: return 0.25
        default: return 1
        }
    }

    private var maxQuantity: Double {
        switch item.unit {
        case .grams: return 5000
        case .milliliters: return 5000
        case .kilograms: return 25
        case .liters: return 10
        case .ounces: return 64
        case .pounds: return 25
        default: return 50
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Inline Confirm Button (compact variant for list rows)

/// A compact "Confirm Prediction" pill button for embedding in item rows.
struct FreshliConfirmPredictionButton: View {
    let prediction: FreshliPrediction
    var onTap: () -> Void

    var body: some View {
        Button {
            PSHaptics.shared.lightTap()
            onTap()
        } label: {
            HStack(spacing: PSSpacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                Text("Confirm")
                    .font(PSTypography.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(buttonColor)
            .padding(.horizontal, PSSpacing.sm)
            .padding(.vertical, PSSpacing.xxs)
            .background(buttonColor.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var buttonColor: Color {
        if prediction.isUrgent { return PSColors.expiredRed }
        if prediction.isRunningLow { return PSColors.warningAmber }
        return PSColors.primaryGreen
    }
}
