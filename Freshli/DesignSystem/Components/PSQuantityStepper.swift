import SwiftUI

struct PSQuantityStepper: View {
    @Binding var value: Double
    var minimum: Double = 0
    var maximum: Double = 999
    var step: Double = 1
    var unit: String = ""

    var body: some View {
        HStack(spacing: PSSpacing.lg) {
            Button {
                let newValue = max(minimum, value - step)
                if newValue <= minimum {
                    PSHaptics.shared.heavyTap()  // Boundary thunk
                } else {
                    PSHaptics.shared.tick()
                }
                withAnimation(PSMotion.springBouncy) {
                    value = newValue
                }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(value <= minimum ? PSColors.textTertiary : PSColors.primaryGreen)
                    .frame(width: 36, height: 36)
                    .background(PSColors.backgroundSecondary)
                    .clipShape(Circle())
            }
            .disabled(value <= minimum)

            VStack(spacing: 0) {
                let formatted = value.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", value)
                    : String(format: "%.1f", value)
                Text(formatted)
                    .font(PSTypography.title3)
                    .monospacedDigit()
                    .foregroundStyle(PSColors.textPrimary)
                    .contentTransition(.numericText())
                    .compositingGroup()
                if !unit.isEmpty {
                    Text(unit)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
            .frame(minWidth: 50)

            Button {
                let newValue = min(maximum, value + step)
                if newValue >= maximum {
                    PSHaptics.shared.heavyTap()  // Boundary thunk
                } else {
                    PSHaptics.shared.tick()
                }
                withAnimation(PSMotion.springBouncy) {
                    value = newValue
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(value >= maximum ? PSColors.textTertiary : PSColors.primaryGreen)
                    .frame(width: 36, height: 36)
                    .background(PSColors.primaryGreen.opacity(0.12))
                    .clipShape(Circle())
            }
            .disabled(value >= maximum)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(String(format: "%.0f", value)) \(unit)")
        .accessibilityHint(String(localized: "Adjust quantity using swipe gestures"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                PSHaptics.shared.tick()
                withAnimation(PSMotion.springBouncy) {
                    value = min(maximum, value + step)
                }
            case .decrement:
                PSHaptics.shared.tick()
                withAnimation(PSMotion.springBouncy) {
                    value = max(minimum, value - step)
                }
            @unknown default: break
            }
        }
    }
}

#Preview {
    @Previewable @State var qty: Double = 3
    PSQuantityStepper(value: $qty, unit: "pcs")
        .padding()
}
