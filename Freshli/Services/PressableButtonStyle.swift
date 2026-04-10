import SwiftUI

// MARK: - PressableButtonStyle
/// Button style with scale down press animation

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(PSMotion.snappy, value: configuration.isPressed)
    }
}

#Preview {
    Button("Press Me") {
        print("Pressed")
    }
    .buttonStyle(PressableButtonStyle())
    .padding()
}
