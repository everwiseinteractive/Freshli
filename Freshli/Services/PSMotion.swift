import SwiftUI

// MARK: - PSMotion (Pantry Saver Design System - Animation Curves)
/// Consistent animation timing and curves

struct PSMotion {
    
    // MARK: - Animation Curves
    
    /// Freshli signature spring curve - organic, bouncy feel
    static let freshliCurve = Animation.spring(
        response: 0.4,
        dampingFraction: 0.75,
        blendDuration: 0
    )
    
    /// Smooth ease in-out for general transitions
    static let smooth = Animation.easeInOut(duration: 0.3)
    
    /// Quick snappy response for UI feedback
    static let snappy = Animation.spring(
        response: 0.25,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    /// Gentle ease for subtle state changes
    static let gentle = Animation.easeInOut(duration: 0.5)
    
    /// Bouncy celebration animation
    static let celebration = Animation.spring(
        response: 0.6,
        dampingFraction: 0.6,
        blendDuration: 0
    )
    
    // MARK: - Duration Constants
    
    static let durationQuick: TimeInterval = 0.2
    static let durationNormal: TimeInterval = 0.3
    static let durationSlow: TimeInterval = 0.5
    static let durationHero: TimeInterval = 0.8
}

// MARK: - FLMotion (Freshli-Specific Animations)
/// Custom transitions and effects specific to Freshli

struct FLMotion {
    
    // MARK: - Tab Transition
    
    /// Animation for tab switching
    static let tabTransition = Animation.spring(
        response: 0.35,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    enum TabSlideDirection {
        case forward
        case backward
    }
    
    /// Slide + scale transition for organic tab switching
    static func tabSlideTransition(direction: TabSlideDirection) -> AnyTransition {
        let edge: Edge = direction == .forward ? .trailing : .leading
        return AnyTransition.asymmetric(
            insertion: .push(from: edge).combined(with: .scale(scale: 0.95)),
            removal: .push(from: edge.opposite).combined(with: .scale(scale: 1.05).combined(with: .opacity))
        )
    }
    
    // MARK: - List Animations
    
    /// Staggered appearance delay multiplier
    static let staggerDelay: TimeInterval = 0.05
    
    /// Card entrance animation
    static let cardEntrance = Animation.spring(
        response: 0.5,
        dampingFraction: 0.75,
        blendDuration: 0
    )
    
    // MARK: - Celebration Animations
    
    /// Confetti burst animation
    static let confettiBurst = Animation.spring(
        response: 0.6,
        dampingFraction: 0.5,
        blendDuration: 0
    )
    
    /// Achievement unlock animation
    static let achievementUnlock = Animation.spring(
        response: 0.7,
        dampingFraction: 0.6,
        blendDuration: 0
    )
}

// MARK: - Edge Extension

extension Edge {
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

// MARK: - View Animation Helpers

extension View {
    
    /// Apply staggered appearance animation
    func staggeredAppearance(index: Int, delay: TimeInterval = FLMotion.staggerDelay) -> some View {
        self
            .opacity(1.0)
            .offset(y: 0)
            .animation(
                FLMotion.cardEntrance.delay(Double(index) * delay),
                value: index
            )
    }
}
