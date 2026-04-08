import SwiftUI

struct PSSearchBar: View {
    @Binding var text: String
    var placeholder: String = String(localized: "Search...")
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: PSSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(PSColors.textTertiary)

            TextField(placeholder, text: $text)
                .font(PSTypography.body)
                .foregroundStyle(PSColors.textPrimary)
                .focused($isFocused)
                .onSubmit { onSubmit?() }
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    withAnimation(PSMotion.springQuick) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PSColors.textTertiary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.md)
        .background(PSColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .animation(PSMotion.springQuick, value: text.isEmpty)
    }
}

#Preview {
    @Previewable @State var text = ""
    PSSearchBar(text: $text, placeholder: "Search pantry...")
        .padding()
}
