import SwiftUI

@available(iOS 16, macOS 13, *)
struct PagedScroll<Content: View>: View {
    @Binding var currentIndex: Int
    let itemCount: Int
    let isZoomed: Bool
    let externalDragOffset: CGFloat
    let isDragging: Bool
    @ViewBuilder let content: (Int) -> Content

    private let swipeThreshold: CGFloat = 0.2  // 20% of page width

    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        isZoomed: Bool,
        externalDragOffset: CGFloat = 0,
        isDragging: Bool = false,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.isZoomed = isZoomed
        self.externalDragOffset = externalDragOffset
        self.isDragging = isDragging
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
            .animation(isDragging ? .none : .spring(), value: currentIndex)
            .animation(isDragging ? .none : .spring(), value: externalDragOffset)
        }
    }

    private func pageOffset(in geometry: GeometryProxy) -> CGFloat {
        let pageWidth = geometry.size.width
        let baseOffset = -CGFloat(currentIndex) * pageWidth
        let elasticDrag = elasticDragOffset(in: geometry)
        return baseOffset + elasticDrag
    }

    private func elasticDragOffset(in geometry: GeometryProxy) -> CGFloat {
        let proposed = externalDragOffset
        let atStart = currentIndex == 0 && proposed > 0
        let atEnd = currentIndex == itemCount - 1 && proposed < 0
        if atStart || atEnd {
            return proposed * 0.3
        }
        return proposed
    }
}
