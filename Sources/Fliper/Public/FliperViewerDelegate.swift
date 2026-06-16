import UIKit

public protocol FliperViewerDelegate: AnyObject {
    func viewer(_ viewer: FliperViewerController, didScrollToIndex index: Int)
    func viewer(_ viewer: FliperViewerController, didLongPressImageAt index: Int, point: CGPoint)
    func viewerDidDismiss(_ viewer: FliperViewerController)
}

public extension FliperViewerDelegate {
    func viewer(_ viewer: FliperViewerController, didScrollToIndex index: Int) {}
    func viewer(_ viewer: FliperViewerController, didLongPressImageAt index: Int, point: CGPoint) {}
    func viewerDidDismiss(_ viewer: FliperViewerController) {}
}
