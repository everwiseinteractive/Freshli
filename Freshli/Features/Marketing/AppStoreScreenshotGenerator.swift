import SwiftUI
import os

// ══════════════════════════════════════════════════════════════════
// MARK: - App Store Screenshot Generator
// Automated creation of high-resolution, device-frame-accurate
// marketing assets that showcase Freshli's Liquid Glass shaders.
//
// Architecture:
//   1. Device frames define pixel-perfect dimensions for each device
//   2. Marketing scenes compose app UI + copy + shader effects
//   3. PPO segments customize messaging for user personas
//   4. ImageRenderer exports @3x PNGs for App Store Connect upload
//
// Product Page Optimization (PPO):
//   Apple allows up to 3 alternative product pages with different
//   screenshots/copy. Each page targets a different user segment:
//     - Default: General "Food waste hero" messaging
//     - "The Athlete": Macro tracking, meal prep, protein focus
//     - "The Busy Professional": Time savings, smart automation
//     - "The Eco-Warrior": Environmental impact, sustainability
//
// Output sizes (required by App Store Connect):
//   - iPhone 17 Pro Max: 1320 × 2868 (6.9" Super Retina XDR)
//   - iPhone 17 Pro: 1206 × 2622 (6.3" ProMotion)
//   - iPad Pro 13": 2064 × 2752
//
// Usage:
//   AppStoreScreenshotGenerator.shared.generateAllScreenshots()
//   → outputs PNG files to the Documents directory
// ══════════════════════════════════════════════════════════════════

// MARK: - Device Frame

/// App Store Connect device frame dimensions.
enum ScreenshotDevice: String, CaseIterable, Sendable {
    case iPhone17ProMax = "iPhone 17 Pro Max"
    case iPhone17Pro = "iPhone 17 Pro"
    case iPadPro13 = "iPad Pro 13"

    var size: CGSize {
        switch self {
        case .iPhone17ProMax: return CGSize(width: 1320, height: 2868)
        case .iPhone17Pro: return CGSize(width: 1206, height: 2622)
        case .iPadPro13: return CGSize(width: 2064, height: 2752)
        }
    }

    var scale: CGFloat { 3.0 }

    /// Display-safe dimensions for on-screen preview (1/3 scale).
    var previewSize: CGSize {
        CGSize(width: size.width / scale, height: size.height / scale)
    }
}

// MARK: - PPO User Segment

/// Product Page Optimization segments — each gets customized copy.
enum PPOSegment: String, CaseIterable, Identifiable, Sendable {
    case `default` = "Default"
    case athlete = "The Athlete"
    case professional = "The Busy Professional"
    case ecoWarrior = "The Eco-Warrior"

    var id: String { rawValue }

    /// Headline copy for hero screenshot.
    var heroHeadline: String {
        switch self {
        case .default:      return "Rescue Your Food.\nSave the Planet."
        case .athlete:      return "Track Every Macro.\nZero Waste."
        case .professional: return "Smart Pantry.\nZero Effort."
        case .ecoWarrior:   return "Every Item Saved\nHeals the Earth."
        }
    }

    /// Subheadline copy.
    var heroSubheadline: String {
        switch self {
        case .default:      return "AI-powered food waste prevention"
        case .athlete:      return "Meal prep meets sustainability"
        case .professional: return "Automated expiry tracking saves you time"
        case .ecoWarrior:   return "Track your CO₂ impact in real-time"
        }
    }

    /// Feature callout for screenshot 2.
    var featureCallout: String {
        switch self {
        case .default:      return "Smart expiry alerts before food goes bad"
        case .athlete:      return "Recipe suggestions matched to your macros"
        case .professional: return "Scan receipts to auto-fill your pantry"
        case .ecoWarrior:   return "See your environmental impact grow daily"
        }
    }

    /// Accent color tint for the segment.
    var accentColor: Color {
        switch self {
        case .default:      return PSColors.primaryGreen
        case .athlete:      return Color(hex: 0x3B82F6)  // Blue
        case .professional: return Color(hex: 0x8B5CF6)  // Violet
        case .ecoWarrior:   return Color(hex: 0x10B981)  // Emerald
        }
    }
}

// MARK: - Screenshot Scene

/// Defines which app screen to showcase in each screenshot position.
enum ScreenshotScene: Int, CaseIterable, Sendable {
    case hero = 0          // App icon + headline + glass shader background
    case pantryView = 1    // Pantry with expiring items highlighted
    case recipeMatch = 2   // Recipe suggestions from pantry items
    case impactDash = 3    // Environmental impact dashboard
    case visionScan = 4    // Freshli Vision AR scanning

    var title: String {
        switch self {
        case .hero:        return "Hero"
        case .pantryView:  return "Smart Pantry"
        case .recipeMatch: return "Recipe Rescue"
        case .impactDash:  return "Impact Dashboard"
        case .visionScan:  return "Freshli Vision"
        }
    }
}

// MARK: - Screenshot Generator

@Observable @MainActor
final class AppStoreScreenshotGenerator {
    static let shared = AppStoreScreenshotGenerator()

    private(set) var isGenerating = false
    private(set) var progress: Double = 0
    private(set) var generatedCount = 0
    private(set) var totalCount = 0

    private let logger = Logger(subsystem: "com.freshli", category: "Screenshots")

    private init() {}

    /// Generates all screenshots for all devices and PPO segments.
    /// Outputs PNG files to the app's Documents/Screenshots directory.
    func generateAllScreenshots() async -> [URL] {
        isGenerating = true
        defer { isGenerating = false }

        let devices = ScreenshotDevice.allCases
        let segments = PPOSegment.allCases
        let scenes = ScreenshotScene.allCases

        totalCount = devices.count * segments.count * scenes.count
        generatedCount = 0
        progress = 0

        var outputURLs: [URL] = []

        for device in devices {
            for segment in segments {
                for scene in scenes {
                    let url = generateScreenshot(
                        device: device,
                        segment: segment,
                        scene: scene
                    )
                    if let url {
                        outputURLs.append(url)
                    }
                    generatedCount += 1
                    progress = Double(generatedCount) / Double(totalCount)
                }
            }
        }

        logger.info("Screenshot generation complete: \(outputURLs.count)/\(self.totalCount) exported")
        return outputURLs
    }

    /// Generate a single screenshot for a specific combination.
    @discardableResult
    func generateScreenshot(
        device: ScreenshotDevice,
        segment: PPOSegment,
        scene: ScreenshotScene
    ) -> URL? {
        let view = screenshotView(device: device, segment: segment, scene: scene)

        let renderer = ImageRenderer(content: view)
        renderer.scale = device.scale
        renderer.proposedSize = ProposedViewSize(device.previewSize)

        guard let image = renderer.uiImage else {
            logger.error("Failed to render screenshot: \(device.rawValue)/\(segment.rawValue)/\(scene.title)")
            return nil
        }

        // Save to Documents/Screenshots
        let dir = screenshotsDirectory(device: device, segment: segment)
        let filename = "\(scene.rawValue)_\(scene.title.replacingOccurrences(of: " ", with: "_")).png"
        let url = dir.appendingPathComponent(filename)

        guard let data = image.pngData() else { return nil }

        do {
            try data.write(to: url)
            logger.info("Exported: \(url.lastPathComponent)")
            return url
        } catch {
            logger.error("Failed to write screenshot: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - View Builders

    @ViewBuilder
    private func screenshotView(
        device: ScreenshotDevice,
        segment: PPOSegment,
        scene: ScreenshotScene
    ) -> some View {
        let size = device.previewSize

        switch scene {
        case .hero:
            heroScreenshot(size: size, segment: segment)
        case .pantryView:
            pantryScreenshot(size: size, segment: segment)
        case .recipeMatch:
            recipeScreenshot(size: size, segment: segment)
        case .impactDash:
            impactScreenshot(size: size, segment: segment)
        case .visionScan:
            visionScreenshot(size: size, segment: segment)
        }
    }

    // MARK: - Hero Screenshot

    private func heroScreenshot(size: CGSize, segment: PPOSegment) -> some View {
        ZStack {
            // Glass shader background
            LinearGradient(
                colors: [Color(hex: 0x0F2818), segment.accentColor.opacity(0.3), Color(hex: 0x0A1F12)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 24) {
                Spacer()

                // App icon
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [segment.accentColor, segment.accentColor.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: segment.accentColor.opacity(0.5), radius: 30)

                // Headline
                Text(segment.heroHeadline)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                // Subheadline
                Text(segment.heroSubheadline)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                // Frosted glass card preview
                mockPantryCard(segment: segment)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .padding(24)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Pantry Screenshot

    private func pantryScreenshot(size: CGSize, segment: PPOSegment) -> some View {
        ZStack {
            Color(hex: 0x0F2818)

            VStack(spacing: 16) {
                // Top caption
                screenshotCaption(
                    text: segment == .athlete
                        ? "Track macros for every item"
                        : "Your smart pantry at a glance",
                    color: segment.accentColor
                )

                // Mock pantry items
                VStack(spacing: 8) {
                    ForEach(self.mockPantryItems.prefix(5), id: \.name) { item in
                        self.mockItemRow(item: item, segment: segment)
                    }
                }
                .padding(16)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Recipe Screenshot

    private func recipeScreenshot(size: CGSize, segment: PPOSegment) -> some View {
        ZStack {
            Color(hex: 0x0F2818)

            VStack(spacing: 16) {
                screenshotCaption(
                    text: segment.featureCallout,
                    color: segment.accentColor
                )

                // Mock recipe cards
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        self.mockRecipeCard(index: i, segment: segment)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Impact Screenshot

    private func impactScreenshot(size: CGSize, segment: PPOSegment) -> some View {
        ZStack {
            Color(hex: 0x0F2818)

            VStack(spacing: 20) {
                screenshotCaption(
                    text: segment == .ecoWarrior
                        ? "Your climate impact, visualized"
                        : "See how much you've saved",
                    color: segment.accentColor
                )

                // Impact stat cards
                HStack(spacing: 12) {
                    impactStatCard(value: "$127", label: "Saved", icon: "dollarsign.circle.fill", color: .green)
                    impactStatCard(value: "45.2kg", label: "CO₂ Avoided", icon: "leaf.fill", color: segment.accentColor)
                    impactStatCard(value: "38", label: "Items Rescued", icon: "heart.fill", color: .pink)
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Vision Screenshot

    private func visionScreenshot(size: CGSize, segment: PPOSegment) -> some View {
        ZStack {
            // Simulated camera background
            LinearGradient(
                colors: [Color(hex: 0x1E293B), Color(hex: 0x0F172A)],
                startPoint: .top, endPoint: .bottom
            )

            VStack(spacing: 16) {
                screenshotCaption(
                    text: "Point. Scan. Know instantly.",
                    color: Color(hex: 0x22D3EE)
                )

                // Mock vision overlay cards
                ZStack {
                    // Reticle brackets
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            PSColors.primaryGreen.opacity(0.4),
                            style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                        )
                        .frame(width: size.width * 0.7, height: size.height * 0.3)

                    VStack(spacing: 8) {
                        Text("🍎 Apple")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                        Text("52 cal • 14g carbs • 7d shelf life")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(12)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Shared Components

    private func screenshotCaption(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.top, 60)
            .padding(.horizontal, 24)
    }

    private func mockPantryCard(segment: PPOSegment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("3 items expiring soon")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }

            ForEach(["Avocado — 1 day", "Milk — 2 days", "Chicken — 3 days"], id: \.self) { item in
                HStack {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text(item)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func mockItemRow(item: MockPantryItem, segment: PPOSegment) -> some View {
        HStack(spacing: 12) {
            Text(item.emoji)
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(item.daysLeft)d left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.daysLeft <= 2 ? .orange : .white.opacity(0.5))
            }

            Spacer()

            // Freshness bar
            Capsule()
                .fill(item.daysLeft <= 2 ? Color.orange : PSColors.primaryGreen)
                .frame(width: 40, height: 4)
        }
        .padding(.vertical, 4)
    }

    private func mockRecipeCard(index: Int, segment: PPOSegment) -> some View {
        let recipes = [
            ("Stir-Fry Rescue", "Use your expiring veggies", "fork.knife"),
            ("Quick Omelette", "3 ingredients from your pantry", "frying.pan"),
            ("Green Smoothie", "Rescue those bananas", "cup.and.saucer.fill")
        ]
        let recipe = recipes[index % recipes.count]

        return HStack(spacing: 12) {
            Image(systemName: recipe.2)
                .font(.system(size: 20))
                .foregroundStyle(segment.accentColor)
                .frame(width: 44, height: 44)
                .background(segment.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.0)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(recipe.1)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text("85%")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(PSColors.primaryGreen)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func impactStatCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - File System

    private func screenshotsDirectory(device: ScreenshotDevice, segment: PPOSegment) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs
            .appendingPathComponent("Screenshots")
            .appendingPathComponent(device.rawValue.replacingOccurrences(of: " ", with: "_"))
            .appendingPathComponent(segment.rawValue.replacingOccurrences(of: " ", with: "_"))

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Mock Data

    private struct MockPantryItem {
        let name: String
        let emoji: String
        let daysLeft: Int
    }

    private var mockPantryItems: [MockPantryItem] {
        [
            MockPantryItem(name: "Avocado", emoji: "🥑", daysLeft: 1),
            MockPantryItem(name: "Chicken Breast", emoji: "🍗", daysLeft: 2),
            MockPantryItem(name: "Whole Milk", emoji: "🥛", daysLeft: 3),
            MockPantryItem(name: "Fresh Spinach", emoji: "🥬", daysLeft: 4),
            MockPantryItem(name: "Greek Yogurt", emoji: "🫙", daysLeft: 5),
            MockPantryItem(name: "Salmon Fillet", emoji: "🐟", daysLeft: 1),
            MockPantryItem(name: "Sourdough Bread", emoji: "🍞", daysLeft: 3),
        ]
    }
}

// MARK: - Preview / Debug View

/// Debug view to preview and trigger screenshot generation.
/// Accessible from Profile → Settings → Developer → Generate Screenshots.
struct ScreenshotGeneratorView: View {
    @State private var generator = AppStoreScreenshotGenerator.shared
    @State private var selectedDevice: ScreenshotDevice = .iPhone17Pro
    @State private var selectedSegment: PPOSegment = .default
    @State private var selectedScene: ScreenshotScene = .hero
    @State private var isExporting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Controls
                VStack(spacing: 12) {
                    Picker("Device", selection: $selectedDevice) {
                        ForEach(ScreenshotDevice.allCases, id: \.self) { device in
                            Text(device.rawValue).tag(device)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Segment", selection: $selectedSegment) {
                        ForEach(PPOSegment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Scene", selection: $selectedScene) {
                        ForEach(ScreenshotScene.allCases, id: \.rawValue) { scene in
                            Text(scene.title).tag(scene)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                // Export All button
                PSButton(
                    title: isExporting ? "Generating..." : "Export All Screenshots",
                    icon: "arrow.down.circle.fill",
                    style: .primary,
                    isLoading: isExporting
                ) {
                    isExporting = true
                    Task {
                        let _ = await generator.generateAllScreenshots()
                        isExporting = false
                    }
                }
                .padding(.horizontal)

                if generator.isGenerating {
                    ProgressView(value: generator.progress)
                        .tint(PSColors.primaryGreen)
                        .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Screenshot Generator")
    }
}
