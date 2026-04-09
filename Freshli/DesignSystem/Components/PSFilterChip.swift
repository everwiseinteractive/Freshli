import SwiftUI

struct PSFilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: PSSpacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(PSTypography.caption1Medium)
            }
            .padding(.horizontal, PSSpacing.md)
            .padding(.vertical, PSSpacing.sm)
            .foregroundStyle(isSelected ? PSColors.textOnPrimary : PSColors.textSecondary)
            .background(isSelected ? PSColors.primaryGreen : PSColors.backgroundSecondary)
            .clipShape(Capsule())
            .overlay {
                if !isSelected {
                    Capsule()
                        .strokeBorder(PSColors.borderLight, lineWidth: 1)
                } else {
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
            }
            .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PSFilterChipRow<Item: Identifiable & Hashable>: View {
    let items: [Item]
    @Binding var selection: Item?
    let titleFor: (Item) -> String
    var iconFor: ((Item) -> String)?
    var showAll: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PSSpacing.sm) {
                if showAll {
                    PSFilterChip(
                        title: String(localized: "All"),
                        isSelected: selection == nil
                    ) {
                        withAnimation(PSMotion.springBouncy) { selection = nil }
                    }
                }

                ForEach(items) { item in
                    PSFilterChip(
                        title: titleFor(item),
                        icon: iconFor?(item),
                        isSelected: selection == item
                    ) {
                        withAnimation(PSMotion.springBouncy) {
                            selection = selection == item ? nil : item
                        }
                    }
                }
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            PSFilterChip(title: "All", isSelected: true, action: {})
            PSFilterChip(title: "Fruits", icon: "leaf.fill", isSelected: false, action: {})
            PSFilterChip(title: "Dairy", isSelected: false, action: {})
        }
    }
    .padding()
}
