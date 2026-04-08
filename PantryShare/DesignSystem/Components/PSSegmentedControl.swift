import SwiftUI

struct PSSegmentedControl<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let titleFor: (Item) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item == selection
                Button {
                    if selection != item { PSHaptics.shared.selection() }
                    withAnimation(PSMotion.springQuick) {
                        selection = item
                    }
                } label: {
                    Text(titleFor(item))
                        .font(PSTypography.subheadlineMedium)
                        .foregroundStyle(isSelected ? PSColors.textOnPrimary : PSColors.textSecondary)
                        .padding(.vertical, PSSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(PSColors.primaryGreen)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(titleFor(item))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(PSSpacing.xxxs + 1)
        .background(PSColors.backgroundSecondary)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

#Preview {
    @Previewable @State var selected = ListingType.share
    PSSegmentedControl(
        items: ListingType.allCases,
        selection: $selected,
        titleFor: { $0.displayName }
    )
    .padding()
}
