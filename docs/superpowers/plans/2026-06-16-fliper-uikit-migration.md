# Fliper UIKit Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current SwiftUI Fliper implementation with a UIKit-based image viewer using UICollectionView + UIScrollView zoom, matching the architecture of GPImageBrowser but in pure Swift.

**Architecture:** FliperViewerController (UIViewController) orchestrates four delegated components: FliperPagingView (UICollectionView subclass with custom layout for inter-page spacing), FliperImageCell (UICollectionViewCell with UIScrollView zoom), FliperDismissGesture (pan-to-dismiss with anchor point manipulation), and FliperTransitionAnimator (fade+scale presentation/dismissal).

**Tech Stack:** Swift 5.9, UIKit (iOS 15+), no third-party dependencies.

---

## File Map

| File | Responsibility |
|---|---|
| `Package.swift` | SPM manifest (iOS 15+, update from v16) |
| `Sources/Fliper/Public/FliperViewerDataSource.swift` | Data source protocol |
| `Sources/Fliper/Public/FliperViewerDelegate.swift` | Delegate protocol (all optional) |
| `Sources/Fliper/Public/FliperViewerController.swift` | Main UIViewController, orchestrates all components |
| `Sources/Fliper/Internal/FliperPagingLayout.swift` | UICollectionViewFlowLayout subclass with parallax center-shift for inter-page spacing |
| `Sources/Fliper/Internal/FliperPagingView.swift` | UICollectionView subclass with paging, detects page index changes |
| `Sources/Fliper/Internal/FliperImageCell.swift` | UICollectionViewCell with UIScrollView zoom, double-tap, reports zoom state |
| `Sources/Fliper/Internal/FliperDismissGesture.swift` | UIGestureRecognizer subclass for pan-to-dismiss with anchor point manipulation |
| `Sources/Fliper/Internal/FliperTransitionAnimator.swift` | UIViewControllerAnimatedTransitioning for fade+scale present/dismiss |
| `Demo/FliperDemo/FliperDemo/ContentView.swift` | Updated demo using UIKit API |

**Files to delete** (replaced by the above):
- `Sources/Fliper/Public/FliperViewer.swift`
- `Sources/Fliper/Public/FliperThumbnail.swift`
- `Sources/Fliper/Public/FliperTransition.swift`
- `Sources/Fliper/Internal/ZoomContainer.swift`
- `Sources/Fliper/Internal/DismissController.swift`
- `Sources/Fliper/Internal/TransitionCoordinator.swift`

---

### Task 1: Scaffold — Remove SwiftUI sources, update Package.swift, create empty UIKit files

**Files:**
- Delete: `Sources/Fliper/Public/FliperViewer.swift`
- Delete: `Sources/Fliper/Public/FliperThumbnail.swift`
- Delete: `Sources/Fliper/Public/FliperTransition.swift`
- Delete: `Sources/Fliper/Internal/ZoomContainer.swift`
- Delete: `Sources/Fliper/Internal/DismissController.swift`
- Delete: `Sources/Fliper/Internal/TransitionCoordinator.swift`
- Modify: `Package.swift`
- Create: `Sources/Fliper/Public/FliperViewerDataSource.swift`
- Create: `Sources/Fliper/Public/FliperViewerDelegate.swift`
- Create: `Sources/Fliper/Public/FliperViewerController.swift`
- Create: `Sources/Fliper/Internal/FliperPagingLayout.swift`
- Create: `Sources/Fliper/Internal/FliperPagingView.swift`
- Create: `Sources/Fliper/Internal/FliperImageCell.swift`
- Create: `Sources/Fliper/Internal/FliperDismissGesture.swift`
- Create: `Sources/Fliper/Internal/FliperTransitionAnimator.swift`

- [ ] **Step 1: Delete old SwiftUI source files**

```bash
rm Sources/Fliper/Public/FliperViewer.swift
rm Sources/Fliper/Public/FliperThumbnail.swift
rm Sources/Fliper/Public/FliperTransition.swift
rm Sources/Fliper/Internal/ZoomContainer.swift
rm Sources/Fliper/Internal/DismissController.swift
rm Sources/Fliper/Internal/TransitionCoordinator.swift
```

- [ ] **Step 2: Update Package.swift to target iOS 15**

Replace `Package.swift` with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fliper",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Fliper", targets: ["Fliper"]),
    ],
    targets: [
        .target(name: "Fliper", path: "Sources/Fliper"),
    ]
)
```

- [ ] **Step 3: Create placeholder files so the package compiles**

Create `Sources/Fliper/Public/FliperViewerDataSource.swift`:
```swift
import UIKit

public protocol FliperViewerDataSource: AnyObject {
    func numberOfItems(in viewer: FliperViewerController) -> Int
    func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage
}
```

Create `Sources/Fliper/Public/FliperViewerDelegate.swift`:
```swift
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
```

Create `Sources/Fliper/Public/FliperViewerController.swift`:
```swift
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
```

Create `Sources/Fliper/Internal/FliperPagingLayout.swift`:
```swift
import UIKit

final class FliperPagingLayout: UICollectionViewFlowLayout {
    var interPageSpacing: CGFloat = 20.0

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect)?
            .map({ $0.copy() as! UICollectionViewLayoutAttributes }) else { return nil }
        return superAttributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
}
```

Create `Sources/Fliper/Internal/FliperPagingView.swift`:
```swift
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
```

Create `Sources/Fliper/Internal/FliperImageCell.swift`:
```swift
import UIKit

protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
}

final class FliperImageCell: UICollectionViewCell {
    weak var cellDelegate: FliperImageCellDelegate?

    let scrollView = UIScrollView()
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        scrollView.zoomScale = 1.0
        scrollView.contentOffset = .zero
    }
}
```

Create `Sources/Fliper/Internal/FliperDismissGesture.swift`:
```swift
import UIKit

final class FliperDismissGesture: UIGestureRecognizer {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }
}
```

Create `Sources/Fliper/Internal/FliperTransitionAnimator.swift`:
```swift
import UIKit

final class FliperTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.25
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: transitionContext)
        } else {
            animateDismiss(using: transitionContext)
        }
    }

    private func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to) else { return }
        let containerView = transitionContext.containerView
        containerView.addSubview(toView)
        transitionContext.completeTransition(true)
    }

    private func animateDismiss(using transitionContext: UIViewControllerContextTransitioning) {
        transitionContext.completeTransition(true)
    }
}
```

- [ ] **Step 4: Verify package builds**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: scaffold UIKit files, remove SwiftUI sources, target iOS 15"
```

---

### Task 2: FliperPagingLayout — Custom flow layout with inter-page spacing

**Files:**
- Modify: `Sources/Fliper/Internal/FliperPagingLayout.swift`

This layout uses the same parallax center-shift technique as GPImageBrowser: cells that are further from the viewport center get pushed further away, creating a visual gap between pages while `isPagingEnabled` remains true.

- [ ] **Step 1: Implement the parallax center-shift layout**

Replace `Sources/Fliper/Internal/FliperPagingLayout.swift` with:

```swift
import UIKit

final class FliperPagingLayout: UICollectionViewFlowLayout {
    var interPageSpacing: CGFloat = 20.0

    override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }
        scrollDirection = .horizontal
        itemSize = collectionView.bounds.size
        minimumLineSpacing = 0
        minimumInteritemSpacing = 0
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let superAttributes = super.layoutAttributesForElements(in: rect)?
            .map({ $0.copy() as! UICollectionViewLayoutAttributes }),
              let collectionView = collectionView else { return nil }

        let halfWidth = collectionView.bounds.width / 2.0
        let centerX = collectionView.contentOffset.x + halfWidth

        for attributes in superAttributes {
            let shift = (attributes.center.x - centerX) / halfWidth * interPageSpacing / 2.0
            attributes.center.x += shift
        }

        return superAttributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
}
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/FliperPagingLayout.swift
git commit -m "feat: implement FliperPagingLayout with parallax center-shift spacing"
```

---

### Task 3: FliperPagingView — UICollectionView subclass with paging and index detection

**Files:**
- Modify: `Sources/Fliper/Internal/FliperPagingView.swift`

FliperPagingView is a UICollectionView subclass with `isPagingEnabled = true`. It detects page index changes in `scrollViewDidScroll` by computing the nearest integer index from content offset, using the same rounding technique as GPImageBrowser. It applies left/right content insets of `interPageSpacing / 2` so the first and last pages center correctly.

- [ ] **Step 1: Implement FliperPagingView with page index detection and inset**

Replace `Sources/Fliper/Internal/FliperPagingView.swift` with:

```swift
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

extension FliperPagingView: UIScrollViewDelegate {
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
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/FliperPagingView.swift
git commit -m "feat: implement FliperPagingView with page index detection and content inset"
```

---

### Task 4: FliperImageCell — UICollectionViewCell with UIScrollView zoom and double-tap

**Files:**
- Modify: `Sources/Fliper/Internal/FliperImageCell.swift`

FliperImageCell contains a UIScrollView wrapping a UIImageView. The scroll view handles pinch-zoom natively. Double-tap toggles between 1x and `doubleTapZoomScale` using the `zoom(to:animated:)` trick from GPImageBrowser (zoom to a 1x1 rect at the tap point, with maximumZoomScale temporarily set to the target scale). After zoom, the image is centered in the scroll view.

- [ ] **Step 1: Implement FliperImageCell with zoom, double-tap, and centering**

Replace `Sources/Fliper/Internal/FliperImageCell.swift` with:

```swift
import UIKit

protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
}

final class FliperImageCell: UICollectionViewCell {
    weak var cellDelegate: FliperImageCellDelegate?

    let scrollView = UIScrollView()
    let imageView = UIImageView()

    private var maxZoomScale: CGFloat = 5.0
    private var doubleTapZoomScale: CGFloat = 2.0
    private var isZoomed: Bool = false

    private let doubleTapGesture = UITapGestureRecognizer()
    private let longPressGesture = UILongPressGestureRecognizer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupGestures()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = maxZoomScale
        scrollView.decelerationRate = .fast
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.layer.masksToBounds = false
        scrollView.contentInsetAdjustmentBehavior = .never

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    private func setupGestures() {
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.addTarget(self, action: #selector(handleDoubleTap(_:)))
        scrollView.addGestureRecognizer(doubleTapGesture)

        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.addTarget(self, action: #selector(handleLongPress(_:)))
        scrollView.addGestureRecognizer(longPressGesture)
    }

    func configure(image: UIImage, maxZoomScale: CGFloat, doubleTapZoomScale: CGFloat) {
        self.maxZoomScale = maxZoomScale
        self.doubleTapZoomScale = doubleTapZoomScale
        scrollView.maximumZoomScale = maxZoomScale
        imageView.image = image
        setNeedsLayout()
    }

    func resetZoom() {
        scrollView.setZoomScale(1.0, animated: false)
        scrollView.contentOffset = .zero
        updateZoomState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = contentView.bounds
        layoutImageView()
    }

    private func layoutImageView() {
        guard let image = imageView.image else { return }
        let screenSize = scrollView.bounds.size
        let imageSize = image.size

        let widthRatio = screenSize.width / imageSize.width
        let heightRatio = screenSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let fitWidth = imageSize.width * scale
        let fitHeight = imageSize.height * scale

        imageView.frame = CGRect(
            x: max(0, (screenSize.width - fitWidth) / 2.0),
            y: max(0, (screenSize.height - fitHeight) / 2.0),
            width: fitWidth,
            height: fitHeight
        )

        scrollView.contentSize = CGSize(
            width: max(screenSize.width, fitWidth),
            height: max(screenSize.height, fitHeight)
        )
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: imageView)
        guard imageView.bounds.contains(point) else { return }

        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            scrollView.maximumZoomScale = doubleTapZoomScale
            scrollView.zoom(to: CGRect(x: point.x, y: point.y, width: 1, height: 1), animated: true)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: imageView)
        cellDelegate?.cellDidLongPress(self, point: point)
    }

    private func updateZoomState() {
        let zoomed = scrollView.zoomScale > 1.0
        if zoomed != isZoomed {
            isZoomed = zoomed
            cellDelegate?.cellZoomStateDidChange(self, isZoomed: zoomed)
        }
    }
}

extension FliperImageCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageViewAfterZoom()
        updateZoomState()

        if scrollView.zoomScale <= 1.0 {
            scrollView.maximumZoomScale = maxZoomScale
        }
    }

    private func centerImageViewAfterZoom() {
        let screenSize = scrollView.bounds.size
        let contentSize = imageView.frame.size

        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0

        if contentSize.width < screenSize.width {
            offsetX = (screenSize.width - contentSize.width) / 2.0
        }
        if contentSize.height < screenSize.height {
            offsetY = (screenSize.height - contentSize.height) / 2.0
        }

        imageView.center = CGPoint(
            x: max(contentSize.width / 2.0, screenSize.width / 2.0) + offsetX,
            y: max(contentSize.height / 2.0, screenSize.height / 2.0) + offsetY
        )
    }
}
```

- [ ] **Step 2: Update FliperImageCellDelegate to include long press**

The delegate needs a long press method. Update the protocol at the top of the file (already included above):

```swift
protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
    func cellDidLongPress(_ cell: FliperImageCell, point: CGPoint)
}
```

This is already in the code above.

- [ ] **Step 3: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/Fliper/Internal/FliperImageCell.swift
git commit -m "feat: implement FliperImageCell with UIScrollView zoom, double-tap, and centering"
```

---

### Task 5: FliperDismissGesture — Pan-to-dismiss with anchor point manipulation

**Files:**
- Modify: `Sources/Fliper/Internal/FliperDismissGesture.swift`

This gesture implements GPImageBrowser-style pan-to-dismiss. When the user drags vertically at zoom scale 1.0, the cell's scroll view anchor point is moved to the touch point and the scroll view follows the finger. The cell scales down and the background fades proportionally. On release past threshold, the viewer dismisses; otherwise it springs back.

- [ ] **Step 1: Implement FliperDismissGesture with anchor point manipulation**

Replace `Sources/Fliper/Internal/FliperDismissGesture.swift` with:

```swift
import UIKit

protocol FliperDismissGestureDelegate: AnyObject {
    func dismissGestureDidBegin(_ gesture: FliperDismissGesture)
    func dismissGestureDidChange(_ gesture: FliperDismissGesture, progress: CGFloat)
    func dismissGestureDidEnd(_ gesture: FliperDismissGesture, shouldDismiss: Bool)
}

final class FliperDismissGesture: UIGestureRecognizer {
    weak var dismissDelegate: FliperDismissGestureDelegate?
    var dismissThreshold: CGFloat = 0.25

    private var startPoint = CGPoint.zero
    private var isInteracting = false
    private var targetScrollView: UIScrollView?

    func setTargetScrollView(_ scrollView: UIScrollView) {
        targetScrollView = scrollView
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        startPoint = touch.location(in: view)
        state = .possible
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let point = touch.location(in: view)

        if !isInteracting {
            let dx = abs(point.x - startPoint.x)
            let dy = point.y - startPoint.y
            if dy > 3 && dy > dx {
                beginInteraction(at: point)
            }
            return
        }

        let dy = point.y - startPoint.y
        let viewHeight = view?.bounds.height ?? 1
        let progress = min(1.0, max(0.0, abs(dy) / (viewHeight * 1.2)))

        targetScrollView?.center = point

        let scale = max(0.35, 1.0 - progress * 0.65)
        targetScrollView?.transform = CGAffineTransform(scaleX: scale, y: scale)

        dismissDelegate?.dismissGestureDidChange(self, progress: progress)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard isInteracting else { state = .failed; return }

        guard let touch = touches.first else { state = .failed; return }
        let point = touch.location(in: view)
        let dy = point.y - startPoint.y
        let viewHeight = view?.bounds.height ?? 1

        let velocity = velocity(in: view)
        let shouldDismiss = abs(dy) > viewHeight * dismissThreshold || abs(velocity.y) > 800

        dismissDelegate?.dismissGestureDidEnd(self, shouldDismiss: shouldDismiss)
        isInteracting = false
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        if isInteracting {
            dismissDelegate?.dismissGestureDidEnd(self, shouldDismiss: false)
            isInteracting = false
        }
        state = .cancelled
    }

    private func beginInteraction(at point: CGPoint) {
        isInteracting = true
        state = .began

        guard let scrollView = targetScrollView else { return }

        let anchorX = point.x / scrollView.bounds.width
        let anchorY = point.y / scrollView.bounds.height
        scrollView.layer.anchorPoint = CGPoint(x: anchorX, y: anchorY)

        scrollView.isUserInteractionEnabled = false

        dismissDelegate?.dismissGestureDidBegin(self)
    }

    func restoreScrollView(_ scrollView: UIScrollView, to center: CGPoint, duration: TimeInterval = 0.15, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            scrollView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            scrollView.center = center
            scrollView.transform = .identity
        }, completion: { _ in
            scrollView.isUserInteractionEnabled = true
            completion?()
        })
    }

    func animateDismiss(_ scrollView: UIScrollView, toward point: CGPoint, duration: TimeInterval = 0.25, completion: @escaping () -> Void) {
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
            scrollView.alpha = 0
            scrollView.transform = scrollView.transform.scaledBy(x: 0.5, y: 0.5)
        }, completion: { _ in
            completion()
        })
    }
}
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/FliperDismissGesture.swift
git commit -m "feat: implement FliperDismissGesture with anchor point pan-to-dismiss"
```

---

### Task 6: FliperTransitionAnimator — Fade+scale presentation and dismissal

**Files:**
- Modify: `Sources/Fliper/Internal/FliperTransitionAnimator.swift`

Implements UIViewControllerAnimatedTransitioning. On present: fades the background from transparent to opaque and scales content from 0.95 to 1.0. On dismiss: reverse.

- [ ] **Step 1: Implement fade+scale transition animator**

Replace `Sources/Fliper/Internal/FliperTransitionAnimator.swift` with:

```swift
import UIKit

final class FliperTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    private let duration: TimeInterval = 0.25

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresent(using: transitionContext)
        } else {
            animateDismiss(using: transitionContext)
        }
    }

    private func animatePresent(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        containerView.addSubview(toView)

        toView.alpha = 0
        toView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                toView.alpha = 1
                toView.transform = .identity
            },
            completion: { finished in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }

    private func animateDismiss(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                fromView.alpha = 0
                fromView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            },
            completion: { finished in
                fromView.transform = .identity
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        )
    }
}
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/FliperTransitionAnimator.swift
git commit -m "feat: implement FliperTransitionAnimator with fade+scale transitions"
```

---

### Task 7: FliperViewerController — Wire all components together

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewerController.swift`

This is the main controller that orchestrates all components. It sets up the FliperPagingView as its collection view, implements UICollectionViewDataSource/Delegate, manages the FliperDismissGesture, handles zoom state changes from FliperImageCell, and manages page index changes.

- [ ] **Step 1: Implement the full FliperViewerController**

Replace `Sources/Fliper/Public/FliperViewerController.swift` with:

```swift
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
    private var pagingView: FliperPagingView!
    private var dismissGesture: FliperDismissGesture!
    private var isZoomed = false

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
        pagingView.frame = view.bounds
        if let layout = pagingView.collectionViewLayout as? FliperPagingLayout {
            layout.invalidateLayout()
        }
        pagingView.updateContentInset()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        pagingView.scrollToPage(currentIndex)
    }

    public func reloadData() {
        pagingView.reloadData()
    }

    public func dismissViewer() {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.delegate?.viewerDidDismiss(self)
        }
    }

    private func setupPagingView() {
        pagingView = FliperPagingView(frame: view.bounds)
        pagingView.register(FliperImageCell.self, forCellWithReuseIdentifier: Self.cellReuseIdentifier)
        pagingView.dataSource = self
        pagingView.pagingDelegate = self
        pagingView.currentIndex = currentIndex
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
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewerController.swift
git commit -m "feat: implement FliperViewerController orchestrating all components"
```

---

### Task 8: Update demo app to use UIKit API

**Files:**
- Modify: `Demo/FliperDemo/FliperDemo/ContentView.swift`
- Modify: `Demo/FliperDemo/FliperDemo/FliperDemoApp.swift` (if needed)

The demo app currently uses the SwiftUI API. Replace it with UIKit usage: a thumbnail grid in SwiftUI that creates and presents a FliperViewerController.

- [ ] **Step 1: Update ContentView to use FliperViewerController**

Replace `Demo/FliperDemo/FliperDemo/ContentView.swift` with:

```swift
import SwiftUI
import Fliper

struct ContentView: View {
    @State private var isPresented = false
    @State private var selectedIndex = 0

    private let imageNames = (1...12).map { "photo\($0)" }
    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<imageNames.count, id: \.self) { index in
                    Image(imageNames[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .onTapGesture {
                            selectedIndex = index
                            isPresented = true
                        }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            FliperViewerWrapper(
                imageNames: imageNames,
                currentIndex: selectedIndex,
                isPresented: $isPresented
            )
            .ignoresSafeArea()
        }
    }
}

struct FliperViewerWrapper: UIViewControllerRepresentable {
    let imageNames: [String]
    let currentIndex: Int
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> FliperViewerController {
        let dataSource = FliperDemoDataSource(imageNames: imageNames)
        let viewer = FliperViewerController(dataSource: dataSource, currentIndex: currentIndex)
        viewer.delegate = context.coordinator
        return viewer
    }

    func updateUIViewController(_ uiViewController: FliperViewerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject, FliperViewerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func viewerDidDismiss(_ viewer: FliperViewerController) {
            isPresented = false
        }
    }
}

final class FliperDemoDataSource: FliperViewerDataSource {
    let imageNames: [String]

    init(imageNames: [String]) {
        self.imageNames = imageNames
    }

    func numberOfItems(in viewer: FliperViewerController) -> Int {
        imageNames.count
    }

    func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage {
        UIImage(named: imageNames[index]) ?? UIImage()
    }
}
```

- [ ] **Step 2: Verify demo project builds in Xcode**

Open the demo project in Xcode and build. Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Demo/FliperDemo/FliperDemo/ContentView.swift
git commit -m "feat: update demo app to use UIKit FliperViewerController API"
```

---

### Task 9: Integration testing — Manual verification of all features

**Files:**
- None (manual testing only)

Run the demo app on an iOS 15+ simulator and verify all features work together.

- [ ] **Step 1: Test the complete flow in simulator**

Run through this checklist:
1. Thumbnail grid renders correctly in 3 columns
2. Tap a thumbnail → viewer presents with fade+scale transition
3. Pinch zoom: scale follows fingers, bounded at maxZoomScale
4. Double-tap zoom in → animates to doubleTapZoomScale at the tap point
5. Double-tap zoom out → animates back to 1x
6. Pan while zoomed: image follows finger via UIScrollView, bounded at content edges
7. Swipe between images at scale 1.0: smooth page snap with inter-page spacing visible
8. Swipe while zoomed: pans image, does not change page
9. Drag down to dismiss: image shrinks following finger, background fades, spring back if released early
10. Drag down past threshold: viewer dismisses with fade+scale transition
11. Navigate to different image and dismiss: works correctly
12. Long press on image: delegate callback fires

- [ ] **Step 2: Fix any issues found during testing**

Address each issue found in Step 1. Common areas:
- Gesture conflict between dismiss gesture and paging scroll
- Anchor point restoration not resetting correctly
- Double-tap zoom scale overshooting (maximumZoomScale not being temporarily limited)
- Image not centering correctly after zoom
- Content inset causing first/last page misalignment

- [ ] **Step 3: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration test fixes for gesture conflicts and layout"
```
