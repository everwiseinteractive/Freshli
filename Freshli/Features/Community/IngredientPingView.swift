import SwiftUI

// MARK: - Ingredient Ping View
// Quickly request a single ingredient from your local pod.
// Faster than a shop run, uses Karma Credits as currency.

struct IngredientPingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var karmaService = KarmaCreditService.shared
    @State private var podService = CommunityPodsService.shared
    @State private var ingredientName: String = ""
    @State private var quantity: String = "1"
    @State private var selectedUrgency: Urgency = .today
    @State private var note: String = ""
    @State private var selectedPodId: UUID?
    @State private var showSuccessToast = false

    enum Urgency: String, CaseIterable {
        case now     = "Right now"
        case today   = "Today"
        case thisWeek = "This week"

        var icon: String {
            switch self {
            case .now:     return "bolt.fill"
            case .today:   return "sun.max.fill"
            case .thisWeek: return "calendar"
            }
        }
        var color: Color {
            switch self {
            case .now:     return Color(hex: 0xEF4444)
            case .today:   return Color(hex: 0xF59E0B)
            case .thisWeek: return Color(hex: 0x3B82F6)
            }
        }
    }

    private let cost = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PSSpacing.xxl) {
                    header
                    ingredientField
                    urgencyPicker
                    podPicker
                    balanceRow
                    pingButton
                    howItWorksNote
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)
                .padding(.vertical, PSSpacing.lg)
            }
            .background(PSColors.backgroundPrimary)
            .navigationTitle("Request Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PSColors.textSecondary)
                }
            }
            .overlay(alignment: .top) {
                if showSuccessToast {
                    successToast
                        .padding(.top, PSSpacing.xl)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: PSSpacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x8B5CF6).opacity(0.15), Color(hex: 0xEC4899).opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: PSLayout.scaledFont(34)))
                    .foregroundStyle(Color(hex: 0x8B5CF6))
            }
            VStack(spacing: PSSpacing.xs) {
                Text("Ping Your Pod")
                    .font(.system(size: PSLayout.scaledFont(20), weight: .black, design: .rounded))
                Text("Need one egg for a cake? Your neighbours probably have a spare. Faster than the shop.")
                    .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }

    private var ingredientField: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("WHAT DO YOU NEED?")
                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                .foregroundStyle(PSColors.textSecondary).tracking(0.8)

            HStack(spacing: PSSpacing.md) {
                TextField("e.g. One egg, half an onion…", text: $ingredientName)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    .padding(PSSpacing.md)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .strokeBorder(PSColors.borderLight, lineWidth: 1))

                TextField("Qty", text: $quantity)
                    .font(.system(size: PSLayout.scaledFont(16), weight: .semibold))
                    .multilineTextAlignment(.center)
                    .frame(width: PSLayout.scaled(60))
                    .padding(PSSpacing.md)
                    .background(PSColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                        .strokeBorder(PSColors.borderLight, lineWidth: 1))
                    .keyboardType(.numberPad)
            }
        }
    }

    private var urgencyPicker: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("HOW SOON?")
                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                .foregroundStyle(PSColors.textSecondary).tracking(0.8)

            HStack(spacing: PSSpacing.sm) {
                ForEach(Urgency.allCases, id: \.self) { urgency in
                    Button {
                        PSHaptics.shared.lightTap()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedUrgency = urgency
                        }
                    } label: {
                        VStack(spacing: PSSpacing.xs) {
                            Image(systemName: urgency.icon)
                                .font(.system(size: PSLayout.scaledFont(20)))
                                .foregroundStyle(selectedUrgency == urgency ? .white : urgency.color)
                            Text(urgency.rawValue)
                                .font(.system(size: PSLayout.scaledFont(12), weight: .semibold))
                                .foregroundStyle(selectedUrgency == urgency ? .white : PSColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, PSSpacing.lg)
                        .background(selectedUrgency == urgency ? urgency.color : PSColors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                            .strokeBorder(selectedUrgency == urgency ? Color.clear : PSColors.borderLight, lineWidth: 1))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private var podPicker: some View {
        VStack(alignment: .leading, spacing: PSSpacing.sm) {
            Text("BROADCAST TO POD")
                .font(.system(size: PSLayout.scaledFont(11), weight: .black))
                .foregroundStyle(PSColors.textSecondary).tracking(0.8)

            let joined = podService.nearbyPods.filter { podService.isJoined($0) }
            if joined.isEmpty {
                HStack(spacing: PSSpacing.md) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(18)))
                        .foregroundStyle(PSColors.secondaryAmber)
                    Text("Join a pod first to ping your neighbours.")
                        .font(.system(size: PSLayout.scaledFont(13), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                    Spacer()
                }
                .padding(PSSpacing.lg)
                .background(PSColors.secondaryAmber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            } else {
                ForEach(joined) { pod in
                    podRow(pod)
                }
            }
        }
    }

    private func podRow(_ pod: LocalPod) -> some View {
        let isSelected = selectedPodId == pod.id
        return Button {
            PSHaptics.shared.lightTap()
            selectedPodId = pod.id
        } label: {
            HStack(spacing: PSSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(pod.podType.color.opacity(0.12))
                        .frame(width: PSLayout.scaled(40), height: PSLayout.scaled(40))
                    Image(systemName: pod.podType.icon)
                        .font(.system(size: PSLayout.scaledFont(16)))
                        .foregroundStyle(pod.podType.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(pod.name)
                        .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                        .foregroundStyle(PSColors.textPrimary)
                    Text("\(pod.memberCount) members")
                        .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                        .foregroundStyle(PSColors.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: PSLayout.scaledFont(20)))
                        .foregroundStyle(pod.podType.color)
                }
            }
            .padding(PSSpacing.md)
            .background(isSelected ? pod.podType.color.opacity(0.08) : PSColors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
                .strokeBorder(isSelected ? pod.podType.color : PSColors.borderLight, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var balanceRow: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: PSLayout.scaledFont(22)))
                .foregroundStyle(Color(hex: 0x8B5CF6))
            VStack(alignment: .leading, spacing: 1) {
                Text("Cost: \(cost) Karma Credits")
                    .font(.system(size: PSLayout.scaledFont(14), weight: .bold))
                    .foregroundStyle(PSColors.textPrimary)
                Text("Your balance: \(karmaService.balance) credits")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
            }
            Spacer()
            if karmaService.canAfford(cost) {
                Text("✓ Ready")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .foregroundStyle(PSColors.primaryGreen)
            } else {
                Text("Low balance")
                    .font(.system(size: PSLayout.scaledFont(12), weight: .bold))
                    .foregroundStyle(PSColors.expiredRed)
            }
        }
        .padding(PSSpacing.lg)
        .background(Color(hex: 0x8B5CF6).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous)
            .strokeBorder(Color(hex: 0x8B5CF6).opacity(0.2), lineWidth: 1))
    }

    private var pingButton: some View {
        let isEnabled = !ingredientName.isEmpty && selectedPodId != nil && karmaService.canAfford(cost)
        return Button {
            PSHaptics.shared.mediumTap()
            guard isEnabled else { return }
            let podName = podService.nearbyPods.first(where: { $0.id == selectedPodId })?.name
            _ = karmaService.spend(itemName: ingredientName, amount: cost, otherParty: podName)
            withAnimation { showSuccessToast = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            }
        } label: {
            HStack(spacing: PSSpacing.sm) {
                Image(systemName: "paperplane.fill")
                Text("Send Ping")
            }
            .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, PSSpacing.lg)
            .background(isEnabled ? Color(hex: 0x8B5CF6) : PSColors.borderLight)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
            .shadow(color: isEnabled ? Color(hex: 0x8B5CF6).opacity(0.3) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
    }

    private var howItWorksNote: some View {
        HStack(alignment: .top, spacing: PSSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: PSLayout.scaledFont(12)))
                .foregroundStyle(PSColors.textTertiary)
            Text("Your pod gets notified instantly. Whoever responds first gets the credit — faster than a shop, better than waste.")
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
                .lineSpacing(2)
        }
        .padding(.horizontal, PSSpacing.xl)
    }

    private var successToast: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PSColors.primaryGreen)
            Text("Ping sent! Your pod has been notified.")
                .font(.system(size: PSLayout.scaledFont(13), weight: .semibold))
                .foregroundStyle(PSColors.textPrimary)
        }
        .padding(PSSpacing.md)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
        .elevation(.z2)
    }
}

#Preview { IngredientPingView() }
