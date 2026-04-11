import SwiftUI
import SwiftData

/// Multi-screen Spotify Wrapped-style animated weekly impact summary
struct ImpactWrapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var wrapData: ImpactWrapDataService.WeeklyWrapData?
    @State private var currentScreen: Int = 0
    @State private var autoAdvanceTimer: Timer?
    @State private var isAutoAdvancing = true

    private let dataService: ImpactWrapDataService
    private let totalScreens = 7

    init(modelContext: ModelContext) {
        self.dataService = ImpactWrapDataService(modelContext: modelContext)
    }

    var body: some View {
        if let wrapData {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()

                // Screen content
                screenContent
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))

                // Progress indicators
                progressIndicators
                    .padding(.bottom, PSSpacing.xl)
            }
            .onAppear {
                startAutoAdvance()
            }
            .onDisappear {
                stopAutoAdvance()
            }
            .onTapGesture {
                advanceToNext()
            }
            .gesture(swipeGesture)
        } else {
            ProgressView()
                .task {
                    wrapData = dataService.calculateCurrentWeekWrapData()
                }
        }
    }

    // MARK: - Screen Content Router

    @ViewBuilder
    private var screenContent: some View {
        switch currentScreen {
        case 0:
            IntroScreen(wrapData: wrapData!)
        case 1:
            ItemsSavedScreen(wrapData: wrapData!)
        case 2:
            MoneySavedScreen(wrapData: wrapData!)
        case 3:
            EnvironmentalImpactScreen(wrapData: wrapData!)
        case 4:
            TopCategoryScreen(wrapData: wrapData!)
        case 5:
            StreakScreen(wrapData: wrapData!)
        case 6:
            SummaryScreen(wrapData: wrapData!, onShare: shareImpact, onDone: { dismiss() })
        default:
            IntroScreen(wrapData: wrapData!)
        }
    }

    // MARK: - Progress Indicators

    private var progressIndicators: some View {
        VStack(spacing: PSSpacing.lg) {
            Spacer()

            // Tap to continue text (shows on first screen only)
            if currentScreen == 0 {
                Text("Tap or swipe to continue")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.7))
                    .transition(.opacity)
            }

            // Progress dots
            HStack(spacing: PSSpacing.sm) {
                ForEach(0..<totalScreens, id: \.self) { index in
                    Circle()
                        .fill(
                            index == currentScreen
                                ? Color.white
                                : Color.white.opacity(0.3)
                        )
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentScreen ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentScreen)
                }
            }
            .padding(.horizontal, PSSpacing.lg)
            .padding(.vertical, PSSpacing.md)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                stopAutoAdvance()

                if value.translation.width < -50 {
                    advanceToNext()
                } else if value.translation.width > 50 {
                    advanceToPrevious()
                }

                startAutoAdvance()
            }
    }

    // MARK: - Navigation

    private func advanceToNext() {
        withAnimation(PSMotion.springQuick) {
            if currentScreen < totalScreens - 1 {
                currentScreen += 1
                stopAutoAdvance()
                startAutoAdvance()
            }
        }
    }

    private func advanceToPrevious() {
        withAnimation(PSMotion.springQuick) {
            if currentScreen > 0 {
                currentScreen -= 1
                stopAutoAdvance()
                startAutoAdvance()
            }
        }
    }

    // MARK: - Auto-advance

    private func startAutoAdvance() {
        stopAutoAdvance()

        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            advanceToNext()
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }

    // MARK: - Sharing

    private func shareImpact() {
        let cardView = ImpactWrapCardView(wrapData: wrapData!, showBranding: true)
            .frame(width: 360, height: 640)

        if let image = renderViewToImage(cardView, scale: 3.0) {
            shareImage(image)
        }
    }

    @MainActor
    private func renderViewToImage(_ view: some View, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage
    }

    private func shareImage(_ image: UIImage) {
        let items: [Any] = [image]
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)

        activity.excludedActivityTypes = [.print, .saveToCameraRoll]

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController
        {
            rootViewController.present(activity, animated: true)
        }
    }
}

// MARK: - Screen 1: Intro

private struct IntroScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    @State private var showTitle = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [PSColors.primaryGreenDark, .black]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: PSSpacing.xxxl) {
                Spacer()

                // Title with animation
                VStack(spacing: PSSpacing.md) {
                    Text("Your Week")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.white)

                    Text("in Review")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(PSColors.primaryGreen)
                }
                .opacity(showTitle ? 1 : 0)
                .scaleEffect(showTitle ? 1 : 0.8)
                .onAppear {
                    withAnimation(PSMotion.springGentle) {
                        showTitle = true
                    }
                }

                Spacer()

                // Date range
                Text(wrapData.weekDisplayRange)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(showTitle ? 1 : 0)

                Spacer()

                // Subtle indicator
                VStack(spacing: PSSpacing.sm) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    Text("Swipe to continue")
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, PSSpacing.xxxl)
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
    }
}

// MARK: - Screen 2: Items Saved

private struct ItemsSavedScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    @State private var displayedCount = 0

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [PSColors.primaryGreen.opacity(0.8), PSColors.accentTeal]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: PSSpacing.xxxl) {
                Spacer()

                VStack(spacing: PSSpacing.xl) {
                    // Large counter
                    Text("\(displayedCount)")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text("items rescued\nfrom waste")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Spacer()

                // Category breakdown with staggered animations
                VStack(spacing: PSSpacing.lg) {
                    ForEach(wrapData.categoryBreakdown.prefix(4), id: \.category.id) { category, count in
                        CategoryBreakdownRow(
                            category: category,
                            count: count,
                            emoji: category.emoji
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading)
                        ))
                    }
                }
                .padding(.horizontal, PSSpacing.lg)

                Spacer()
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .onAppear {
                animateCounter()
            }
        }
    }

    private func animateCounter() {
        // `.contentTransition(.numericText())` on the Text view interpolates
        // Int changes automatically, so a single `withAnimation` does the
        // entire count-up — no manual tick loop needed.
        withAnimation(.easeOut(duration: 1.5)) {
            displayedCount = wrapData.itemsSaved
        }
    }
}

private struct CategoryBreakdownRow: View {
    let category: FoodCategory
    let count: Int
    let emoji: String

    var body: some View {
        HStack(spacing: PSSpacing.md) {
            Text(emoji)
                .font(.system(size: 28))

            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.white)

                Text("\(count) items")
                    .font(.system(size: 12, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Text("\(count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(PSSpacing.md)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))
    }
}

// MARK: - Screen 3: Money Saved

private struct MoneySavedScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    @State private var displayedAmount = 0.0

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0xF59E0B).opacity(0.8),
                    Color(hex: 0xF97316)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating dollar signs
            Canvas { context, size in
                for _ in 0..<10 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let text = Text("$")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white.opacity(0.1))

                    var stringContext = context
                    stringContext.translateBy(x: x, y: y)
                }
            }

            VStack(spacing: PSSpacing.xxxl) {
                Spacer()

                VStack(spacing: PSSpacing.xl) {
                    Text("$\(Int(displayedAmount))")
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text("Money Saved")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.95))
                }

                Spacer()

                // Comparison
                Text(wrapData.weekOverWeekLabel)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, PSSpacing.lg)
                    .padding(.vertical, PSSpacing.md)
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                Spacer()
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .onAppear {
                animateAmount()
            }
        }
    }

    private func animateAmount() {
        // Double values interpolate natively under `withAnimation`; paired
        // with `.contentTransition(.numericText())` the digits roll cleanly.
        withAnimation(.easeOut(duration: 1.5)) {
            displayedAmount = wrapData.moneySaved
        }
    }
}

// MARK: - Screen 4: Environmental Impact

private struct EnvironmentalImpactScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    @State private var displayedCO2 = 0.0
    @State private var showTrees = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    PSColors.accentTeal.opacity(0.8),
                    Color(hex: 0x0891B2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: PSSpacing.xxxl) {
                Spacer()

                VStack(spacing: PSSpacing.xl) {
                    Text("\(String(format: "%.1f", displayedCO2))kg")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())

                    Text("CO₂ Avoided")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.95))
                }

                Spacer()

                // Tree equivalence
                if showTrees {
                    VStack(spacing: PSSpacing.md) {
                        HStack(spacing: PSSpacing.sm) {
                            ForEach(0..<wrapData.treesEquivalent, id: \.self) { _ in
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Text("That's like planting \(wrapData.treesEquivalent) tree\(wrapData.treesEquivalent > 1 ? "s" : "")")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(.white.opacity(0.9))
                            .transition(.opacity)
                    }
                    .animation(.staggered(staggerInterval: 0.1), value: showTrees)
                }

                Spacer()
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .task { await runEntrance() }
        }
    }

    @MainActor
    private func runEntrance() async {
        // Counter interpolates natively; trees stagger in after it lands.
        withAnimation(.easeOut(duration: 1.5)) {
            displayedCO2 = wrapData.co2Avoided
        }
        try? await Task.sleep(for: .seconds(1))
        withAnimation(PSMotion.springGentle) {
            showTrees = true
        }
    }
}

// MARK: - Screen 5: Top Category

private struct TopCategoryScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    @State private var emojiScale: CGFloat = 0.5
    @State private var emojiRotation: Double = -45

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    PSColors.categoryColor(for: wrapData.topCategorySaved).opacity(0.8),
                    PSColors.categoryColor(for: wrapData.topCategorySaved).opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: PSSpacing.xxxl) {
                Spacer()

                Text("Your Top Category")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.white.opacity(0.8))

                // Large bouncing emoji
                Text(wrapData.topCategorySaved.emoji)
                    .font(.system(size: 120))
                    .scaleEffect(emojiScale)
                    .rotationEffect(.degrees(emojiRotation))
                    .onAppear {
                        withAnimation(
                            Animation.spring(response: 0.6, dampingFraction: 0.5)
                                .repeatCount(2, autoreverses: true)
                        ) {
                            emojiScale = 1.1
                        }

                        withAnimation(
                            Animation.spring(response: 0.6, dampingFraction: 0.5)
                                .repeatCount(2, autoreverses: true)
                        ) {
                            emojiRotation = 15
                        }
                    }

                VStack(spacing: PSSpacing.md) {
                    Text(wrapData.topCategorySaved.displayName)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.white)

                    Text("\(wrapData.topCategoryCount) items saved")
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Fun fact
                VStack(spacing: PSSpacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text(categoryFunFact)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(PSSpacing.md)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                Spacer()
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
        }
    }

    private var categoryFunFact: String {
        switch wrapData.topCategorySaved {
        case .fruits:
            return "Fruits are rich in vitamins and have a short shelf life, so saving them makes a huge impact!"
        case .vegetables:
            return "You're preventing waste on the most environmentally friendly foods!"
        case .dairy:
            return "Dairy production requires significant resources, so saving it counts for a lot."
        case .meat:
            return "Meat has the highest carbon footprint, so saving it is extra impactful!"
        case .seafood:
            return "Seafood is both expensive and resource-intensive. Great job saving it!"
        case .bakery:
            return "Baked goods are best when fresh. Nice work preventing waste!"
        case .frozen:
            return "Frozen items last longer, so you're doing great extending their life!"
        case .canned:
            return "Canned goods are shelf-stable, but your mindfulness still prevents waste!"
        case .condiments:
            return "Small items add up! These condiments help reduce overall household waste."
        case .snacks:
            return "Snacks are easy to waste. Great job being mindful!"
        case .beverages:
            return "Beverages make up a surprising amount of household waste. Nice work!"
        case .grains:
            return "Grains are staples that feed your household efficiently!"
        case .other:
            return "Every item counts! You're making a difference across all food types."
        }
    }
}

// MARK: - Screen 6: Streak

private struct StreakScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    @State private var showStreak = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: 0xEF4444).opacity(0.8),
                    Color(hex: 0xDC2626)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: PSSpacing.xxxl) {
                Spacer()

                if showStreak {
                    VStack(spacing: PSSpacing.xl) {
                        HStack(alignment: .top, spacing: PSSpacing.lg) {
                            if wrapData.currentStreak > 3 {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundColor(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            VStack(alignment: .leading, spacing: PSSpacing.xs) {
                                Text("\(wrapData.currentStreak)")
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .contentTransition(.numericText())

                                Text("Day Streak")
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                                    .foregroundColor(.white.opacity(0.9))
                            }

                            Spacer()
                        }

                        Text(wrapData.streakLabel)
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                    .animation(PSMotion.springGentle, value: showStreak)
                }

                Spacer()

                // Motivational message
                VStack(spacing: PSSpacing.sm) {
                    Text(motivationalMessage)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(PSSpacing.md)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusMd, style: .continuous))

                Spacer()
            }
            .padding(.horizontal, PSSpacing.screenHorizontal)
            .onAppear {
                withAnimation(PSMotion.springDefault) {
                    showStreak = true
                }
            }
        }
    }

    private var motivationalMessage: String {
        if wrapData.currentStreak >= 7 {
            return "You're unstoppable! Keep saving food every single day."
        } else if wrapData.currentStreak >= 3 {
            return "Amazing momentum! Just a few more days to reach a week."
        } else if wrapData.currentStreak >= 1 {
            return "Great start! Come back tomorrow to keep your streak alive."
        } else {
            return "Start your streak today by saving food from waste!"
        }
    }
}

// MARK: - Screen 7: Summary

private struct SummaryScreen: View {
    let wrapData: ImpactWrapDataService.WeeklyWrapData
    let onShare: () -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    PSColors.primaryGreen.opacity(0.8),
                    PSColors.accentTeal.opacity(0.8)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: PSSpacing.xl) {
                Spacer()

                // Card preview
                ImpactWrapCardView(wrapData: wrapData, showBranding: true)
                    .frame(height: 300)
                    .scaleEffect(0.7)

                Spacer()

                // Action buttons
                VStack(spacing: PSSpacing.md) {
                    Button(action: onShare) {
                        HStack(spacing: PSSpacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Your Impact")
                        }
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(PSColors.textOnPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                    }

                    Button(action: onDone) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundColor(PSColors.textOnPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(PSColors.primaryGreenDark)
                            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusLg, style: .continuous))
                    }
                }
                .padding(.horizontal, PSSpacing.screenHorizontal)

                Spacer()
            }
        }
    }
}

// MARK: - Animation Extensions

extension Animation {
    static func staggered(staggerInterval: Double) -> Animation {
        Animation.easeInOut(duration: 0.5).delay(staggerInterval)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: FreshliItem.self, configurations: config)

    NavigationStack {
        ImpactWrapView(modelContext: container.mainContext)
            .modelContainer(container)
    }
}
