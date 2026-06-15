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
    @State private var viewerDragOffset: CGSize = .zero
    @GestureState private var gestureDragOffset: CGSize = .zero
    @State private var containerSize: CGSize = .zero

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
        GeometryReader { geometry in
            backgroundColor.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .overlay(
                    PagedScroll(
                        currentIndex: $selection,
                        itemCount: itemCount,
                        isZoomed: currentZoomScale > 1.0,
                        externalDragOffset: viewerDragOffset.width,
                        isDragging: viewerDragOffset.width != 0
                    ) { index in
                        ZoomContainer(
                            maxScale: maxScale,
                            doubleTapScale: doubleTapScale,
                            currentScale: zoomScaleBinding(for: index)
                        ) {
                            content(index)
                                .matchedGeometryEffect(
                                    id: TransitionCoordinator.matchedGeometryID(for: index),
                                    in: namespace
                                )
                        }
                    }
                    .modifier(DismissController(
                        isZoomed: currentZoomScale > 1.0,
                        verticalDragOffset: viewerDragOffset.height
                    ))
                    .gesture(unifiedDragGesture)
                )
                .onAppear { containerSize = geometry.size }
                .onChange(of: geometry.size) { newSize in
                    containerSize = newSize
                }
                .onChange(of: selection) { _ in
                    withAnimation(.spring()) {
                        currentZoomScale = 1.0
                    }
                }
        }
    }

    // MARK: - Background Fade on Dismiss

    private var backgroundOpacity: Double {
        guard viewerDragOffset.height > 0 else { return 1.0 }
        let screenHeight = containerSize.height > 0 ? containerSize.height : 800
        let progress = min(1.0, viewerDragOffset.height / screenHeight)
        return 1.0 - progress
    }

    // MARK: - Unified Drag Gesture

    private var unifiedDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($gestureDragOffset) { value, state, _ in
                guard currentZoomScale <= 1.0 else { return }
                state = value.translation
            }
            .onChanged { value in
                guard currentZoomScale <= 1.0 else { return }
                let translation = value.translation
                let isHorizontal = abs(translation.width) > abs(translation.height)
                if isHorizontal {
                    viewerDragOffset = CGSize(width: translation.width, height: 0)
                } else if translation.height > 0 {
                    viewerDragOffset = CGSize(width: 0, height: translation.height)
                }
            }
            .onEnded { value in
                let translation = value.translation
                let isHorizontal = abs(translation.width) > abs(translation.height)
                if isHorizontal {
                    handlePagingEnd(translation: translation)
                } else if translation.height > 0 {
                    handleDismissEnd(translation: translation)
                }
                viewerDragOffset = .zero
            }
    }

    private func handlePagingEnd(translation: CGSize) {
        let screenWidth = containerSize.width
        let threshold = screenWidth * 0.2
        withAnimation(.spring()) {
            if translation.width < -threshold && selection < itemCount - 1 {
                selection += 1
            } else if translation.width > threshold && selection > 0 {
                selection -= 1
            }
        }
    }

    private func handleDismissEnd(translation: CGSize) {
        let screenHeight = containerSize.height
        if translation.height > screenHeight * dismissThreshold {
            withAnimation(.spring()) {
                onDismiss()
            }
        } else {
            withAnimation(.spring()) {
                viewerDragOffset = .zero
            }
        }
    }

    // MARK: - Zoom Scale Binding

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
