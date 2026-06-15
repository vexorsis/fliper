import SwiftUI

@available(iOS 16, macOS 13, *)
struct PagedScroll<Content: View>: View {
    @Binding var currentIndex: Int
    let itemCount: Int
    let isZoomed: Bool
    let externalDragOffset: CGFloat
    let isDragging: Bool
    @ViewBuilder let content: (Int) -> Content

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
            let lower = max(0, currentIndex - 1)
            let upper = min(itemCount, currentIndex + 2)

            HStack(spacing: 0) {
                ForEach(lower..<upper, id: \.self) { index in
                    content(index)
                        .frame(width: pageWidth, height: geometry.size.height)
                }
            }
            .offset(x: pageOffset(lower: lower, pageWidth: pageWidth))
            .animation(isDragging ? .none : .spring(), value: currentIndex)
            .animation(isDragging ? .none : .spring(), value: externalDragOffset)
        }
    }

    private func pageOffset(lower: Int, pageWidth: CGFloat) -> CGFloat {
        let baseOffset = -CGFloat(currentIndex - lower) * pageWidth
        let proposed = isZoomed ? 0 : externalDragOffset
        let atStart = currentIndex == 0 && proposed > 0
        let atEnd = currentIndex == itemCount - 1 && proposed < 0
        let elastic = (atStart || atEnd) ? proposed * 0.3 : proposed
        return baseOffset + elastic
    }
}
