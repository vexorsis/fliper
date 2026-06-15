import SwiftUI

@available(iOS 16, macOS 13, *)
struct ZoomContainer<Content: View>: View {
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    @Binding var currentScale: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var magnificationScale: CGFloat = 1.0

    init(
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        currentScale: Binding<CGFloat>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self._currentScale = currentScale
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            content()
                .scaleEffect(effectiveScale)
                .offset(effectiveOffset(in: geometry))
                .gesture(magnificationGesture)
                .gesture(dragGesture(in: geometry))
                .gesture(doubleTapGesture)
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
            width: offset.width + dragOffset.width,
            height: offset.height + dragOffset.height
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
                        offset = .zero
                    }
                } else {
                    scale = newScale
                }
            }
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if scale > 1.0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    offset = boundedOffset(
                        CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        ),
                        in: geometry
                    )
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { _ in
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                    } else {
                        scale = doubleTapScale
                    }
                }
            }
    }
}
