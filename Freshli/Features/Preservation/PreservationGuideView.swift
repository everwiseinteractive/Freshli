import SwiftUI

// MARK: - Preservation Guide View
// Step-by-step guide for freezing, pickling, dehydrating, and more.
// Presented as a sheet from FreshliDetailView.

struct PreservationGuideView: View {
    let item: FreshliItem

    @State private var selectedMethod: PreservationMethod?
    @State private var methods: [PreservationMethod] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    itemHeader
                    if methods.isEmpty {
                        noGuideState
                    } else {
                        methodsGrid
                        if let method = selectedMethod {
                            selectedMethodDetail(method)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Save it for Later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                        .foregroundStyle(PSColors.primaryGreen)
                }
            }
            .task {
                methods = PreservationGuideService.shared.methods(for: item)
                selectedMethod = methods.first
            }
        }
    }

    // MARK: - Item Header

    private var itemHeader: some View {
        HStack(spacing: PSSpacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(PSColors.accentTeal.opacity(0.12))
                    .frame(width: PSLayout.scaled(60), height: PSLayout.scaled(60))
                Image(systemName: "snowflake")
                    .font(.system(size: PSLayout.scaledFont(28)))
                    .foregroundStyle(PSColors.accentTeal)
            }
            VStack(alignment: .leading, spacing: PSSpacing.xxs) {
                Text(item.name)
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Preservation options to extend shelf life")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                if item.expiryStatus != .fresh {
                    HStack(spacing: PSSpacing.xxs) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: PSLayout.scaledFont(10)))
                        Text("Expires soon — act now!")
                            .font(.system(size: PSLayout.scaledFont(11), weight: .semibold))
                    }
                    .foregroundStyle(PSColors.expiredRed)
                }
            }
            Spacer()
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }

    // MARK: - Methods Grid

    private var methodsGrid: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("Choose a Method")
                .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                .foregroundStyle(PSColors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PSSpacing.md) {
                ForEach(methods) { method in
                    methodTile(method, isSelected: selectedMethod?.id == method.id)
                }
            }
        }
    }

    private func methodTile(_ method: PreservationMethod, isSelected: Bool) -> some View {
        Button {
            PSHaptics.shared.lightTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMethod = method
            }
        } label: {
            VStack(spacing: PSSpacing.sm) {
                Image(systemName: method.type.icon)
                    .font(.system(size: PSLayout.scaledFont(24)))
                    .foregroundStyle(isSelected ? .white : method.type.color)
                Text(method.type.rawValue)
                    .font(.system(size: PSLayout.scaledFont(13), weight: .bold))
                    .foregroundStyle(isSelected ? .white : PSColors.textPrimary)
                Text(method.storageLife)
                    .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 2) {
                    ForEach(0..<3) { star in
                        Image(systemName: star < method.difficulty ? "star.fill" : "star")
                            .font(.system(size: PSLayout.scaledFont(9)))
                            .foregroundStyle(isSelected ? .white.opacity(0.7) : (star < method.difficulty ? PSColors.secondaryAmber : PSColors.borderLight))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(PSSpacing.lg)
            .background(isSelected ? method.type.color : PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : method.type.color.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: isSelected ? method.type.color.opacity(0.3) : .black.opacity(0.04), radius: isSelected ? 12 : 4, y: isSelected ? 6 : 2)
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Selected Method Detail

    private func selectedMethodDetail(_ method: PreservationMethod) -> some View {
        VStack(alignment: .leading, spacing: PSSpacing.lg) {
            // Header
            HStack(spacing: PSSpacing.md) {
                Image(systemName: method.type.icon)
                    .font(.system(size: PSLayout.scaledFont(20)))
                    .foregroundStyle(method.type.color)
                    .padding(PSSpacing.sm)
                    .background(method.type.color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("How to \(method.type.rawValue)")
                        .font(.system(size: PSLayout.scaledFont(17), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("Lasts: \(method.storageLife)")
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
            }

            // Steps
            VStack(alignment: .leading, spacing: PSSpacing.sm) {
                ForEach(Array(method.steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: PSSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(method.type.color.opacity(0.15))
                                .frame(width: PSLayout.scaled(28), height: PSLayout.scaled(28))
                            Text("\(idx + 1)")
                                .font(.system(size: PSLayout.scaledFont(12), weight: .black))
                                .foregroundStyle(method.type.color)
                        }
                        Text(step)
                            .font(.system(size: PSLayout.scaledFont(14), weight: .medium))
                            .foregroundStyle(PSColors.textPrimary)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            // Pro tip
            HStack(alignment: .top, spacing: PSSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: PSLayout.scaledFont(14)))
                    .foregroundStyle(PSColors.secondaryAmber)
                Text(method.tip)
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .lineSpacing(2)
            }
            .padding(PSSpacing.md)
            .background(PSColors.secondaryAmber.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        }
        .padding(PSSpacing.lg)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .strokeBorder(method.type.color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - No Guide State

    private var noGuideState: some View {
        VStack(spacing: PSSpacing.md) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: PSLayout.scaledFont(40)))
                .foregroundStyle(PSColors.textTertiary)
            Text("No specific guide yet")
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                .foregroundStyle(PSColors.textPrimary)
            Text("When in doubt, freeze it! Most foods last 1–3 months when sealed properly and frozen.")
                .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                .foregroundStyle(PSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(PSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(PSColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
    }
}
