import SwiftUI

@available(iOS 16, macOS 13, *)
struct DismissController: ViewModifier {
    let isZoomed: Bool
    let verticalDragOffset: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(dismissScale)
            .offset(y: isZoomed ? 0 : verticalDragOffset)
    }

    private var dismissScale: CGFloat {
        guard !isZoomed else { return 1.0 }
        let progress = abs(verticalDragOffset) / 1000
        return max(0.5, 1.0 - progress * 0.5)
    }
}
