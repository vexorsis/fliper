import UIKit

public class FliperViewerController: UIViewController {
    public weak var delegate: FliperViewerDelegate?

    public var maxZoomScale: CGFloat = 5.0
    public var doubleTapZoomScale: CGFloat = 2.0
    public var dismissThreshold: CGFloat = 0.25
    public var interPageSpacing: CGFloat = 20.0
    public var backgroundColor: UIColor = .black
    public var currentIndex: Int = 0

    private let dataSource: FliperViewerDataSource

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
    }

    public func reloadData() {}
    public func dismissViewer() {}
}

extension FliperViewerController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FliperTransitionAnimator(isPresenting: true)
    }

    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        FliperTransitionAnimator(isPresenting: false)
    }
}
