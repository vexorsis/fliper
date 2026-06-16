import UIKit

public protocol FliperViewerDataSource: AnyObject {
    func numberOfItems(in viewer: FliperViewerController) -> Int
    func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage
}
