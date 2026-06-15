import SwiftUI

@available(iOS 16, macOS 13, *)
struct DismissController: ViewModifier {
    let isZoomed: Bool
    let dismissProgress: CGFloat
    let dragOffset: CGSize

    func body(content: Content) -> some View {
        content
            .scaleEffect(dismissScale)
            .offset(isZoomed ? .zero : dragOffset)
    }

    private var dismissScale: CGFloat {
        guard !isZoomed else { return 1.0 }
        return 1.0 - dismissProgress * 0.5
    }
}
