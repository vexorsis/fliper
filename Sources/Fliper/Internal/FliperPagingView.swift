import UIKit

protocol FliperPagingViewDelegate: AnyObject {
    func pagingView(_ pagingView: FliperPagingView, didScrollToIndex index: Int)
}

final class FliperPagingView: UICollectionView {
    weak var pagingDelegate: FliperPagingViewDelegate?
    var currentIndex: Int = 0
    private var bodyIsInCenter = true
    private var isDealingScreenRotation = false

    init(frame: CGRect) {
        let layout = FliperPagingLayout()
        super.init(frame: frame, collectionViewLayout: layout)
        commonInit()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func commonInit() {
        isPagingEnabled = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear
        alwaysBounceHorizontal = false
        alwaysBounceVertical = false
        delegate = self
    }

    func updateContentInset() {
        guard let layout = collectionViewLayout as? FliperPagingLayout else { return }
        contentInset = UIEdgeInsets(
            top: 0,
            left: layout.interPageSpacing / 2.0,
            bottom: 0,
            right: layout.interPageSpacing / 2.0
        )
    }

    func scrollToPage(_ index: Int, animated: Bool = false) {
        let offsetX = CGFloat(index) * bounds.width + contentInset.left
        setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
    }
}

extension FliperPagingView: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let indexF = (scrollView.contentOffset.x - contentInset.left) / scrollView.bounds.width
        let index = Int(round(indexF))

        let isInCenter = abs(indexF - round(indexF)) < 0.001

        if bodyIsInCenter != isInCenter {
            bodyIsInCenter = isInCenter
        }

        guard index >= 0,
              let itemCount = dataSource?.collectionView(self, numberOfItemsInSection: 0),
              index < itemCount,
              !isDealingScreenRotation,
              bodyIsInCenter else { return }

        if currentIndex != index {
            currentIndex = index
            pagingDelegate?.pagingView(self, didScrollToIndex: index)
        }
    }
}
