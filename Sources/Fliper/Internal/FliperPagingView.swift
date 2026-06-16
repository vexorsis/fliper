import UIKit

protocol FliperPagingViewDelegate: AnyObject {
    func pagingView(_ pagingView: FliperPagingView, didScrollToIndex index: Int)
}

final class FliperPagingView: UICollectionView {
    weak var pagingDelegate: FliperPagingViewDelegate?
    var currentIndex: Int = 0

    init(frame: CGRect) {
        super.init(frame: frame, collectionViewLayout: FliperPagingLayout())
        commonInit()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func commonInit() {
        isPagingEnabled = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
    }
}
