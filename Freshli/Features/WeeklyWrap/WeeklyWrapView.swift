import SwiftUI
import SwiftData

/// Full-screen vertical-story format Weekly Wrap (Instagram/Spotify style)
struct WeeklyWrapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel: WeeklyWrapViewModel?
    @State private var currentSlide: Int = 0
    @State private var autoAdvanceTimer: Timer?
    @State private var pulsePhase: CGFloat = 0

    private let totalSlides = 3

    var body: some View {
        Group {
            if let viewModel {
                storyContent(viewModel: viewModel)
            } else {
                loadingView
            }
        }
        .statusBarHidden()
    }

    // MARK: - Loading

    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
        }
        .task {
            let dataService = ImpactWrapDataService(modelContext: modelContext)
            if let data = dataService.calculateCurrentWeekWrapData() {
                viewModel = WeeklyWrapViewModel(wrapData: data)
                AnalyticsService.shared.track(.weeklyWrapOpened, properties: .props([
                    "items_saved":   data.totalItemsImpacted,
                    "co2_avoided_g": Int(data.co2Avoided * 1_000)
                ]))
            }
        }
    }

    // MARK: - Story Content

    @ViewBuilder
    private func storyContent(viewModel: WeeklyWrapViewModel) -> some View {
        ZStack {
            // Animated pulse background
            pulseBackground(viewModel: viewModel)

            // Slide content
            Group {
                switch currentSlide {
                case 0:
                    BigNumberSlide(viewModel: viewModel)
                case 1:
                    CommunityHeroSlide(viewModel: viewModel)
                case 2:
                    EnvironmentalImpactSlide(
                        viewModel: viewModel,
                        onShare: { shareStory(viewModel: viewModel) },
                        onDone: { dismiss() }
                    )
                default:
                    BigNumberSlide(viewModel: viewModel)
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            // Progress bar + close
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.top, PSSpacing.sm)

                HStack {
                    Spacer()
                    Button {
                        PSHaptics.shared.lightTap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, PSSpacing.lg)
                    .padding(.top, PSSpacing.sm)
                }

                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear { startAutoAdvance() }
        .onDisappear { stopAutoAdvance() }
        .onTapGesture { advanceToNext() }
        .gesture(swipeGesture)
    }

    // MARK: - Pulse Background

    @ViewBuilder
    private func pulseBackground(viewModel: WeeklyWrapViewModel) -> some View {
        let pulseColor = categoryPulseColor(for: viewModel.wrapData.topCategorySaved)

        ZStack {
            Color.black.ignoresSafeArea()

            // Layered radial pulses
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                pulseColor.opacity(0.3 - Double(i) * 0.08),
                                pulseColor.opacity(0)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: PSLayout.screenWidth * (0.6 + pulsePhase * 0.4)
                        )
                    )
                    .scaleEffect(1.0 + pulsePhase * CGFloat(i + 1) * 0.15)
                    .opacity(0.6 - pulsePhase * 0.2)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.5)
                .repeatForever(autoreverses: true)
            ) {
                pulsePhase = 1
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: PSSpacing.xs) {
            ForEach(0..<totalSlides, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))

                        if index < currentSlide {
                            Capsule()
                                .fill(Color.white)
                        } else if index == currentSlide {
                            Capsule()
                                .fill(Color.white)
                                .frame(width: geo.size.width)
                                .animation(.linear(duration: 6.0), value: currentSlide)
                        }
                    }
                }
                .frame(height: 3)
            }
        }
    }

    // MARK: - Gestures & Navigation

    private var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.width < -50 {
                    advanceToNext()
                } else if value.translation.width > 50 {
                    advanceToPrevious()
                }
            }
    }

    private func advanceToNext() {
        PSHaptics.shared.lightTap()
        withAnimation(PSMotion.springQuick) {
            if currentSlide < totalSlides - 1 {
                currentSlide += 1
                resetAutoAdvance()
            }
        }
    }

    private func advanceToPrevious() {
        PSHaptics.shared.selection()
        withAnimation(PSMotion.springQuick) {
            if currentSlide > 0 {
                currentSlide -= 1
                resetAutoAdvance()
            }
        }
    }

    private func startAutoAdvance() {
        stopAutoAdvance()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
            advanceToNext()
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    private func resetAutoAdvance() {
        stopAutoAdvance()
        startAutoAdvance()
    }

    // MARK: - Sharing

    private func shareStory(viewModel: WeeklyWrapViewModel) {
        PSHaptics.shared.mediumTap()
        AnalyticsService.shared.track(.weeklyWrapShared, properties: .props([
            "items_saved": viewModel.wrapData.totalItemsImpacted
        ]))
        let card = WeeklyWrapShareCard(viewModel: viewModel)
            .frame(width: 360, height: 640)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }

        let activity = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        activity.excludedActivityTypes = [.print]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let root = window.rootViewController {
            root.present(activity, animated: true)
        }
    }

    // MARK: - Category Pulse Color

    private func categoryPulseColor(for category: FoodCategory) -> Color {
        switch category {
        case .vegetables, .condiments:
            return PSColors.primaryGreen
        case .fruits, .bakery, .snacks:
            return Color(hex: 0xFBBF24) // warm yellow
        case .meat:
            return Color(hex: 0xEF5350)
        case .seafood:
            return PSColors.accentTeal
        case .dairy:
            return Color(hex: 0x42A5F5)
        case .beverages:
            return Color(hex: 0x29B6F6)
        case .grains:
            return Color(hex: 0xA1887F)
        case .frozen:
            return Color(hex: 0x7E57C2)
        case .canned:
            return Color(hex: 0xAB47BC)
        case .other:
            return PSColors.primaryGreen
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FreshliItem.self, configurations: config)

    WeeklyWrapView()
        .modelContainer(container)
}
