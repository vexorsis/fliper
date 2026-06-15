import SwiftUI

@available(iOS 16, macOS 13, *)
public struct FliperViewer<Content: View>: View {
    @Binding var selection: Int
    let namespace: Namespace.ID
    let itemCount: Int
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    let dismissThreshold: CGFloat
    let backgroundColor: Color
    let onDismiss: () -> Void
    let content: (Int) -> Content

    @State private var currentZoomScale: CGFloat = 1.0
    @State private var startIndex: Int = 0

    public init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._selection = selection
        self.namespace = namespace
        self.itemCount = itemCount
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self.dismissThreshold = dismissThreshold
        self.backgroundColor = backgroundColor
        self.onDismiss = onDismiss
        self.content = content
    }

    public var body: some View {
        backgroundColor
            .ignoresSafeArea()
            .overlay(
                PagedScroll(
                    currentIndex: $selection,
                    itemCount: itemCount,
                    isZoomed: currentZoomScale > 1.0
                ) { index in
                    ZoomContainer(
                        maxScale: maxScale,
                        doubleTapScale: doubleTapScale,
                        currentScale: zoomScaleBinding(for: index)
                    ) {
                        content(index)
                            .matchedGeometryEffect(
                                id: "fliper-\(index)",
                                in: namespace
                            )
                    }
                }
                .modifier(DismissController(
                    isZoomed: currentZoomScale > 1.0,
                    dismissThreshold: dismissThreshold,
                    onDismiss: onDismiss
                ))
            )
            .onAppear {
                startIndex = selection
            }
    }

    private func zoomScaleBinding(for index: Int) -> Binding<CGFloat> {
        Binding(
            get: { selection == index ? currentZoomScale : 1.0 },
            set: { newValue in
                if selection == index {
                    currentZoomScale = newValue
                }
            }
        )
    }
}
