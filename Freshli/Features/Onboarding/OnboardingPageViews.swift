import SwiftUI

// MARK: - Screen 1: Your Kitchen, Optimized
// Visualizes a clean, organized fridge using custom SwiftUI shapes and iconography.

struct KitchenOptimizedPage: View {
    @State private var appeared = false
    @State private var fridgeOpen = false
    @State private var glowPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Fridge illustration
            ZStack {
                // Glow ring behind fridge
                Circle()
                    .fill(PSColors.primaryGreen.opacity(0.08))
                    .frame(width: PSLayout.scaled(280), height: PSLayout.scaled(280))
                    .scaleEffect(glowPulse ? 1.06 : 1.0)

                // Fridge body
                fridgeIllustration
                    .scaleEffect(appeared ? 1 : 0.7)
                    .opacity(appeared ? 1 : 0)

                // Floating food items around the fridge
                floatingFoodItems
            }
            .frame(height: PSLayout.screenHeight * 0.34)

            // Text content
            VStack(spacing: PSSpacing.lg) {
                Text(String(localized: "Your Kitchen, Optimized"))
                    .font(.system(size: PSLayout.scaledFont(32), weight: .black, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(String(localized: "See everything in your fridge at a glance. No more forgotten leftovers or surprise expiry dates."))
                    .font(.system(size: PSLayout.scaledFont(17), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, PSSpacing.xl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                fridgeOpen = true
                return
            }
            withAnimation(PSMotion.springBouncy.delay(0.2)) {
                appeared = true
            }
            withAnimation(PSMotion.springGentle.delay(0.6)) {
                fridgeOpen = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // MARK: - Fridge Illustration

    private var fridgeIllustration: some View {
        ZStack {
            // Fridge body
            RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: PSLayout.scaled(160), height: PSLayout.scaled(220))
                .overlay(
                    RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: PSColors.primaryGreen.opacity(0.15), radius: 30, y: 10)

            // Fridge shelves with food
            VStack(spacing: PSLayout.scaled(12)) {
                fridgeShelf(items: ["🥬", "🍎", "🥛"])
                fridgeShelf(items: ["🧀", "🍊", "🥕"])
                fridgeShelf(items: ["🍗", "🫐", "🥚"])
            }
            .opacity(fridgeOpen ? 1 : 0)
            .scaleEffect(fridgeOpen ? 1 : 0.8)

            // Freshli badge overlay
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(PSColors.primaryGreen)
                            .frame(width: PSLayout.scaled(36), height: PSLayout.scaled(36))
                            .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 8, y: 2)
                        Image(systemName: "checkmark")
                            .font(.system(size: PSLayout.scaledFont(16), weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: PSLayout.scaled(8), y: PSLayout.scaled(-8))
                    .scaleEffect(fridgeOpen ? 1 : 0)
                }
                Spacer()
            }
            .frame(width: PSLayout.scaled(160), height: PSLayout.scaled(220))
        }
    }

    private func fridgeShelf(items: [String]) -> some View {
        HStack(spacing: PSLayout.scaled(8)) {
            ForEach(items, id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: PSLayout.scaledFont(28)))
                    .frame(width: PSLayout.scaled(38), height: PSLayout.scaled(38))
                    .background(.white.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusSm, style: .continuous))
            }
        }
    }

    // MARK: - Floating Food Items

    private var floatingFoodItems: some View {
        let items: [(emoji: String, x: CGFloat, y: CGFloat, delay: Double)] = [
            ("🍃", -110, -90, 0.3),
            ("✨", 100, -70, 0.5),
            ("🌿", -90, 80, 0.4),
            ("💚", 110, 90, 0.6),
        ]

        return ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            Text(item.emoji)
                .font(.system(size: PSLayout.scaledFont(20)))
                .offset(x: PSLayout.scaled(item.x), y: PSLayout.scaled(item.y))
                .opacity(appeared ? 0.7 : 0)
                .scaleEffect(appeared ? 1 : 0.3)
                .animation(
                    reduceMotion ? .none : PSMotion.springBouncy.delay(item.delay),
                    value: appeared
                )
        }
    }
}

// MARK: - Screen 2: Save Money, Save the Planet
// Interactive slider showing $ saved ↔ CO2 avoided correlation.

struct SavingsImpactPage: View {
    @State private var appeared = false
    @State private var savedMeals: Double = 5
    @State private var sliderInteracted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Illustration height scales with screen height so it never overflows on compact devices (e.g. iPhone SE 667 pt).
    private var illustrationHeight: CGFloat { PSLayout.screenHeight * 0.28 }

    // $3.50 avg per rescued meal, 2.5 kg CO2 per meal
    private var dollarsSaved: Double { savedMeals * 3.5 }
    private var co2Avoided: Double { savedMeals * 2.5 }
    private var treesEquivalent: Double { co2Avoided / 21.0 } // 21kg CO2 per tree per year

    var body: some View {
        VStack(spacing: PSSpacing.xxl) {
            Spacer()

            // Earth / Savings illustration
            ZStack {
                // Animated rings
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .strokeBorder(
                            PSColors.primaryGreen.opacity(0.08 + Double(ring) * 0.04),
                            lineWidth: 1.5
                        )
                        .frame(
                            width: PSLayout.scaled(CGFloat(180 + ring * 50)),
                            height: PSLayout.scaled(CGFloat(180 + ring * 50))
                        )
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            reduceMotion ? .none : PSMotion.springGentle.delay(Double(ring) * 0.15),
                            value: appeared
                        )
                }

                // Center globe icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [PSColors.primaryGreen, PSColors.accentTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: PSLayout.scaled(120), height: PSLayout.scaled(120))
                        .shadow(color: PSColors.primaryGreen.opacity(0.3), radius: 24, y: 8)

                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: PSLayout.scaledFont(52)))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)

                // Floating impact labels — y is proportional to illustrationHeight so they
                // stay within bounds on all devices (iPhone SE through 17 Pro Max).
                impactLabel(
                    value: String(format: "$%.0f", dollarsSaved),
                    label: String(localized: "saved"),
                    color: PSColors.primaryGreen,
                    x: -95, y: -illustrationHeight * 0.22
                )
                impactLabel(
                    value: String(format: "%.1fkg", co2Avoided),
                    label: String(localized: "CO₂ avoided"),
                    color: PSColors.accentTeal,
                    x: 95, y: -illustrationHeight * 0.15
                )
                impactLabel(
                    value: String(format: "%.1f", treesEquivalent),
                    label: String(localized: "trees worth"),
                    color: PSColors.secondaryAmber,
                    x: 0, y: illustrationHeight * 0.36
                )
            }
            .frame(height: illustrationHeight)

            // Text content
            VStack(spacing: PSSpacing.lg) {
                Text(String(localized: "Save Money, Save the Planet"))
                    .font(.system(size: PSLayout.scaledFont(32), weight: .black, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(String(localized: "Every meal you rescue keeps money in your pocket and carbon out of the atmosphere."))
                    .font(.system(size: PSLayout.scaledFont(17), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, PSSpacing.xl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
            }

            // Interactive slider
            VStack(spacing: PSSpacing.md) {
                HStack {
                    Text(String(localized: "Meals rescued per week"))
                        .font(.system(size: PSLayout.scaledFont(14), weight: .semibold))
                        .foregroundStyle(PSColors.textSecondary)
                    Spacer()
                    Text("\(Int(savedMeals))")
                        .font(.system(size: PSLayout.scaledFont(20), weight: .bold, design: .rounded))
                        .foregroundStyle(PSColors.primaryGreen)
                        .contentTransition(.numericText(value: savedMeals))
                }

                Slider(value: $savedMeals, in: 1...20, step: 1) {
                    Text(String(localized: "Meals rescued"))
                } onEditingChanged: { editing in
                    if editing && !sliderInteracted {
                        PSHaptics.shared.lightTap()
                        sliderInteracted = true
                    }
                    if !editing {
                        PSHaptics.shared.tick()
                    }
                }
                .tint(PSColors.primaryGreen)

                HStack {
                    Text(String(localized: "1"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                    Spacer()
                    Text(String(localized: "20"))
                        .font(.system(size: PSLayout.scaledFont(12), weight: .medium))
                        .foregroundStyle(PSColors.textTertiary)
                }
            }
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .padding(.vertical, PSSpacing.lg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, PSLayout.formHorizontalPadding)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            Spacer()
        }
        .animation(PSMotion.springDefault, value: savedMeals)
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(PSMotion.springBouncy.delay(0.2)) {
                appeared = true
            }
        }
    }

    private func impactLabel(value: String, label: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: PSLayout.scaledFont(10), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
        }
        .padding(.horizontal, PSSpacing.md)
        .padding(.vertical, PSSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .offset(x: PSLayout.scaled(x), y: y)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.5)
    }
}

// MARK: - Screen 3: Join the Freshli Community
// Blurred map of nearby users sharing food.

struct CommunityMapPage: View {
    @State private var appeared = false
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: PSSpacing.xxxl) {
            Spacer()

            // Map illustration
            ZStack {
                // Map grid background
                mapGridView

                // User dots on the map
                communityDots

                // Center "you" indicator
                ZStack {
                    Circle()
                        .fill(PSColors.primaryGreen.opacity(0.15))
                        .frame(width: PSLayout.scaled(80), height: PSLayout.scaled(80))
                        .scaleEffect(pulsing ? 1.2 : 1.0)
                        .opacity(pulsing ? 0.3 : 0.6)

                    Circle()
                        .fill(PSColors.primaryGreen)
                        .frame(width: PSLayout.scaled(24), height: PSLayout.scaled(24))
                        .overlay(
                            Circle().strokeBorder(.white, lineWidth: 3)
                        )
                        .shadow(color: PSColors.primaryGreen.opacity(0.4), radius: 8, y: 2)
                }
                .scaleEffect(appeared ? 1 : 0)

                // "You" label
                Text(String(localized: "You"))
                    .font(.system(size: PSLayout.scaledFont(11), weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, PSSpacing.sm)
                    .padding(.vertical, PSSpacing.xxs)
                    .background(PSColors.primaryGreen)
                    .clipShape(Capsule())
                    .offset(y: PSLayout.scaled(28))
                    .opacity(appeared ? 1 : 0)
            }
            .frame(width: PSLayout.scaled(300), height: PSLayout.screenHeight * 0.30)
            .clipShape(RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PSSpacing.radiusXxl, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, y: 8)

            // Text content
            VStack(spacing: PSSpacing.lg) {
                Text(String(localized: "Join the Freshli Community"))
                    .font(.system(size: PSLayout.scaledFont(32), weight: .black, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(PSColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(String(localized: "Neighbors near you are already sharing food and reducing waste. See what's available nearby."))
                    .font(.system(size: PSLayout.scaledFont(17), weight: .medium))
                    .foregroundStyle(PSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, PSSpacing.xl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)

                // Community stats pill
                HStack(spacing: PSSpacing.xl) {
                    statPill(value: "2.4k", label: String(localized: "neighbors"))
                    statPill(value: "850+", label: String(localized: "meals shared"))
                    statPill(value: "12", label: String(localized: "near you"))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                pulsing = false
                return
            }
            withAnimation(PSMotion.springBouncy.delay(0.2)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }

    // MARK: - Map Grid

    private var mapGridView: some View {
        Canvas { context, size in
            // Subtle grid lines
            let gridSpacing: CGFloat = 30
            let lineColor = PSColors.infoBlue.opacity(0.08)

            for x in stride(from: CGFloat(0), through: size.width, by: gridSpacing) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for y in stride(from: CGFloat(0), through: size.height, by: gridSpacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }

            // Organic "street" curves
            let streets: [(start: CGPoint, control: CGPoint, end: CGPoint)] = [
                (CGPoint(x: 0, y: size.height * 0.3),
                 CGPoint(x: size.width * 0.5, y: size.height * 0.25),
                 CGPoint(x: size.width, y: size.height * 0.4)),
                (CGPoint(x: size.width * 0.2, y: 0),
                 CGPoint(x: size.width * 0.35, y: size.height * 0.5),
                 CGPoint(x: size.width * 0.15, y: size.height)),
                (CGPoint(x: size.width * 0.6, y: 0),
                 CGPoint(x: size.width * 0.7, y: size.height * 0.6),
                 CGPoint(x: size.width * 0.8, y: size.height)),
            ]
            for street in streets {
                var path = Path()
                path.move(to: street.start)
                path.addQuadCurve(to: street.end, control: street.control)
                context.stroke(path, with: .color(PSColors.infoBlue.opacity(0.12)), lineWidth: 2.5)
            }
        }
        .background(PSColors.infoBlue.opacity(0.03))
        .blur(radius: 1)
    }

    // MARK: - Community Dots

    private var communityDots: some View {
        let users: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double, sharing: Bool)] = [
            (-80, -70, 14, 0.3, true),
            (90, -50, 12, 0.4, false),
            (-60, 50, 16, 0.35, true),
            (70, 70, 13, 0.45, true),
            (-100, 10, 11, 0.5, false),
            (100, -10, 14, 0.55, true),
            (30, -90, 12, 0.6, false),
            (-40, 90, 13, 0.65, true),
        ]

        return ForEach(Array(users.enumerated()), id: \.offset) { index, user in
            ZStack {
                if user.sharing {
                    Circle()
                        .fill(PSColors.primaryGreen.opacity(0.15))
                        .frame(width: PSLayout.scaled(user.size * 2.5),
                               height: PSLayout.scaled(user.size * 2.5))
                }
                Circle()
                    .fill(user.sharing ? PSColors.primaryGreen.opacity(0.7) : PSColors.infoBlue.opacity(0.5))
                    .frame(width: PSLayout.scaled(user.size),
                           height: PSLayout.scaled(user.size))
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5)
                    )
            }
            .offset(x: PSLayout.scaled(user.x), y: PSLayout.scaled(user.y))
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0)
            .animation(
                reduceMotion ? .none : PSMotion.springBouncy.delay(user.delay),
                value: appeared
            )
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: PSLayout.scaledFont(16), weight: .bold, design: .rounded))
                .foregroundStyle(PSColors.primaryGreen)
            Text(label)
                .font(.system(size: PSLayout.scaledFont(11), weight: .medium))
                .foregroundStyle(PSColors.textTertiary)
        }
    }
}

// MARK: - Previews

#Preview("Kitchen") {
    KitchenOptimizedPage()
}

#Preview("Savings") {
    SavingsImpactPage()
}

#Preview("Community") {
    CommunityMapPage()
}
