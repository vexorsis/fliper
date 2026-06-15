import SwiftUI

@available(iOS 16, macOS 13, *)
public struct FliperTransition<Content: View>: View {
    @Binding var isPresented: Bool
    @Binding var dismissProgress: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var animationProgress: CGFloat = 0.0
    @State private var isVisible: Bool = false

    public init(
        isPresented: Binding<Bool>,
        dismissProgress: Binding<CGFloat> = .constant(0),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self._dismissProgress = dismissProgress
        self.content = content
    }

    public var body: some View {
        ZStack {
            if isVisible {
                let backgroundOpacity = Double(animationProgress) * (1.0 - Double(dismissProgress))
                let contentScale = 1.0 + (1.0 - animationProgress) * -0.05

                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                    .overlay(
                        content()
                            .scaleEffect(contentScale)
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            if isPresented {
                isVisible = true
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    animationProgress = 1.0
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                isVisible = true
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    animationProgress = 1.0
                }
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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
