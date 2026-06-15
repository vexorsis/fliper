import SwiftUI

@available(iOS 16, macOS 13, *)
struct DismissController: ViewModifier {
    let isZoomed: Bool
    let dismissProgress: CGFloat
    let verticalDragOffset: CGFloat

    private let minDismissScale: CGFloat = 0.5

    func body(content: Content) -> some View {
        content
            .scaleEffect(dismissScale)
            .offset(y: isZoomed ? 0 : verticalDragOffset)
    }

    private var dismissScale: CGFloat {
        guard !isZoomed else { return 1.0 }
        return max(minDismissScale, 1.0 - dismissProgress * minDismissScale)
    }
}
