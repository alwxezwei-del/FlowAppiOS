import SwiftUI

/** Show a short message */
private struct FlowToast: ViewModifier {
    @Binding var message: String?

    @Environment(\.flowColors) private var colors

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(FlowTypography.body2)
                        .foregroundStyle(colors.textMain)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FlowSpacers.x16)
                        .padding(.vertical, FlowSpacers.x12)
                        .background(colors.layer3, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                        .padding(.horizontal, FlowSpacers.x24)
                        .padding(.bottom, FlowSpacers.x32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: message) {
                            try? await Task.sleep(for: .seconds(3))
                            self.message = nil
                        }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: message)
    }
}

extension View {
    func flowToast(message: Binding<String?>) -> some View {
        modifier(FlowToast(message: message))
    }
}
