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
                PSHaptics.shared.tick()
                withAnimation(PSMotion.springBouncy) {
                    value = max(minimum, value - step)
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
                    .foregroundStyle(PSColors.textPrimary)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(PSTypography.caption1)
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
            .frame(minWidth: 50)

            Button {
                PSHaptics.shared.tick()
                withAnimation(PSMotion.springBouncy) {
                    value = min(maximum, value + step)
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
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(maximum, value + step)
            case .decrement: value = max(minimum, value - step)
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
