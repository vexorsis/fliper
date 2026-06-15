import SwiftUI

@available(iOS 16, macOS 13, *)
struct ZoomContainer<Content: View>: View {
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    @Binding var currentScale: CGFloat
    @Binding var dragTranslation: CGSize
    @Binding var accumulatedOffset: CGSize
    @ViewBuilder let content: () -> Content

    @State private var scale: CGFloat = 1.0
    @GestureState private var magnificationScale: CGFloat = 1.0

    init(
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        currentScale: Binding<CGFloat>,
        dragTranslation: Binding<CGSize>,
        accumulatedOffset: Binding<CGSize>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self._currentScale = currentScale
        self._dragTranslation = dragTranslation
        self._accumulatedOffset = accumulatedOffset
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            content()
                .scaleEffect(effectiveScale)
                .offset(effectiveOffset(in: geometry))
                .gesture(magnificationGesture)
                .gesture(doubleTapGesture)
                .onChange(of: currentScale) { newScale in
                    if newScale <= 1.0 {
                        accumulatedOffset = .zero
                    }
                }
                .onChange(of: effectiveScale) { newScale in
                    currentScale = newScale
                }
        }
        .clipped()
    }

    private var effectiveScale: CGFloat {
        let s = scale * magnificationScale
        return min(s, maxScale)
    }

    private func effectiveOffset(in geometry: GeometryProxy) -> CGSize {
        let totalOffset = CGSize(
            width: accumulatedOffset.width + dragTranslation.width,
            height: accumulatedOffset.height + dragTranslation.height
        )
        if effectiveScale <= 1.0 {
            return .zero
        }
        return boundedOffset(totalOffset, in: geometry)
    }

    private func boundedOffset(_ offset: CGSize, in geometry: GeometryProxy) -> CGSize {
        let scaledWidth = geometry.size.width * effectiveScale
        let scaledHeight = geometry.size.height * effectiveScale
        let extraWidth = max(0, (scaledWidth - geometry.size.width) / 2)
        let extraHeight = max(0, (scaledHeight - geometry.size.height) / 2)
        return CGSize(
            width: min(extraWidth, max(-extraWidth, offset.width)),
            height: min(extraHeight, max(-extraHeight, offset.height))
        )
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($magnificationScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = min(scale * value, maxScale)
                if newScale < 1.0 {
                    withAnimation(.spring()) {
                        scale = 1.0
                        accumulatedOffset = .zero
                    }
                } else {
                    scale = newScale
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { _ in
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        accumulatedOffset = .zero
                    } else {
                        scale = doubleTapScale
                    }
                }
            }
    }
}
