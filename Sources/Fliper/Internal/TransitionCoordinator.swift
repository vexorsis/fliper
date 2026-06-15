import SwiftUI

@available(iOS 16, macOS 13, *)
enum TransitionCoordinator {
    static func matchedGeometryID(for index: Int) -> String {
        "fliper-\(index)"
    }

    static func shouldUseHeroTransition(thumbnailVisible: Bool) -> Bool {
        thumbnailVisible
    }
}
