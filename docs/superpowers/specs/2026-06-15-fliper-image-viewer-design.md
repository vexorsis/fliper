# Fliper — SwiftUI Image Viewer Library

A SwiftUI library that provides an iOS Photos-style fullscreen image viewer with hero transition, pinch-zoom, double-tap zoom, horizontal swipe paging, and swipe-to-dismiss.

## Overview

- **Package type:** Swift Package (SPM)
- **Platform:** iOS 16+
- **Swift version:** 5.9+
- **Dependencies:** None
- **Scope:** Fullscreen viewer only — no thumbnail grid

## Public API

### FliperViewer

The core fullscreen viewer component.

```swift
struct FliperViewer<Content: View>: View {
    init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping (Int) -> Content
    )
}
```

- `selection` — binding to the currently visible image index, synced bidirectionally
- `namespace` — shared `Namespace.ID` for matched geometry hero transition
- `itemCount` — total number of images in the gallery
- `onDismiss` — called when the viewer is dismissed via swipe-to-dismiss
- `content` — `@ViewBuilder` closure that returns the view for a given index (user provides their own image loading)

### FliperThumbnail

A wrapper for thumbnail views that participates in the hero transition.

```swift
struct FliperThumbnail<Content: View>: View {
    init(
        index: Int,
        namespace: Namespace.ID,
        isPresented: Binding<Bool>,
        selection: Binding<Int>,
        @ViewBuilder content: @escaping () -> Content
    )
}

```

- `index` — the image index this thumbnail represents
- `namespace` — same namespace passed to `FliperViewer`
- `isPresented` — binding that triggers the viewer when set to true
- `selection` — binding to the current image index; set to `index` on tap so the viewer opens to the correct image
- `content` — the thumbnail view (typically a small `Image`)

### Usage Flow

1. User builds their own thumbnail grid, wrapping each thumbnail in `FliperThumbnail` with a shared `@Namespace`
2. Tapping a thumbnail sets `isPresented = true`
3. `FliperViewer` presents fullscreen with hero transition from the tapped thumbnail
4. User can zoom, pan, swipe between images, and swipe down to dismiss
5. `selection` binding stays synced so the caller knows which image is current
6. On dismiss, the hero transition animates back to the thumbnail of the current image

## Gesture System

Three gestures coexist with priority-based conflict resolution:

### Zoom (MagnificationGesture + DragGesture for pan)
- Pinch to zoom in/out, centered on the pinch point
- When zoomed in, single-finger drag pans the image
- Spring-back animation when released while over-zoomed
- Min scale: 1.0 (fit to screen), Max scale: configurable (default 5x)

### Horizontal Swipe (DragGesture)
- When at scale 1.0: horizontal swipe moves to next/previous image
- When zoomed in: horizontal drag pans the image; swipe only activates when the image edge is reached
- Threshold-based: drag exceeding 20% of page width snaps to next/previous page; less than that snaps back

### Dismiss (Vertical DragGesture)
- Only active when scale == 1.0
- Dragging down scales the image down and fades the background proportionally
- Release past `dismissThreshold` (default 25% of screen height) → dismiss
- Release below threshold → spring back to fullscreen

### Double-Tap
- Toggles between scale 1.0 and `doubleTapScale` (default 2x)
- Animated with a spring transition

### Priority Resolution
1. Zoomed in → drag always pans the image, never swipes pages or dismisses
2. Scale 1.0 → vertical drag = dismiss, horizontal drag = swipe pages
3. Double-tap always works regardless of zoom state

## Hero Transition

Uses SwiftUI's `matchedGeometryEffect` for the thumbnail-to-fullscreen animation.

### Opening
1. Each thumbnail has `matchedGeometryEffect(id: "fliper-\(index)", namespace: namespace)`
2. The fullscreen image in `FliperViewer` uses the same ID
3. When `isPresented` becomes true, SwiftUI animates the image from the thumbnail's frame/position to the fullscreen frame
4. Background fades from transparent to black simultaneously

### Closing
1. On dismiss, the reverse animation plays — image animates back to the thumbnail's position
2. If the user swiped to a different image than the starting one, the transition targets that image's thumbnail

### Offscreen Thumbnail Fallback
- If the target thumbnail is scrolled offscreen (not in the view hierarchy), matched geometry effect cannot find it
- Fallback: simple fade + scale transition
- The library detects this by checking whether the thumbnail view is actively rendered

## Internal Architecture

### ZoomContainer
Wraps a single image view. Responsibilities:
- `MagnificationGesture` for pinch zoom
- `DragGesture` for pan (only when zoomed)
- `SpatialTapGesture` for double-tap zoom toggle
- Manages `currentScale`, `offset`, and spring-back animations
- Reports current scale to parent for gesture priority decisions

### PagedScroll
Horizontal paging container. Responsibilities:
- Custom scroll using `DragGesture` + offset animation (not `TabView` — poor gesture interop with zoom)
- Manages current page index and snap animations
- Only responds to horizontal drag when the active `ZoomContainer` reports scale == 1.0
- Pre-renders adjacent pages for smooth transitions
- At first/last image: elastic bounce resistance (no overscroll to a blank page)

### DismissController
Vertical drag dismiss handler. Responsibilities:
- Monitors vertical drag when scale == 1.0
- Computes dismiss progress (0–1) based on drag distance
- Scales image down and fades background proportionally
- Triggers dismiss callback when progress crosses threshold

### FliperViewer (Orchestrator)
The public-facing component. Responsibilities:
- Composes ZoomContainer, PagedScroll, and DismissController
- Owns the `matchedGeometryEffect` connections
- Manages presentation state and the `selection` binding
- Provides the background that fades during dismiss

### Data Flow
`FliperViewer` → `PagedScroll` (which page) → `ZoomContainer` (zoom state) → reports scale back up to `PagedScroll` and `DismissController` so they know when to activate.

## Package Structure

```
Fliper/
├── Package.swift
├── Sources/
│   └── Fliper/
│       ├── Public/
│       │   ├── FliperViewer.swift
│       │   └── FliperThumbnail.swift
│       └── Internal/
│           ├── ZoomContainer.swift
│           ├── PagedScroll.swift
│           ├── DismissController.swift
│           └── TransitionCoordinator.swift
├── Tests/
│   └── FliperTests/
└── Demo/
    └── FliperDemo/
```

## Configuration

Direct parameters on `FliperViewer` init — no configuration struct:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `maxScale` | CGFloat | 5.0 | Maximum zoom level |
| `doubleTapScale` | CGFloat | 2.0 | Scale on double-tap |
| `dismissThreshold` | CGFloat | 0.25 | Fraction of screen height to drag before dismissing |
| `backgroundColor` | Color | .black | Background color behind the image |
