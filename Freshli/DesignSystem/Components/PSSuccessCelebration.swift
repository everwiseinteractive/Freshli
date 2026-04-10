import SwiftUI

// Figma: SuccessCelebration — full-screen bg-green-500
// Two radial pulse: bg-green-400 (120vw), bg-green-300 (80vw) with mix-blend-overlay
// Icon: w-32 h-32 bg-green-400 rounded-[2.5rem] shadow-2xl
// 6 confetti: animated keyframes scale [0,1.5,0], random offsets 200px, opacity [1,1,0]
// Title: text-4xl font-black text-white tracking-tight (36px)
// Description: text-green-100 text-lg font-medium
// CTA: w-full h-16 bg-white text-green-600 rounded-[1.25rem] shadow-xl shadow-green-900/20

struct PSSuccessCelebration: View {
    @Binding var isPresented: Bool
    let title: String
    let description: String
    var actionLabel: String = String(localized: "Continue")
    var icon: String = "checkmark.circle"

    @State private var showContent = false
    @State private var confettiPhase: CGFloat = 0

    var body: some View {
        if isPresented {
            ZStack {
                // Figma: bg-green-500 full screen
                PSColors.primaryGreen
                    .ignoresSafeArea()

                // Figma: decorative circles with springs.slow entrance
                Circle()
                    .fill(PSColors.green400.opacity(0.3))
                    .frame(width: ScreenMetrics.bounds.width * 1.2,
                           height: ScreenMetrics.bounds.width * 1.2)
                    .scaleEffect(showContent ? 1 : 0)
                    .opacity(showContent ? 1 : 0)
                    .blendMode(.overlay)

                Circle()
                    .fill(Color(hex: 0x86EFAC).opacity(0.4)) // green-300
                    .frame(width: ScreenMetrics.bounds.width * 0.8,
                           height: ScreenMetrics.bounds.width * 0.8)
                    .scaleEffect(showContent ? 1 : 0)
                    .opacity(showContent ? 1 : 0)
                    .blendMode(.overlay)

                VStack(spacing: 0) {
                    Spacer()

                    // Figma: w-32 h-32 bg-green-400 rounded-[2.5rem] shadow-2xl
                    ZStack {
                        RoundedRectangle(cornerRadius: PSSpacing.radiusHero, style: .continuous)
                            .fill(PSColors.green400)
                            .adaptiveFrame(width: 128, height: 128)
                            .shadow(color: .black.opacity(0.25), radius: 25, y: 12)

                        Image(systemName: icon)
                            .font(.system(size: 64, weight: .regular))
                            .foregroundStyle(.white)
                            .scaleEffect(showContent ? 1 : 0.8)

                        // Figma: 6 confetti particles with keyframe animation
                        ForEach(0..<6, id: \.self) { i in
                            ConfettiParticle(
                                index: i,
                                animate: showContent
                            )
                        }
                    }
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    .padding(.bottom, 40)

                    // Figma: text-4xl font-black = 36px weight 900
                    Text(title)
                        .font(.system(size: 36, weight: .black))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .padding(.bottom, 16)

                    // Figma: text-green-100 (#DCFCE7) text-lg font-medium
                    Text(description)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(hex: 0xDCFCE7)) // green-100
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    Spacer()

                    // Figma: w-full h-16 bg-white text-green-600 rounded-[1.25rem]
                    // shadow-xl shadow-green-900/20
                    Button {
                        withAnimation(PSMotion.springDefault) {
                            isPresented = false
                        }
                    } label: {
                        Text(actionLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PSColors.headerGreen)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXl, style: .continuous))
                            .shadow(color: Color(hex: 0x14532D).opacity(0.2), radius: 20, y: 8) // green-900/20
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .onAppear {
                withAnimation(PSMotion.springBouncy.delay(0.1)) {
                    showContent = true
                }
            }
            .onDisappear { showContent = false }
        }
    }
}

// Figma: Confetti particle with scale [0, 1.5, 0] and random offset animation
private struct ConfettiParticle: View {
    let index: Int
    let animate: Bool

    private var angle: Double { Double(index) * (360.0 / 6.0) + Double.random(in: -30...30) }
    private var distance: CGFloat { CGFloat.random(in: 60...120) }

    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 12, height: 12)
            .offset(x: offsetX, y: offsetY)
            .onAppear {
                let radians = angle * .pi / 180
                let targetX = cos(radians) * distance
                let targetY = sin(radians) * distance

                withAnimation(
                    .easeOut(duration: 1.0).delay(0.3)
                ) {
                    offsetX = targetX
                    offsetY = targetY
                }
            }
            .modifier(ConfettiKeyframeModifier(animate: animate, index: index))
    }
}

private struct ConfettiKeyframeModifier: ViewModifier {
    let animate: Bool
    let index: Int

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: animate) { _, newValue in
                if newValue {
                    // Phase 1: grow
                    withAnimation(.easeOut(duration: 0.3).delay(0.2 + Double(index) * 0.03)) {
                        scale = 1.5
                    }
                    // Phase 2: shrink and fade
                    withAnimation(.easeIn(duration: 0.5).delay(0.6 + Double(index) * 0.03)) {
                        scale = 0
                        opacity = 0
                    }
                }
            }
    }
}

#Preview {
    PSSuccessCelebration(
        isPresented: .constant(true),
        title: "Added to Pantry!",
        description: "Your item is now tracked. We'll remind you before it expires.",
        actionLabel: "Awesome"
    )
}
