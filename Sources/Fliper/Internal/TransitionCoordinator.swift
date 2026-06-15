import SwiftUI

@available(iOS 16, macOS 13, *)
struct TransitionCoordinator {
    let namespace: Namespace.ID
    let startIndex: Int

    func matchedGeometryID(for index: Int) -> String {
        "fliper-\(index)"
    }

    func shouldUseHeroTransition(for index: Int, thumbnailVisible: Bool) -> Bool {
        thumbnailVisible
    }
}
