import SwiftUI
import SwiftData

/// Full-screen vertical-story format Weekly Wrap (Instagram/Spotify style).
///
/// Visual revamp: animated MeshGradient background that shifts palette per
/// slide, glowing capsule progress bar, "cards in a deck" scale transition,
/// and celebrate haptic on the final slide.
struct WeeklyWrapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var viewModel: WeeklyWrapViewModel?
    @State private var currentSlide: Int = 0
    @State private var autoAdvanceTimer: Timer?

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
            // Animated MeshGradient background — shifts palette per slide
            meshBackground(viewModel: viewModel)

            // Slide content with "cards in a deck" scale transition
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
                insertion: .move(edge: .trailing)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96)),
                removal: .move(edge: .leading)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96))
            ))

            // Progress bar + close
            VStack(spacing: 0) {
                glowingProgressBar
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.top, PSSpacing.sm)
                    .sensoryFeedback(.impact(weight: .light), trigger: currentSlide)

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
        // Handoff: resume Weekly Wrap on another Apple device
        .userActivity("com.freshli.weeklyWrap") { activity in
            activity.title = "Freshli Weekly Wrap"
            activity.isEligibleForHandoff = true
        }
    }

    // MARK: - MeshGradient Background (iOS 26)
    //
    // Replaces the old flat-black-with-radial-pulses. A 3×3 MeshGradient
    // driven by TimelineView creates an organic, living atmosphere. Corner
    // points are pinned; edge and center points drift with a slow sin-wave.
    // Colors crossfade when the user swipes between slides, so each slide
    // has a distinct mood (forest green → warm amber → cool teal).

    @ViewBuilder
    private func meshBackground(viewModel: WeeklyWrapViewModel) -> some View {
        let colors = viewModel.meshColors(for: currentSlide)

        ZStack {
            if reduceMotion {
                // Static fallback — no TimelineView, no drift
                MeshGradient(
                    width: 3, height: 3,
                    points: Self.staticMeshPoints,
                    colors: colors
                )
            } else {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSince1970
                        .truncatingRemainder(dividingBy: 10.0) / 10.0
                    let phase = Float(t * .pi * 2)
                    let d: Float = 0.03 // drift amplitude — subtle

                    MeshGradient(
                        width: 3, height: 3,
                        points: [
                            // Row 0: top edge — corners pinned
                            .init(0, 0),
                            .init(0.5 + d * sin(phase * 1.3), 0),
                            .init(1, 0),
                            // Row 1: middle — center drifts most
                            .init(0, 0.5 + d * sin(phase * 0.7)),
                            .init(0.5 + d * sin(phase), 0.5 + d * cos(phase * 0.9)),
                            .init(1, 0.5 + d * sin(phase * 1.1)),
                            // Row 2: bottom edge — corners pinned
                            .init(0, 1),
                            .init(0.5 + d * cos(phase * 0.8), 1),
                            .init(1, 1)
                        ],
                        colors: colors
                    )
                }
            }

            // Vignette overlay — keeps text legible at all scroll positions
            RadialGradient(
                gradient: Gradient(colors: [.clear, Color.black.opacity(0.35)]),
                center: .center,
                startRadius: PSLayout.screenWidth * 0.3,
                endRadius: PSLayout.screenWidth * 0.9
            )
        }
        .ignoresSafeArea()
        .animation(PSMotion.springDefault, value: currentSlide)
    }

    private static let staticMeshPoints: [SIMD2<Float>] = [
        .init(0, 0), .init(0.5, 0), .init(1, 0),
        .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
        .init(0, 1), .init(0.5, 1), .init(1, 1)
    ]

    // MARK: - Glowing Progress Bar
    //
    // 4pt capsules with green glow on completed slides, a trailing-edge
    // glow dot on the current slide, and dimmed upcoming slides. Each
    // slide change fires a `.sensoryFeedback(.impact)` on the container.

    private var glowingProgressBar: some View {
        HStack(spacing: PSSpacing.xxs) {
            ForEach(0..<totalSlides, id: \.self) { index in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.white.opacity(0.2))

                        if index < currentSlide {
                            // Completed — solid white + green glow
                            Capsule()
                                .fill(.white)
                                .shadow(color: PSColors.primaryGreen.opacity(0.5), radius: 4)
                        } else if index == currentSlide {
                            // Active — animated fill with trailing glow dot
                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width)
                                .animation(.linear(duration: 6.0), value: currentSlide)
                                .overlay(alignment: .trailing) {
                                    if !reduceMotion {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 8, height: 8)
                                            .blur(radius: 3)
                                            .shadow(color: .white.opacity(0.6), radius: 4)
                                    }
                                }
                        }
                    }
                }
                .frame(height: 4)
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
        withAnimation(PSMotion.springQuick) {
            if currentSlide < totalSlides - 1 {
                // Celebrate haptic on reaching the final slide
                if currentSlide == totalSlides - 2 {
                    PSHaptics.shared.success()
                } else {
                    PSHaptics.shared.lightTap()
                }
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
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FreshliItem.self, configurations: config)

    WeeklyWrapView()
        .modelContainer(container)
}
