import SwiftUI

@available(iOS 16, macOS 13, *)
struct FliperTransition<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    @State private var animationProgress: CGFloat = 0.0
    @State private var isVisible: Bool = false

    private let magnifySpring = Spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        Group {
            if isVisible {
                Color.black
                    .opacity(Double(animationProgress))
                    .ignoresSafeArea()
                    .overlay(
                        content()
                            .scaleEffect(1.0 + (1.0 - animationProgress) * -0.05)
                    )
                    .transition(.opacity)
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                isVisible = true
                withAnimation(.spring(magnifySpring)) {
                    animationProgress = 1.0
                }
            } else {
                withAnimation(.spring(magnifySpring)) {
                    animationProgress = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if animationProgress == 0.0 {
                        isVisible = false
                    }
                }
            }
        }
    }
}
