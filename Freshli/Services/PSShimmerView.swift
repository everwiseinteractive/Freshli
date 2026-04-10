import SwiftUI

// MARK: - PSShimmerView
/// Loading shimmer effect for skeleton screens

struct PSShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: PSSpacing.radiusMd)
            .fill(
                LinearGradient(
                    colors: [
                        Color.gray.opacity(0.2),
                        Color.gray.opacity(0.3),
                        Color.gray.opacity(0.2)
                    ],
                    startPoint: isAnimating ? .leading : .trailing,
                    endPoint: isAnimating ? .trailing : .leading
                )
            )
            .frame(height: 60)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating.toggle()
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        PSShimmerView()
        PSShimmerView()
        PSShimmerView()
    }
    .padding()
}
