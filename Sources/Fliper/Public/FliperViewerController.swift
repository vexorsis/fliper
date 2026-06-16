import UIKit

public class FliperViewerController: UIViewController {
    public weak var delegate: FliperViewerDelegate?

    public var maxZoomScale: CGFloat = 5.0
    public var doubleTapZoomScale: CGFloat = 2.0
    public var dismissThreshold: CGFloat = 0.25 {
        didSet { dismissGesture?.dismissThreshold = dismissThreshold }
    }
    public var interPageSpacing: CGFloat = 20.0 {
        didSet {
            if let layout = pagingView?.collectionViewLayout as? FliperPagingLayout {
                layout.interPageSpacing = interPageSpacing
                pagingView?.updateContentInset()
            }
        }
    }
    public var backgroundColor: UIColor = .black {
        didSet { view.backgroundColor = backgroundColor }
    }
    public var currentIndex: Int = 0

    private let dataSource: FliperViewerDataSource
    private var pagingView: FliperPagingView!
    private var dismissGesture: FliperDismissGesture!
    private var isZoomed = false
    private var hasAppeared = false

    private static let cellReuseIdentifier = "FliperImageCell"

    public init(dataSource: FliperViewerDataSource, currentIndex: Int = 0) {
        self.dataSource = dataSource
        self.currentIndex = currentIndex
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = backgroundColor
        setupPagingView()
        setupDismissGesture()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let newBounds = view.bounds
        if !pagingView.frame.equalTo(newBounds) {
            pagingView.frame = newBounds
            if let layout = pagingView.collectionViewLayout as? FliperPagingLayout {
                layout.invalidateLayout()
            }
            pagingView.updateContentInset()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasAppeared {
            hasAppeared = true
            pagingView.scrollToPage(currentIndex)
            updateDismissGestureTarget()
        }
    }

    public func reloadData() {
        pagingView.reloadData()
    }

    public func dismissViewer() {
        dismiss(animated: true) { [weak self] in
            guard let self, self.view.window == nil else { return }
            self.delegate?.viewerDidDismiss(self)
        }
    }

    private func setupPagingView() {
        pagingView = FliperPagingView(frame: view.bounds)
        pagingView.register(FliperImageCell.self, forCellWithReuseIdentifier: Self.cellReuseIdentifier)
        pagingView.dataSource = self
        pagingView.pagingDelegate = self
        pagingView.currentIndex = currentIndex
        if let layout = pagingView.collectionViewLayout as? FliperPagingLayout {
            layout.interPageSpacing = interPageSpacing
        }
        view.addSubview(pagingView)
    }

    private func setupDismissGesture() {
        dismissGesture = FliperDismissGesture()
        dismissGesture.dismissDelegate = self
        dismissGesture.dismissThreshold = dismissThreshold
        view.addGestureRecognizer(dismissGesture)
    }

    private func updateDismissGestureTarget() {
        guard let cell = currentVisibleCell() else { return }
        dismissGesture.setTargetScrollView(cell.scrollView)
    }

    private func currentVisibleCell() -> FliperImageCell? {
        pagingView.visibleCells
            .compactMap { $0 as? FliperImageCell }
            .first { pagingView.indexPath(for: $0)?.item == currentIndex }
    }

    private func resetZoomOnCell(at index: Int) {
        guard let cell = pagingView.cellForItem(at: IndexPath(item: index, section: 0)) as? FliperImageCell else { return }
        cell.resetZoom()
    }
}

// MARK: - UICollectionViewDataSource

extension FliperViewerController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.numberOfItems(in: self)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellReuseIdentifier, for: indexPath) as! FliperImageCell
        let image = dataSource.viewer(self, imageAt: indexPath.item)
        cell.configure(image: image, maxZoomScale: maxZoomScale, doubleTapZoomScale: doubleTapZoomScale)
        cell.cellDelegate = self
        return cell
    }
}

// MARK: - FliperPagingViewDelegate

extension FliperViewerController: FliperPagingViewDelegate {
    func pagingView(_ pagingView: FliperPagingView, didScrollToIndex index: Int) {
        let previousIndex = currentIndex
        currentIndex = index
        if previousIndex != index {
            resetZoomOnCell(at: previousIndex)
        }
        updateDismissGestureTarget()
        delegate?.viewer(self, didScrollToIndex: index)
    }
}

// MARK: - FliperImageCellDelegate

extension FliperViewerController: FliperImageCellDelegate {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool) {
        self.isZoomed = isZoomed
        pagingView.isScrollEnabled = !isZoomed
        dismissGesture.isEnabled = !isZoomed
    }

    func cellDidLongPress(_ cell: FliperImageCell, point: CGPoint) {
        guard let indexPath = pagingView.indexPath(for: cell) else { return }
        delegate?.viewer(self, didLongPressImageAt: indexPath.item, point: point)
    }
}

// MARK: - FliperDismissGestureDelegate

extension FliperViewerController: FliperDismissGestureDelegate {
    func dismissGestureDidBegin(_ gesture: FliperDismissGesture) {
        pagingView.isScrollEnabled = false
    }

    func dismissGestureDidChange(_ gesture: FliperDismissGesture, progress: CGFloat) {
        view.backgroundColor = backgroundColor.withAlphaComponent(1.0 - progress)
    }

    func dismissGestureDidEnd(_ gesture: FliperDismissGesture, shouldDismiss: Bool) {
        if shouldDismiss {
            dismissViewer()
        } else {
            guard let cell = currentVisibleCell() else { return }
            let screenCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            gesture.restoreScrollView(cell.scrollView, to: screenCenter) { [weak self] in
                self?.pagingView.isScrollEnabled = !((self?.isZoomed ?? false))
                self?.view.backgroundColor = self?.backgroundColor ?? .black
            }
        }
    }
}

// MARK: - UIViewControllerTransitioningDelegate

extension FliperViewerController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FliperTransitionAnimator(isPresenting: true)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FliperTransitionAnimator(isPresenting: false)
    }
}
