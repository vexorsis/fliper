# Fliper — UIKit Image Viewer Library

A UIKit image viewer library (SPM package) providing an iOS Photos-style fullscreen image browsing experience with fade+scale transition, pinch-zoom, double-tap zoom, horizontal swipe paging, and pan-to-dismiss.

## Overview

- **Package type:** Swift Package (SPM)
- **Platform:** iOS 15+
- **Swift version:** 5.9+
- **Dependencies:** None
- **Architecture:** Delegated components — FliperViewerController orchestrates FliperPagingView, FliperImageCell, FliperDismissGesture, and FliperTransitionAnimator

## Public API

### FliperViewerDataSource

Required protocol providing image data.

```swift
protocol FliperViewerDataSource: AnyObject {
    func numberOfItems(in viewer: FliperViewerController) -> Int
    func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage
}
```

### FliperViewerDelegate

Optional protocol for viewer events.

```swift
protocol FliperViewerDelegate: AnyObject {
    func viewer(_ viewer: FliperViewerController, didScrollToIndex index: Int)
    func viewer(_ viewer: FliperViewerController, didLongPressImageAt index: Int, point: CGPoint)
    func viewerDidDismiss(_ viewer: FliperViewerController)
}
```

All methods are optional.

### FliperViewerController

The main fullscreen viewer controller.

```swift
class FliperViewerController: UIViewController {
    init(dataSource: FliperViewerDataSource, currentIndex: Int)

    weak var delegate: FliperViewerDelegate?

    // Configuration
    var maxZoomScale: CGFloat          // default 5.0
    var doubleTapZoomScale: CGFloat    // default 2.0
    var dismissThreshold: CGFloat      // default 0.25 (fraction of view height)
    var interPageSpacing: CGFloat      // default 20pt
    var backgroundColor: UIColor       // default .black

    // State
    var currentIndex: Int              // synced with paging, observable by consumer

    // Actions
    func reloadData()
    func dismissViewer()
}
```

**Presentation:** Consumer creates the controller, sets properties, then calls `present(viewer, animated: true)`. The fade+scale transition is handled by FliperTransitionAnimator.

**Dismissal:** Pan-to-dismiss gesture or `dismissViewer()`. The delegate receives `viewerDidDismiss`.

## Internal Components

### FliperPagingView

UICollectionView subclass with `isPagingEnabled = true`. Uses FliperPagingLayout for inter-page spacing. Detects page index changes in `scrollViewDidScroll` by computing the nearest integer index from content offset.

### FliperPagingLayout

UICollectionViewFlowLayout subclass. Overrides `layoutAttributesForElements(in:)` to shift cell centers based on their offset from the viewport center, creating inter-page spacing while maintaining paging behavior. The collection view is inset by `interPageSpacing / 2` on left and right so the first and last pages center correctly.

### FliperImageCell

UICollectionViewCell containing a UIScrollView (zoom container) wrapping a UIImageView. Conforms to UIScrollViewDelegate:

- `viewForZooming(in:)` returns the UIImageView
- Double-tap via UITapGestureRecognizer (count: 2) toggles zoom between 1.0 and `doubleTapZoomScale`, zooming to the tap point using `scrollView.zoom(to:animated:)`
- Reports zoom state changes to the controller via the `FliperImageCellDelegate` protocol

```swift
protocol FliperImageCellDelegate: AnyObject {
    func cellZoomStateDidChange(_ cell: FliperImageCell, isZoomed: Bool)
}
```

On `prepareForReuse()`: resets zoom scale to 1.0, content offset to .zero, and image to nil.

### FliperDismissGesture

UIGestureRecognizer subclass implementing GPImageBrowser-style pan-to-dismiss:

1. **Begin:** Only activates when cell is at zoom scale 1.0. Records touch point, shifts the cell's scroll view `layer.anchorPoint` to the touch point, compensates center offset.
2. **Move:** Translates center to follow finger. Computes `progress = translation / viewHeight`. Applies `cell.transform = .init(scaleX: 1 - progress * 0.5, y: 1 - progress * 0.5)`. Fades background to `1 - progress`.
3. **End past threshold or with sufficient velocity:** Calls dismiss with spring animation.
4. **End below threshold:** Animates cell back to identity transform, restores anchor point to (0.5, 0.5), fades background back to opaque.

### FliperTransitionAnimator

Implements UIViewControllerAnimatedTransitioning for fade+scale transitions:

- **Present:** Fades background from transparent to opaque, scales content from 0.95 to 1.0.
- **Dismiss:** Reverse — scales content from 1.0 to 0.95, fades background from opaque to transparent.

Uses `UIModalPresentationStyle.custom` with the controller as its own `transitioningDelegate` (conforms to `UIViewControllerTransitioningDelegate`).

## Gesture System

| Zoom State | Pan Gesture | Double-Tap | CollectionView Paging | Dismiss Gesture |
|---|---|---|---|---|
| 1x (not zoomed) | — | Zoom to 2x at tap point | Active | Active |
| > 1x (zoomed) | UIScrollView handles automatically | Reset to 1x | Disabled | Disabled |

**Priority resolution:**

- FliperImageCell reports zoom state via `cellZoomStateDidChange(isZoomed:)` delegate callback
- FliperViewerController stores this state and toggles `FliperDismissGesture.isEnabled` and `FliperPagingView.isScrollEnabled` accordingly
- UIScrollView's built-in pan-when-zoomed naturally takes priority over the collection view scroll when zoomed

**Page change resets zoom:** When `currentIndex` changes, the controller tells the previously visible cell to reset zoom scale to 1.0 and content offset to .zero.

## Data Flow

**State ownership:**

| State | Owner | How it propagates |
|---|---|---|
| `currentIndex` | FliperViewerController | Set on init, updated by FliperPagingView's scrollViewDidScroll, readable by consumer |
| `isZoomed` (per cell) | FliperImageCell | Reported to controller via cellZoomStateDidChange delegate |
| `dismissProgress` | FliperDismissGesture | Computed live during gesture, applied directly to cell transform and background opacity |
| `images` | Consumer (via data source) | Pulled on cellForItemAt, no caching in the library |

**Key flows:**

1. **Page change:** FliperPagingView.scrollViewDidScroll → computes nearest page index → calls FliperViewerController.didScrollToIndex() → controller updates currentIndex, tells previous cell to reset zoom, toggles gesture states, notifies delegate

2. **Zoom change:** FliperImageCell.scrollViewDidZoom → calls cellZoomStateDidChange(isZoomed:) → controller toggles FliperPagingView.isScrollEnabled and FliperDismissGesture.isEnabled

3. **Dismiss:** FliperDismissGesture action handler → if threshold crossed, calls FliperViewerController.dismissViewer() → controller calls dismiss(animated:true) → FliperTransitionAnimator plays dismiss animation → delegate receives viewerDidDismiss

4. **Cell reuse:** Standard UICollectionView reuse. On prepareForReuse, cell resets. On dequeue, controller asks data source for image.

No external state management (no Combine, no ObservableObject). The controller is the single source of truth, communicating imperatively through delegate callbacks and direct property sets.

## Package Structure

```
Fliper/
├── Package.swift
├── Sources/
│   └── Fliper/
│       ├── Public/
│       │   ├── FliperViewerController.swift
│       │   ├── FliperViewerDataSource.swift
│       │   └── FliperViewerDelegate.swift
│       └── Internal/
│           ├── FliperPagingView.swift
│           ├── FliperPagingLayout.swift
│           ├── FliperImageCell.swift
│           ├── FliperDismissGesture.swift
│           └── FliperTransitionAnimator.swift
├── Tests/
│   └── FliperTests/
└── Demo/
    └── FliperDemo/
```

## Configuration

Direct properties on FliperViewerController:

| Property | Type | Default | Description |
|---|---|---|---|
| `maxZoomScale` | CGFloat | 5.0 | Maximum pinch-zoom scale |
| `doubleTapZoomScale` | CGFloat | 2.0 | Scale on double-tap |
| `dismissThreshold` | CGFloat | 0.25 | Fraction of view height to drag before dismissing |
| `interPageSpacing` | CGFloat | 20.0 | Horizontal gap between pages |
| `backgroundColor` | UIColor | .black | Background color behind images |
