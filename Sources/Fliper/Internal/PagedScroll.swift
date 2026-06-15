import SwiftUI

@available(iOS 16, macOS 13, *)
struct PagedScroll<Content: View>: View {
    @Binding var currentIndex: Int
    let itemCount: Int
    let isZoomed: Bool
    @ViewBuilder let content: (Int) -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let swipeThreshold: CGFloat = 0.2  // 20% of page width

    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        isZoomed: Bool,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.isZoomed = isZoomed
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = geometry.size.width

            HStack(spacing: 0) {
                ForEach(0..<itemCount, id: \.self) { index in
                    content(index)
                        .frame(width: pageWidth, height: geometry.size.height)
                }
            }
            .offset(x: pageOffset(in: geometry))
            .gesture(dragGesture(in: geometry))
            .animation(isDragging ? .none : .spring(), value: currentIndex)
            .animation(isDragging ? .none : .spring(), value: dragOffset)
        }
    }

    private func pageOffset(in geometry: GeometryProxy) -> CGFloat {
        let pageWidth = geometry.size.width
        let baseOffset = -CGFloat(currentIndex) * pageWidth
        let elasticDrag = elasticDragOffset(in: geometry)
        return baseOffset + elasticDrag
    }

    private func elasticDragOffset(in geometry: GeometryProxy) -> CGFloat {
        let proposed = dragOffset
        let atStart = currentIndex == 0 && proposed > 0
        let atEnd = currentIndex == itemCount - 1 && proposed < 0
        if atStart || atEnd {
            return proposed * 0.3
        }
        return proposed
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isZoomed else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !isZoomed else { return }
                isDragging = false
                let pageWidth = geometry.size.width
                let threshold = pageWidth * swipeThreshold
                withAnimation(.spring()) {
                    if value.translation.width < -threshold && currentIndex < itemCount - 1 {
                        currentIndex += 1
                    } else if value.translation.width > threshold && currentIndex > 0 {
                        currentIndex -= 1
                    }
                    dragOffset = 0
                }
            }
    }
}
