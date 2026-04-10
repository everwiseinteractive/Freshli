import SwiftUI

// MARK: - View Extensions

extension View {
    
    /// Accessibility header modifier
    func psAccessibleHeader(_ label: String) -> some View {
        self.accessibilityAddTraits(.isHeader)
            .accessibilityLabel(label)
    }
}
