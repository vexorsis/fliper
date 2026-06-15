import SwiftUI

@available(iOS 16, macOS 13, *)
public struct FliperViewer<Content: View>: View {
    @Binding var selection: Int
    @Binding var dismissProgress: CGFloat
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
    @State private var containerSize: CGSize = CGSize(width: 400, height: 800)

    // Zoom-pan state per page
    @State private var zoomAccumulatedOffsets: [Int: CGSize] = [:]

    public init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        dismissProgress: Binding<CGFloat> = .constant(0),
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._selection = selection
        self._dismissProgress = dismissProgress
        self.namespace = namespace
        self.itemCount = itemCount
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self.dismissThreshold = dismissThreshold
        self.backgroundColor = backgroundColor
        self.onDismiss = onDismiss
        self.content = content
    }

    private var isZoomed: Bool {
        currentZoomScale > 1.0
    }

    public var body: some View {
        GeometryReader { geometry in
            PagedScroll(
                currentIndex: $selection,
                itemCount: itemCount,
                isZoomed: isZoomed,
                externalDragOffset: viewerDragOffset.width,
                isDragging: viewerDragOffset.width != 0
            ) { index in
                ZoomContainer(
                    maxScale: maxScale,
                    doubleTapScale: doubleTapScale,
                    currentScale: zoomScaleBinding(for: index),
                    dragTranslation: zoomDragTranslationBinding(for: index),
                    accumulatedOffset: zoomAccumulatedOffsetBinding(for: index)
                ) {
                    content(index)
                        .matchedGeometryEffect(
                            id: TransitionCoordinator.matchedGeometryID(for: index),
                            in: namespace
                        )
                }
            }
            .modifier(DismissController(
                isZoomed: isZoomed,
                dismissProgress: computedDismissProgress,
                dragOffset: viewerDragOffset
            ))
            .contentShape(Rectangle())
            .simultaneousGesture(unifiedDragGesture)
            .ignoresSafeArea()
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

    // MARK: - Dismiss Progress

    private var computedDismissProgress: CGFloat {
        guard viewerDragOffset.height > 0 else { return 0 }
        return min(1.0, viewerDragOffset.height / containerSize.height)
    }

    // MARK: - Background Fade on Dismiss

    private var backgroundOpacity: Double {
        1.0 - Double(computedDismissProgress)
    }

    // MARK: - Unified Drag Gesture

    private var unifiedDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if isZoomed {
                    zoomDragTranslationBinding(for: selection).wrappedValue = value.translation
                } else {
                    let translation = value.translation
                    let isHorizontal = abs(translation.width) > abs(translation.height)
                    if isHorizontal {
                        viewerDragOffset = CGSize(width: translation.width, height: 0)
                        dismissProgress = 0
                    } else if translation.height > 0 {
                        viewerDragOffset = translation
                        dismissProgress = computedDismissProgress
                    }
                }
            }
            .onEnded { value in
                if isZoomed {
                    let accBinding = zoomAccumulatedOffsetBinding(for: selection)
                    let old = accBinding.wrappedValue
                    accBinding.wrappedValue = CGSize(
                        width: old.width + value.translation.width,
                        height: old.height + value.translation.height
                    )
                    zoomDragTranslationBinding(for: selection).wrappedValue = .zero
                } else {
                    let translation = value.translation
                    let isHorizontal = abs(translation.width) > abs(translation.height)
                    if isHorizontal {
                        handlePagingEnd(translation: translation)
                    } else if translation.height > 0 {
                        handleDismissEnd(translation: translation)
                        return
                    }
                    withAnimation(.spring()) {
                        viewerDragOffset = .zero
                        dismissProgress = 0
                    }
                }
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
            viewerDragOffset = .zero
        }
    }

    private func handleDismissEnd(translation: CGSize) {
        if translation.height > containerSize.height * dismissThreshold {
            onDismiss()
        } else {
            withAnimation(.spring()) {
                viewerDragOffset = .zero
                dismissProgress = 0
            }
        }
    }

    // MARK: - Bindings

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

    private func zoomDragTranslationBinding(for index: Int) -> Binding<CGSize> {
        Binding(
            get: { selection == index ? viewerDragOffset : .zero },
            set: { newValue in
                if selection == index {
                    viewerDragOffset = newValue
                }
            }
        )
    }

    private func zoomAccumulatedOffsetBinding(for index: Int) -> Binding<CGSize> {
        Binding(
            get: { zoomAccumulatedOffsets[index] ?? .zero },
            set: { zoomAccumulatedOffsets[index] = $0 }
        )
    }
}
