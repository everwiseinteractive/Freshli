import SwiftUI

// MARK: - Celebration System Previews
// Preview all 10 celebration types for visual verification against Figma

#Preview("First Item Added") {
    StandardCelebrationView(
        type: .firstItemAdded,
        onDismiss: {}
    )
}

#Preview("First Food Saved") {
    StandardCelebrationView(
        type: .firstFoodSaved,
        onDismiss: {}
    )
}

#Preview("Recipe Match (Toast)") {
    ZStack {
        Color(hex: 0xF3F3F5).ignoresSafeArea()
        ToastCelebrationView(
            type: .recipeMatchSuccess(recipeName: "Vegetable Stir Fry"),
            onDismiss: {}
        )
    }
}

#Preview("Share Completed") {
    StandardCelebrationView(
        type: .shareCompleted(itemName: "Organic Milk"),
        onDismiss: {}
    )
}

#Preview("Donation Completed") {
    StandardCelebrationView(
        type: .donationCompleted(itemName: "Canned Tomatoes"),
        onDismiss: {}
    )
}

#Preview("3-Day Streak") {
    StreakCelebrationView(
        streakCount: 3,
        onDismiss: {}
    )
}

#Preview("7-Day Streak (Hero)") {
    StreakCelebrationView(
        streakCount: 7,
        onDismiss: {}
    )
}

#Preview("Impact Milestone") {
    MilestoneCelebrationView(
        type: .impactMilestone(milestone: "Waste Warrior", stat: "50 items saved"),
        onDismiss: {}
    )
}

#Preview("Achievement Unlock") {
    MilestoneCelebrationView(
        type: .achievementUnlock(title: "First Saver", icon: "leaf.fill"),
        onDismiss: {}
    )
}

#Preview("Community Impact") {
    MilestoneCelebrationView(
        type: .communityImpact(totalItems: 25, neighbors: 8),
        onDismiss: {}
    )
}

#Preview("Weekly Recap") {
    WeeklyRecapView(
        saved: 12,
        shared: 5,
        co2: 42.5,
        money: 73,
        onDismiss: {}
    )
}

// MARK: - Component Previews

#Preview("Particle Layer") {
    ZStack {
        Color(hex: 0x22C55E).ignoresSafeArea()
        CelebrationParticleLayer(
            count: 12,
            trigger: true,
            accentColor: Color(hex: 0x86EFAC)
        )
    }
}

#Preview("Celebration Badge") {
    ZStack {
        Color(hex: 0x059669).ignoresSafeArea()
        CelebrationBadge(
            icon: "star.fill",
            color: Color(hex: 0x10B981),
            animate: true
        )
    }
}

#Preview("Count Up Text") {
    ZStack {
        Color(hex: 0x1E293B).ignoresSafeArea()
        VStack(spacing: 20) {
            CelebrationCountUpText.integer(42, color: .white)
            CelebrationCountUpText.currency(73.5, color: Color(hex: 0xFBBF24))
            CelebrationCountUpText.weight(12.5, color: Color(hex: 0x4ADE80))
        }
    }
}
