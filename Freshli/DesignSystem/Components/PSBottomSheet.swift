import SwiftUI

// Figma: BottomSheet — rounded-t-[2.5rem], drag-to-dismiss
// Overlay: bg-neutral-900/40 backdrop-blur-sm
// Handle: w-12 h-1.5 bg-neutral-200 rounded-full
// Close: p-2 bg-neutral-100 rounded-full, X at 20px
// Title: text-2xl font-bold tracking-tight

struct PSBottomSheet<Content: View>: View {
    @Binding var isPresented: Bool
    var title: String?
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                // Figma: bg-neutral-900/40 backdrop-blur-sm
                Color(hex: 0x171717).opacity(0.4)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }
                    .transition(.opacity)

                // Sheet
                VStack(spacing: 0) {
                    // Figma: w-12 h-1.5 bg-neutral-200 rounded-full with glass header
                    VStack {
                        Capsule()
                            .fill(PSColors.neutral200)
                            .frame(width: 48, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .background(.ultraThinMaterial.opacity(0.3))
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.2)
                    }

                    if let title {
                        HStack {
                            Text(title)
                                .font(.system(size: 24, weight: .bold))
                                .tracking(-0.3)
                                .foregroundStyle(PSColors.textPrimary)
                            Spacer()
                            // Figma: p-2 bg-neutral-100 rounded-full, X at 20px
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PSColors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(PSColors.backgroundSecondary)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                        Divider()
                            .foregroundStyle(PSColors.borderLight)
                    }

                    ScrollView {
                        content()
                            .padding(24)
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.9)
                // Figma: bg-white, dark:bg-neutral-900
                .background(PSColors.surfaceCard)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: PSSpacing.radiusHero,
                        topTrailingRadius: PSSpacing.radiusHero
                    )
                )
                .offset(y: max(dragOffset, 0))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > 150 || value.velocity.height > 500 {
                                dismiss()
                            } else {
                                withAnimation(PSMotion.springQuick) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .animation(PSMotion.springBouncy, value: isPresented)
        .ignoresSafeArea()
    }

    private func dismiss() {
        dragOffset = 0
        isPresented = false
    }
}
