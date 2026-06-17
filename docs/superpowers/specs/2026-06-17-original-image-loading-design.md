# Original Image Loading Design

## Overview

Add support for loading original images from URLs. When a user taps a thumbnail, Fliper shows a loading indicator while the original image downloads, then displays it. Failed loads show an error message with a retry button.

## Decisions

- **Data source**: Replace `viewer(_:imageAt:) -> UIImage` with `viewer(_:itemAt:) -> FliperViewerItem` (a three-case enum)
- **Loading indicator**: System `UIActivityIndicatorView` (white large, centered)
- **Error state**: Centered "Failed to load image" label + "Retry" button
- **Image loading**: Injectable `FliperImageLoader` protocol with async method
- **Architecture**: Dedicated `FliperImageLoadingCoordinator` (Approach C)

## FliperViewerItem

```swift
public enum FliperViewerItem {
    /// A locally available image (e.g. thumbnail already in memory)
    case image(UIImage)
    /// A remote image to be loaded via FliperImageLoader
    case url(URL)
    /// A thumbnail shown immediately, with a remote original loaded in the background
    case imageAndURL(thumbnail: UIImage, original: URL)
}
```

The data source protocol changes from:

```swift
func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage
```

to:

```swift
func viewer(_ viewer: FliperViewerController, itemAt index: Int) -> FliperViewerItem
```

This is a breaking change. Existing adopters must switch from returning `UIImage` to wrapping it in `.image(...)`.

For `.image` items, no loading is needed. For `.url` and `.imageAndURL`, the loading coordinator handles fetching. For `.imageAndURL`, the thumbnail displays immediately and gets replaced when the original loads.

## FliperImageLoader Protocol

```swift
public protocol FliperImageLoader {
    func loadImage(from url: URL) async throws -> UIImage
}
```

A single async method. Callers implement this with whatever backing they want (URLSession, Kingfisher, SDWebImage, custom cache, etc.). The `throws` lets the loading coordinator distinguish success from failure for the error+retry state.

FliperViewerController gets a new optional property:

```swift
public let imageLoader: FliperImageLoader?
```

If `nil`, only `.image` items are supported (backward compatible at the init level). Passing `.url` or `.imageAndURL` items with a `nil` loader will assert in debug and show nothing in release.

## FliperImageLoadingCoordinator

A new internal class that owns all async loading tasks and communicates with cells via a delegate protocol.

### Delegate Protocol

```swift
protocol FliperImageLoadingCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didLoadImage image: UIImage, forItemAt index: Int)
    func coordinator(_ coordinator: FliperImageLoadingCoordinator,
                     didFailWithError error: Error, forItemAt index: Int)
}
```

### Coordinator Interface

```swift
final class FliperImageLoadingCoordinator {
    weak var delegate: FliperImageLoadingCoordinatorDelegate?
    private let imageLoader: FliperImageLoader
    private var tasks: [Int: Task<Void, Never>] = [:]
    private var failedURLs: [Int: URL] = [:]

    func startLoading(url: URL, forItemAt index: Int)
    func cancelLoading(forItemAt index: Int)
    func retry(forItemAt index: Int)
    func cancelAll()
}
```

Key behaviors:

- `startLoading` launches an async Task that calls `imageLoader.loadImage(from:)`, reports success or failure to delegate
- `cancelLoading` cancels and removes the task for that index
- `retry` looks up the stored URL from `failedURLs` and re-runs the load
- `cancelAll` cancels everything (called on viewer dismiss)
- The coordinator holds no UI — it's pure logic
- `failedURLs` stores the URL for each failed index so `retry` can re-fetch without the caller providing the URL again

## FliperImageCell Changes

The cell gains a spinner and an error state, controlled externally by the controller.

### New Methods

```swift
func configure(item: FliperViewerItem, maxZoomScale: CGFloat, doubleTapZoomScale: CGFloat)
func showLoading()
func showError()
func setImage(_ image: UIImage)  // 0.25s crossfade if replacing a thumbnail; instant if replacing spinner
```

### New Subviews

- `UIActivityIndicatorView` (white large, centered, hidden by default)
- Error overlay: a `UILabel` ("Failed to load image") + `UIButton` ("Retry"), both centered, hidden by default

### State Transitions

| Item type | On configure | On load success | On load failure |
|---|---|---|---|
| `.image` | Image set directly, no spinner/error | N/A | N/A |
| `.url` | Spinner shown | `setImage` replaces spinner with image (no animation for `.url` items) | `showError` replaces spinner with error+retry |
| `.imageAndURL` | Thumbnail set, spinner shown over it | `setImage` crossfades from thumbnail to original (0.25s fade transition) | `showError` shows error overlay over thumbnail |

### Retry

The retry button triggers a new delegate method on `FliperImageCellDelegate`:

```swift
func cellDidTapRetry(_ cell: FliperImageCell)
```

The controller receives this, calls `loadingCoordinator.retry(forItemAt:)`, and calls `cell.showLoading()`.

### Prepare for Reuse

`prepareForReuse` resets spinner and error state (hides both, clears image).

## FliperViewerController Changes

### New Stored Properties

```swift
private let imageLoader: FliperImageLoader?
private let loadingCoordinator: FliperImageLoadingCoordinator?
```

### Init Change

```swift
public init(dataSource: FliperViewerDataSource, imageLoader: FliperImageLoader? = nil, currentIndex: Int = 0)
```

`imageLoader` defaults to `nil` — existing callers work without changes. When `imageLoader` is provided, creates a `FliperImageLoadingCoordinator`.

### cellForItemAt Changes

- Calls `cell.configure(item:...)` instead of `cell.configure(image:...)`
- For `.url` items: calls `cell.showLoading()`, then `loadingCoordinator.startLoading(url:forItemAt:)`
- For `.imageAndURL` items: calls `cell.showLoading()`, then `loadingCoordinator.startLoading(url:forItemAt:)` (thumbnail is already set by `configure`)
- For `.image` items: no loading needed

### FliperImageLoadingCoordinatorDelegate Adoption

- `didLoadImage` → finds cell at index, calls `cell.setImage(_)` (crossfades if thumbnail was showing)
- `didFailWithError` → finds cell at index, calls `cell.showError()`

### FliperImageCellDelegate Addition

- `cellDidTapRetry` → looks up index for cell, calls `loadingCoordinator.retry(forItemAt:)`, calls `cell.showLoading()`

### Cell Reuse Handling

- In `cellForItemAt`, before configuring the cell for the new index, call `loadingCoordinator.cancelLoading(forItemAt:)` with the old index (the cell may have been reused from a different index)
- Track the current loading index per cell to know what to cancel

### Dismiss Cleanup

- `dismissViewer` calls `loadingCoordinator.cancelAll()`

## SwiftUI Integration Changes

### New API

```swift
extension View {
    public func fliperViewer(
        selectedIndex: Binding<Int?>,
        items: [FliperViewerItem],
        imageLoader: FliperImageLoader? = nil
    ) -> some View
}
```

### Backward Compatibility

The existing `fliperViewer(selectedIndex:images:)` overload stays. It internally maps `[UIImage]` to `[FliperViewerItem.image]`.

### FliperSwiftUIDataSource Changes

```swift
final class FliperSwiftUIDataSource: FliperViewerDataSource {
    let items: [FliperViewerItem]
    // viewer(_:itemAt:) returns items[index]
}
```

### FliperPresentationCoordinator Changes

Gets an `imageLoader` parameter to pass through to `FliperViewerController`.

## Error Handling Details

- Error state shows: centered "Failed to load image" label (white, secondary font) + "Retry" button (white, bordered)
- Retry triggers the flow: `cell → delegate.cellDidTapRetry → controller → coordinator.retry() → cell.showLoading()`
- If retry also fails, the same error state appears again — no special "multiple failures" state
- For `.imageAndURL` items that fail: the thumbnail remains visible behind a semi-transparent error overlay so the user still sees something useful
- For `.url` items that fail: the cell shows just the error overlay on a black background
