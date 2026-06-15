import SwiftUI

@available(iOS 16, macOS 13, *)
struct DismissController: ViewModifier {
    let isZoomed: Bool
    let dismissThreshold: CGFloat  // fraction of screen height
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .scaleEffect(dismissScale)
                .offset(y: isZoomed ? 0 : dragOffset)
                .gesture(isZoomed ? nil : dragGesture(in: geometry))
        }
    }

    private var dismissScale: CGFloat {
        guard !isZoomed else { return 1.0 }
        let progress = abs(dragOffset) / 1000
        return max(0.5, 1.0 - progress * 0.5)
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard value.translation.height > 0 else { return }  // only downward
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                isDragging = true
                dragOffset = value.translation.height
            }
            .onEnded { value in
                isDragging = false
                let screenHeight = geometry.size.height
                if value.translation.height > screenHeight * dismissThreshold {
                    withAnimation(.spring()) {
                        onDismiss()
                    }
                } else {
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
            }
    }
}
