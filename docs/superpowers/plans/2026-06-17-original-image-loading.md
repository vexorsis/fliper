# Original Image Loading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add URL-based original image loading to Fliper with an injectable async image loader, a dedicated loading coordinator, spinner/error/retry UI in cells, and SwiftUI integration.

**Architecture:** A `FliperImageLoadingCoordinator` owns all async loading tasks and reports results to `FliperViewerController` via a delegate protocol. The controller drives cells through loading/success/error states. `FliperViewerItem` enum replaces the raw `UIImage` return in the data source. `FliperImageLoader` protocol lets callers inject any async image loading implementation.

**Tech Stack:** Swift 5.9+, UIKit, SwiftUI, no third-party dependencies

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `Sources/Fliper/Public/FliperViewerItem.swift` | Three-case enum for image items |
| Create | `Sources/Fliper/Public/FliperImageLoader.swift` | Async image loader protocol |
| Create | `Sources/Fliper/Internal/FliperImageLoadingCoordinator.swift` | Manages async tasks, reports success/failure |
| Modify | `Sources/Fliper/Public/FliperViewerDataSource.swift` | Change `imageAt` → `itemAt` |
| Modify | `Sources/Fliper/Internal/FliperImageCell.swift` | Add spinner, error UI, new configure method |
| Modify | `Sources/Fliper/Public/FliperViewerController.swift` | Add imageLoader prop, coordinator, wire everything |
| Modify | `Sources/Fliper/Public/FliperViewerModifier.swift` | Add items-based API, update data source adapter |

---

### Task 1: Add FliperViewerItem enum

**Files:**
- Create: `Sources/Fliper/Public/FliperViewerItem.swift`

- [ ] **Step 1: Create FliperViewerItem.swift**

```swift
import UIKit

public enum FliperViewerItem {
    /// A locally available image (e.g. thumbnail already in memory)
    case image(UIImage)
    /// A remote image to be loaded via FliperImageLoader
    case url(URL)
    /// A thumbnail shown immediately, with a remote original loaded in the background
    case imageAndURL(thumbnail: UIImage, original: URL)

    /// The URL to load, if this item requires remote loading
    var remoteURL: URL? {
        switch self {
        case .image:
            return nil
        case .url(let url):
            return url
        case .imageAndURL(_, let original):
            return original
        }
    }

    /// The thumbnail image, if available immediately
    var thumbnail: UIImage? {
        switch self {
        case .image(let image):
            return image
        case .url:
            return nil
        case .imageAndURL(let thumbnail, _):
            return thumbnail
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build succeeds (enum is not yet used, but compiles)

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewerItem.swift
git commit -m "feat: add FliperViewerItem enum for image/url/imageAndURL"
```

---

### Task 2: Add FliperImageLoader protocol

**Files:**
- Create: `Sources/Fliper/Public/FliperImageLoader.swift`

- [ ] **Step 1: Create FliperImageLoader.swift**

```swift
import UIKit

public protocol FliperImageLoader {
    func loadImage(from url: URL) async throws -> UIImage
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperImageLoader.swift
git commit -m "feat: add FliperImageLoader protocol with async load method"
```

---

### Task 3: Update FliperViewerDataSource to use FliperViewerItem

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewerDataSource.swift`

- [ ] **Step 1: Update the data source protocol**

Replace the entire contents of `FliperViewerDataSource.swift` with:

```swift
import UIKit

public protocol FliperViewerDataSource: AnyObject {
    func numberOfItems(in viewer: FliperViewerController) -> Int
    func viewer(_ viewer: FliperViewerController, itemAt index: Int) -> FliperViewerItem
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build FAILS — FliperSwiftUIDataSource and FliperViewerController still use the old `imageAt` method. This is expected; we fix them in later tasks.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewerDataSource.swift
git commit -m "feat: update FliperViewerDataSource to use FliperViewerItem"
```

---

### Task 4: Add FliperImageLoadingCoordinator

**Files:**
- Create: `Sources/Fliper/Internal/FliperImageLoadingCoordinator.swift`

- [ ] **Step 1: Create FliperImageLoadingCoordinator.swift**

```swift
import UIKit

protocol FliperImageLoadingCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didLoadImage image: UIImage, forItemAt index: Int)
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didFailWithError error: Error, forItemAt index: Int)
}

final class FliperImageLoadingCoordinator {
    weak var delegate: FliperImageLoadingCoordinatorDelegate?
    private let imageLoader: FliperImageLoader
    private var tasks: [Int: Task<Void, Never>] = [:]
    private var failedURLs: [Int: URL] = [:]

    init(imageLoader: FliperImageLoader) {
        self.imageLoader = imageLoader
    }

    func startLoading(url: URL, forItemAt index: Int) {
        cancelLoading(forItemAt: index)
        failedURLs.removeValue(forKey: index)

        let task = Task<Void, Never> { [weak self] in
            do {
                let image = try await imageLoader.loadImage(from: url)
                guard !Task.isCancelled else { return }
                self?.delegate?.coordinator(self!, didLoadImage: image, forItemAt: index)
            } catch {
                guard !Task.isCancelled else { return }
                self?.failedURLs[index] = url
                self?.delegate?.coordinator(self!, didFailWithError: error, forItemAt: index)
            }
        }
        tasks[index] = task
    }

    func cancelLoading(forItemAt index: Int) {
        tasks[index]?.cancel()
        tasks.removeValue(forKey: index)
        failedURLs.removeValue(forKey: index)
    }

    func retry(forItemAt index: Int) {
        guard let url = failedURLs[index] else { return }
        startLoading(url: url, forItemAt: index)
    }

    func cancelAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
        failedURLs.removeAll()
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build succeeds (coordinator is not yet wired, but compiles)

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/FliperImageLoadingCoordinator.swift
git commit -m "feat: add FliperImageLoadingCoordinator for async image loading"
```

---

### Task 5: Update FliperImageCell with spinner, error UI, and new configure method

**Files:**
- Modify: `Sources/Fliper/Internal/FliperImageCell.swift`

- [ ] **Step 1: Update FliperImageCell**

Replace the entire contents of `FliperImageCell.swift` with:

```swift
import UIKit

protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
    func cellDidLongPress(_ cell: FliperImageCell, point: CGPoint)
    func cellDidTapRetry(_ cell: FliperImageCell)
}

final class FliperImageCell: UICollectionViewCell {
    weak var cellDelegate: FliperImageCellDelegate?

    let scrollView = UIScrollView()
    let imageView = UIImageView()

    private var maxZoomScale: CGFloat = 5.0
    private var doubleTapZoomScale: CGFloat = 2.0
    private var isZoomed: Bool = false
    private var hasThumbnail: Bool = false

    private let doubleTapGesture = UITapGestureRecognizer()
    private let longPressGesture = UILongPressGestureRecognizer()

    private let spinner = UIActivityIndicatorView(style: .whiteLarge)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let errorContainer = UIView()

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
        scrollView.contentInsetAdjustmentBehavior = .never

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        contentView.addSubview(scrollView)
        scrollView.addSubview(imageView)

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        errorLabel.text = "Failed to load image"
        errorLabel.textColor = .white
        errorLabel.font = .preferredFont(forTextStyle: .subheadline)
        errorLabel.textAlignment = .center

        retryButton.setTitle("Retry", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        retryButton.layer.borderColor = UIColor.white.cgColor
        retryButton.layer.borderWidth = 1.0
        retryButton.layer.cornerRadius = 6.0
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)

        let errorStack = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        errorStack.axis = .vertical
        errorStack.spacing = 12
        errorStack.alignment = .center

        errorContainer.addSubview(errorStack)
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.isHidden = true
        contentView.addSubview(errorContainer)
        NSLayoutConstraint.activate([
            errorContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            errorStack.topAnchor.constraint(equalTo: errorContainer.topAnchor),
            errorStack.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor),
            errorStack.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorStack.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor)
        ])
    }

    private func setupGestures() {
        doubleTapGesture.numberOfTapsRequired = 2
        doubleTapGesture.addTarget(self, action: #selector(handleDoubleTap(_:)))
        scrollView.addGestureRecognizer(doubleTapGesture)

        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.addTarget(self, action: #selector(handleLongPress(_:)))
        scrollView.addGestureRecognizer(longPressGesture)
    }

    func configure(item: FliperViewerItem, maxZoomScale: CGFloat, doubleTapZoomScale: CGFloat) {
        self.maxZoomScale = maxZoomScale
        self.doubleTapZoomScale = doubleTapZoomScale
        scrollView.maximumZoomScale = maxZoomScale

        switch item {
        case .image(let image):
            hasThumbnail = false
            imageView.image = image
            hideSpinnerAndError()
        case .url:
            hasThumbnail = false
            imageView.image = nil
            showLoading()
        case .imageAndURL(let thumbnail, _):
            hasThumbnail = true
            imageView.image = thumbnail
            showLoading()
        }

        setNeedsLayout()
    }

    func showLoading() {
        spinner.startAnimating()
        errorContainer.isHidden = true
    }

    func showError() {
        spinner.stopAnimating()
        errorContainer.isHidden = false
    }

    func setImage(_ image: UIImage) {
        spinner.stopAnimating()
        errorContainer.isHidden = true

        if hasThumbnail {
            let transition = CATransition()
            transition.duration = 0.25
            transition.type = .fade
            imageView.layer.add(transition, forKey: "crossfade")
        }
        imageView.image = image
        setNeedsLayout()
    }

    private func hideSpinnerAndError() {
        spinner.stopAnimating()
        errorContainer.isHidden = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        hasThumbnail = false
        hideSpinnerAndError()
        resetZoom()
    }

    func resetZoom() {
        scrollView.setZoomScale(1.0, animated: false)
        scrollView.contentOffset = .zero
        scrollView.contentInset = .zero
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
            x: 0,
            y: 0,
            width: fitWidth,
            height: fitHeight
        )

        scrollView.contentSize = imageView.frame.size
        centerImageViewAfterZoom()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: imageView)
        guard imageView.bounds.contains(point) else { return }

        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let zoomRect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
            let savedMaxZoom = scrollView.maximumZoomScale
            scrollView.maximumZoomScale = doubleTapZoomScale
            scrollView.zoom(to: zoomRect, animated: true)
            scrollView.maximumZoomScale = savedMaxZoom
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: imageView)
        cellDelegate?.cellDidLongPress(self, point: point)
    }

    @objc private func handleRetry() {
        cellDelegate?.cellDidTapRetry(self)
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
    }

    private func centerImageViewAfterZoom() {
        let boundsSize = scrollView.bounds.size
        let contentSize = imageView.frame.size
        var inset = UIEdgeInsets.zero
        if contentSize.width < boundsSize.width {
            inset.left = (boundsSize.width - contentSize.width) / 2.0
            inset.right = inset.left
        }
        if contentSize.height < boundsSize.height {
            inset.top = (boundsSize.height - contentSize.height) / 2.0
            inset.bottom = inset.top
        }
        scrollView.contentInset = inset
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build FAILS — FliperViewerController still calls `cell.configure(image:...)`. This is expected; we fix it in Task 6.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/FliperImageCell.swift
git commit -m "feat: add spinner, error UI, and item-based configure to FliperImageCell"
```

---

### Task 6: Update FliperViewerController to wire everything together

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewerController.swift`

- [ ] **Step 1: Update FliperViewerController**

Replace the entire contents of `FliperViewerController.swift` with:

```swift
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

    public let imageLoader: FliperImageLoader?

    private let dataSource: FliperViewerDataSource
    private let loadingCoordinator: FliperImageLoadingCoordinator?
    private var pagingView: FliperPagingView!
    private var dismissGesture: FliperDismissGesture!
    private var isZoomed = false
    private var hasAppeared = false

    private static let cellReuseIdentifier = "FliperImageCell"

    public init(dataSource: FliperViewerDataSource, imageLoader: FliperImageLoader? = nil, currentIndex: Int = 0) {
        self.dataSource = dataSource
        self.imageLoader = imageLoader
        self.currentIndex = currentIndex
        if let imageLoader {
            self.loadingCoordinator = FliperImageLoadingCoordinator(imageLoader: imageLoader)
        } else {
            self.loadingCoordinator = nil
        }
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
        loadingCoordinator?.delegate = self
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
        if !hasAppeared {
            pagingView.scrollToPage(currentIndex)
            pagingView.layoutIfNeeded()
            updateDismissGestureTarget()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasAppeared = true
    }

    public func reloadData() {
        pagingView.reloadData()
    }

    public func dismissViewer() {
        loadingCoordinator?.cancelAll()
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

    private func item(at index: Int) -> FliperViewerItem {
        dataSource.viewer(self, itemAt: index)
    }

    private func startLoadingIfNeeded(item: FliperViewerItem, at index: Int) {
        guard let url = item.remoteURL, let loadingCoordinator else {
            assert(item.remoteURL == nil || imageLoader != nil, "FliperViewerItem.url or .imageAndURL requires an imageLoader")
            return
        }
        loadingCoordinator.startLoading(url: url, forItemAt: index)
    }
}

// MARK: - UICollectionViewDataSource

extension FliperViewerController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.numberOfItems(in: self)
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellReuseIdentifier, for: indexPath) as! FliperImageCell
        let viewerItem = item(at: indexPath.item)
        cell.configure(item: viewerItem, maxZoomScale: maxZoomScale, doubleTapZoomScale: doubleTapZoomScale)
        cell.cellDelegate = self
        startLoadingIfNeeded(item: viewerItem, at: indexPath.item)
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

    func cellDidTapRetry(_ cell: FliperImageCell) {
        guard let indexPath = pagingView.indexPath(for: cell) else { return }
        let index = indexPath.item
        cell.showLoading()
        loadingCoordinator?.retry(forItemAt: index)
    }
}

// MARK: - FliperImageLoadingCoordinatorDelegate

extension FliperViewerController: FliperImageLoadingCoordinatorDelegate {
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didLoadImage image: UIImage, forItemAt index: Int) {
        guard let cell = pagingView.cellForItem(at: IndexPath(item: index, section: 0)) as? FliperImageCell else { return }
        cell.setImage(image)
    }

    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didFailWithError error: Error, forItemAt index: Int) {
        guard let cell = pagingView.cellForItem(at: IndexPath(item: index, section: 0)) as? FliperImageCell else { return }
        cell.showError()
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

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build still fails due to FliperSwiftUIDataSource using old API. We fix that in Task 7.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewerController.swift
git commit -m "feat: wire FliperViewerController with loading coordinator and item-based data source"
```

---

### Task 7: Update SwiftUI integration

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewerModifier.swift`

- [ ] **Step 1: Update FliperViewerModifier.swift**

Replace the entire contents of `FliperViewerModifier.swift` with:

```swift
import SwiftUI
import UIKit

// MARK: - Data Source Adapter

final class FliperSwiftUIDataSource: FliperViewerDataSource {
    let items: [FliperViewerItem]

    init(items: [FliperViewerItem]) {
        self.items = items
    }

    func numberOfItems(in viewer: FliperViewerController) -> Int {
        items.count
    }

    func viewer(_ viewer: FliperViewerController, itemAt index: Int) -> FliperViewerItem {
        items[index]
    }
}

// MARK: - Presentation Coordinator

final class FliperPresentationCoordinator: ObservableObject, FliperViewerDelegate {
    var selectedIndex: Binding<Int?>?
    weak var presentedViewer: FliperViewerController?

    func viewerDidDismiss(_ viewer: FliperViewerController) {
        selectedIndex?.wrappedValue = nil
        presentedViewer = nil
    }

    func present(items: [FliperViewerItem], imageLoader: FliperImageLoader?, currentIndex: Int, selectedIndex: Binding<Int?>) {
        guard let presenter = topViewController() else { return }
        let dataSource = FliperSwiftUIDataSource(items: items)
        let viewer = FliperViewerController(dataSource: dataSource, imageLoader: imageLoader, currentIndex: currentIndex)
        viewer.delegate = self
        self.selectedIndex = selectedIndex
        self.presentedViewer = viewer
        presenter.present(viewer, animated: true)
    }

    func dismiss() {
        presentedViewer?.dismissViewer()
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - View Modifier

struct FliperViewerModifier: ViewModifier {
    @Binding var selectedIndex: Int?
    let items: [FliperViewerItem]
    var imageLoader: FliperImageLoader? = nil
    @StateObject private var coordinator = FliperPresentationCoordinator()

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedIndex) { newValue in
                if let index = newValue {
                    coordinator.present(items: items, imageLoader: imageLoader, currentIndex: index, selectedIndex: $selectedIndex)
                } else {
                    coordinator.dismiss()
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    public func fliperViewer(
        selectedIndex: Binding<Int?>,
        items: [FliperViewerItem],
        imageLoader: FliperImageLoader? = nil
    ) -> some View {
        modifier(FliperViewerModifier(
            selectedIndex: selectedIndex,
            items: items,
            imageLoader: imageLoader
        ))
    }

    public func fliperViewer(
        selectedIndex: Binding<Int?>,
        images: [UIImage]
    ) -> some View {
        let items = images.map { FliperViewerItem.image($0) }
        return modifier(FliperViewerModifier(
            selectedIndex: selectedIndex,
            items: items
        ))
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build succeeds — all internal sources compile. Demo app may need updating (Task 8).

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewerModifier.swift
git commit -m "feat: update SwiftUI integration with FliperViewerItem and imageLoader"
```

---

### Task 8: Update demo app to use URL-based loading

**Files:**
- Modify: `Demo/FliperDemo/FliperDemo/ContentView.swift`

- [ ] **Step 1: Update ContentView.swift**

Replace the entire contents of `ContentView.swift` with:

```swift
import SwiftUI
import Fliper

struct ContentView: View {
    @State private var selectedIndex: Int?

    private let items: [FliperViewerItem] = [
        URL(string: "https://picsum.photos/id/10/800/600")!,
        URL(string: "https://picsum.photos/id/20/800/600")!,
        URL(string: "https://picsum.photos/id/30/800/600")!,
        URL(string: "https://picsum.photos/id/40/800/600")!,
        URL(string: "https://picsum.photos/id/50/800/600")!,
        URL(string: "https://picsum.photos/id/60/800/600")!,
        URL(string: "https://picsum.photos/id/70/800/600")!,
        URL(string: "https://picsum.photos/id/80/800/600")!,
        URL(string: "https://picsum.photos/id/90/800/600")!,
        URL(string: "https://picsum.photos/id/100/800/600")!,
        URL(string: "https://picsum.photos/id/110/800/600")!,
        URL(string: "https://picsum.photos/id/120/800/600")!,
        URL(string: "https://picsum.photos/id/106/600/800")!,
    ].map { FliperViewerItem.url($0) }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<items.count, id: \.self) { index in
                    Color.gray
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            selectedIndex = index
                        }
                }
            }
        }
        .fliperViewer(selectedIndex: $selectedIndex, items: items, imageLoader: DemoImageLoader.shared)
    }
}

final class DemoImageLoader: FliperImageLoader {
    static let shared = DemoImageLoader()

    func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }
        return image
    }
}
```

- [ ] **Step 2: Build the demo app**

Run: `cd Demo/FliperDemo && xcodebuild -project FliperDemo.xcodeproj -scheme FliperDemo -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Demo/FliperDemo/FliperDemo/ContentView.swift
git commit -m "feat: update demo app to use URL-based image loading"
```

---

### Task 9: Manual testing

- [ ] **Step 1: Launch demo in simulator**

Run: `open -a Simulator && xcodebuild -project Demo/FliperDemo/FliperDemo.xcodeproj -scheme FliperDemo -destination 'platform=iOS Simulator,name=iPhone 16'`
Launch the app in simulator.

- [ ] **Step 2: Test `.url` flow**

1. Tap a gray thumbnail
2. Verify: spinner appears on black background
3. Verify: image loads and replaces spinner (instant, no crossfade)
4. Swipe between pages, verify loading works for each page

- [ ] **Step 3: Test error + retry flow**

1. Enable Network Link Conditioner (100% loss) in simulator
2. Tap a thumbnail
3. Verify: spinner appears, then error message + retry button shown
4. Disable Network Link Conditioner
5. Tap retry
6. Verify: spinner appears, then image loads successfully

- [ ] **Step 4: Test dismiss + cancel**

1. Tap a thumbnail (spinner appears)
2. Dismiss the viewer before image loads
3. Verify: no crash, no callback after dismiss

- [ ] **Step 5: Test cell reuse**

1. Open viewer on image at index 0
2. Quickly swipe through many pages
3. Verify: no images appear on wrong pages, no crashes from cancelled tasks
