# Fliper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI image viewer library (SPM) with iOS Photos-style hero transition, pinch-zoom, double-tap zoom, horizontal swipe paging, and swipe-to-dismiss.

**Architecture:** Single `FliperViewer` view composed of three internal components — `ZoomContainer` (zoom/pan/double-tap per image), `PagedScroll` (horizontal swipe between images), and `DismissController` (vertical drag to dismiss). Gesture priority is resolved by `ZoomContainer` reporting its current scale upward so `PagedScroll` and `DismissController` only activate at scale 1.0. Hero transitions use `matchedGeometryEffect`.

**Tech Stack:** Swift 5.9, SwiftUI (iOS 16+), no third-party dependencies.

---

### Task 1: Scaffolding — Package.swift and Directory Structure

**Files:**
- Create: `Package.swift`
- Create: `Sources/Fliper/` (directory)

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Fliper",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Fliper", targets: ["Fliper"]),
    ],
    targets: [
        .target(name: "Fliper", path: "Sources/Fliper"),
    ]
)
```

- [ ] **Step 2: Create directory structure**

Run:
```bash
mkdir -p Sources/Fliper/Public Sources/Fliper/Internal Tests/FliperTests
```

- [ ] **Step 3: Create a placeholder source file so the target compiles**

Create `Sources/Fliper/Public/FliperViewer.swift`:
```swift
import SwiftUI

public struct FliperViewer<Content: View>: View {
    public init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        fatalError("Not yet implemented")
    }

    public var body: some View {
        EmptyView()
    }
}
```

- [ ] **Step 4: Verify package builds**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
git init
git add Package.swift Sources/
git commit -m "feat: scaffold Swift package with directory structure"
```

---

### Task 2: ZoomContainer — Pinch Zoom and Pan

**Files:**
- Create: `Sources/Fliper/Internal/ZoomContainer.swift`

`ZoomContainer` wraps a single content view and adds pinch-to-zoom and drag-to-pan gestures. It reports its current scale via a `@Binding<CGFloat>` so parent components can decide whether to activate their own gestures.

- [ ] **Step 1: Implement ZoomContainer**

Create `Sources/Fliper/Internal/ZoomContainer.swift`:
```swift
import SwiftUI

struct ZoomContainer<Content: View>: View {
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    @Binding var currentScale: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var initialScale: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var magnificationScale: CGFloat = 1.0

    init(
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        currentScale: Binding<CGFloat>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self._currentScale = currentScale
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            content()
                .scaleEffect(effectiveScale)
                .offset(effectiveOffset(in: geometry))
                .gesture(magnificationGesture)
                .gesture(dragGesture(in: geometry))
                .gesture(doubleTapGesture)
                .onChangedOfScale { newScale in
                    currentScale = newScale
                }
        }
        .clipped()
    }

    private var effectiveScale: CGFloat {
        let s = scale * magnificationScale
        return min(s, maxScale)
    }

    private func effectiveOffset(in geometry: GeometryProxy) -> CGSize {
        let totalOffset = offset + dragOffset
        if effectiveScale <= 1.0 {
            return .zero
        }
        return boundedOffset(totalOffset, in: geometry)
    }

    private func boundedOffset(_ offset: CGSize, in geometry: GeometryProxy) -> CGSize {
        let scaledWidth = geometry.size.width * effectiveScale
        let scaledHeight = geometry.size.height * effectiveScale
        let extraWidth = max(0, (scaledWidth - geometry.size.width) / 2)
        let extraHeight = max(0, (scaledHeight - geometry.size.height) / 2)
        return CGSize(
            width: min(extraWidth, max(-extraWidth, offset.width)),
            height: min(extraHeight, max(-extraHeight, offset.height))
        )
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // value is relative to the start of the gesture
            }
            .onEnded { value in
                let newScale = min(scale * value, maxScale)
                scale = newScale
                if scale < 1.0 {
                    withAnimation(.spring()) {
                        scale = 1.0
                        offset = .zero
                    }
                }
            }
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if scale > 1.0 {
                    state = value.translation
                }
            }
            .onEnded { value in
                if scale > 1.0 {
                    offset = boundedOffset(offset + value.translation, in: geometry)
                }
            }
    }

    private var doubleTapGesture: some Gesture {
        SpatialTapGesture(count: 2)
            .onEnded { _ in
                withAnimation(.spring()) {
                    if scale > 1.0 {
                        scale = 1.0
                        offset = .zero
                    } else {
                        scale = doubleTapScale
                    }
                }
            }
    }
}
```

Note: `ZoomContainer` uses `@GestureState` for drag and magnification to get automatic reset on gesture end, and `@State` for persisted scale/offset. The `currentScale` binding reports the effective scale upward.

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/ZoomContainer.swift
git commit -m "feat: add ZoomContainer with pinch-zoom, pan, and double-tap"
```

---

### Task 3: PagedScroll — Horizontal Swipe Paging

**Files:**
- Create: `Sources/Fliper/Internal/PagedScroll.swift`

`PagedScroll` is a custom horizontal paging container. It does NOT use `TabView` (which has poor gesture interop with zoom). Instead it uses `DragGesture` to track horizontal drags and snaps to the nearest page on release. It only activates when the active `ZoomContainer` reports `currentScale == 1.0`.

- [ ] **Step 1: Implement PagedScroll**

Create `Sources/Fliper/Internal/PagedScroll.swift`:
```swift
import SwiftUI

struct PagedScroll<Content: View>: View {
    @Binding var currentIndex: Int
    let itemCount: Int
    let isZoomed: Bool  // reported from the active ZoomContainer
    @ViewBuilder let content: (Int) -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let swipeThreshold: CGFloat = 0.2  // 20% of page width

    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        isZoomed: Bool,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.isZoomed = isZoomed
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = geometry.size.width

            HStack(spacing: 0) {
                ForEach(0..<itemCount, id: \.self) { index in
                    content(index)
                        .frame(width: pageWidth, height: geometry.size.height)
                }
            }
            .offset(x: pageOffset(in: geometry))
            .gesture(dragGesture(in: geometry))
            .animation(isDragging ? .none : .spring(), value: currentIndex)
            .animation(isDragging ? .none : .spring(), value: dragOffset)
        }
    }

    private func pageOffset(in geometry: GeometryProxy) -> CGFloat {
        let pageWidth = geometry.size.width
        let baseOffset = -CGFloat(currentIndex) * pageWidth
        let elasticDrag = elasticDragOffset(in: geometry)
        return baseOffset + elasticDrag
    }

    private func elasticDragOffset(in geometry: GeometryProxy) -> CGFloat {
        let proposed = dragOffset
        let pageWidth = geometry.size.width

        // At boundaries, apply rubber-band resistance
        let atStart = currentIndex == 0 && proposed > 0
        let atEnd = currentIndex == itemCount - 1 && proposed < 0

        if atStart || atEnd {
            return proposed * 0.3
        }
        return proposed
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isZoomed else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                guard !isZoomed else { return }
                isDragging = false
                let pageWidth = geometry.size.width
                let threshold = pageWidth * swipeThreshold

                withAnimation(.spring()) {
                    if value.translation.width < -threshold && currentIndex < itemCount - 1 {
                        currentIndex += 1
                    } else if value.translation.width > threshold && currentIndex > 0 {
                        currentIndex -= 1
                    }
                    dragOffset = 0
                }
            }
    }
}
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/PagedScroll.swift
git commit -m "feat: add PagedScroll with horizontal swipe paging"
```

---

### Task 4: DismissController — Vertical Drag to Dismiss

**Files:**
- Create: `Sources/Fliper/Internal/DismissController.swift`

`DismissController` is a modifier that adds vertical-drag-to-dismiss behavior. It only activates when the active `ZoomContainer` reports `currentScale == 1.0`. As the user drags down, the content scales down proportionally and the background fades. Releasing past the threshold triggers dismissal.

- [ ] **Step 1: Implement DismissController**

Create `Sources/Fliper/Internal/DismissController.swift`:
```swift
import SwiftUI

struct DismissController: ViewModifier {
    let isZoomed: Bool
    let dismissThreshold: CGFloat  // fraction of screen height
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .scaleEffect(dismissScale)
                .offset(y: isZoomed ? 0 : dragOffset)
                .gesture(isZoomed ? nil : dragGesture(in: geometry))
        }
    }

    private var dismissScale: CGFloat {
        guard !isZoomed else { return 1.0 }
        let progress = abs(dragOffset) / 1000
        return max(0.5, 1.0 - progress * 0.5)
    }

    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard value.translation.height > 0 else { return }  // only downward
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                isDragging = true
                dragOffset = value.translation.height
            }
            .onEnded { value in
                isDragging = false
                let screenHeight = geometry.size.height
                if value.translation.height > screenHeight * dismissThreshold {
                    withAnimation(.spring()) {
                        onDismiss()
                    }
                } else {
                    withAnimation(.spring()) {
                        dragOffset = 0
                    }
                }
            }
    }
}
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/DismissController.swift
git commit -m "feat: add DismissController with vertical drag-to-dismiss"
```

---

### Task 5: TransitionCoordinator — Matched Geometry and Presentation Logic

**Files:**
- Create: `Sources/Fliper/Internal/TransitionCoordinator.swift`

`TransitionCoordinator` manages the `matchedGeometryEffect` IDs, tracks the initial index for reverse transitions, and detects whether the target thumbnail is offscreen (fallback to fade transition).

- [ ] **Step 1: Implement TransitionCoordinator**

Create `Sources/Fliper/Internal/TransitionCoordinator.swift`:
```swift
import SwiftUI

struct TransitionCoordinator {
    let namespace: Namespace.ID
    let startIndex: Int

    func matchedGeometryID(for index: Int) -> String {
        "fliper-\(index)"
    }

    func shouldUseHeroTransition(for index: Int, thumbnailVisible: Bool) -> Bool {
        thumbnailVisible
    }
}
```

This is intentionally minimal — the real hero transition logic lives in `FliperViewer` and `FliperThumbnail` where the `matchedGeometryEffect` modifier is applied. `TransitionCoordinator` just provides the ID scheme and a helper for the offscreen fallback decision.

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Internal/TransitionCoordinator.swift
git commit -m "feat: add TransitionCoordinator for matched geometry ID management"
```

---

### Task 6: FliperViewer — Public Orchestrator

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewer.swift`

Wire together `ZoomContainer`, `PagedScroll`, and `DismissController` into the public `FliperViewer` view. Apply `matchedGeometryEffect` to the fullscreen image content. Manage the `selection` binding and presentation state.

- [ ] **Step 1: Implement FliperViewer**

Replace the placeholder in `Sources/Fliper/Public/FliperViewer.swift` with:

```swift
import SwiftUI

public struct FliperViewer<Content: View>: View {
    @Binding var selection: Int
    let namespace: Namespace.ID
    let itemCount: Int
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    let dismissThreshold: CGFloat
    let backgroundColor: Color
    let content: (Int) -> Content

    @State private var currentZoomScale: CGFloat = 1.0
    @State private var startIndex: Int = 0

    public init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._selection = selection
        self.namespace = namespace
        self.itemCount = itemCount
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self.dismissThreshold = dismissThreshold
        self.backgroundColor = backgroundColor
        self.content = content
    }

    public var body: some View {
        backgroundColor
            .ignoresSafeArea()
            .overlay(
                PagedScroll(
                    currentIndex: $selection,
                    itemCount: itemCount,
                    isZoomed: currentZoomScale > 1.0
                ) { index in
                    ZoomContainer(
                        maxScale: maxScale,
                        doubleTapScale: doubleTapScale,
                        currentScale: zoomScaleBinding(for: index)
                    ) {
                        content(index)
                            .matchedGeometryEffect(
                                id: "fliper-\(index)",
                                in: namespace
                            )
                    }
                }
                .modifier(DismissController(
                    isZoomed: currentZoomScale > 1.0,
                    dismissThreshold: dismissThreshold,
                    onDismiss: {
                        // Dismiss handled by parent via isPresented binding
                    }
                ))
            )
            .onAppear {
                startIndex = selection
            }
    }

    private func zoomScaleBinding(for index: Int) -> Binding<CGFloat> {
        Binding(
            get: { selection == index ? currentZoomScale : 1.0 },
            set: { newValue in
                if selection == index {
                    currentZoomScale = newValue
                }
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
git add Sources/Fliper/Public/FliperViewer.swift
git commit -m "feat: implement FliperViewer orchestrating zoom, paging, and dismiss"
```

---

### Task 7: FliperThumbnail — Public Thumbnail Wrapper

**Files:**
- Create: `Sources/Fliper/Public/FliperThumbnail.swift`

`FliperThumbnail` wraps a thumbnail view, applies `matchedGeometryEffect`, and handles the tap-to-present flow.

- [ ] **Step 1: Implement FliperThumbnail**

Create `Sources/Fliper/Public/FliperThumbnail.swift`:
```swift
import SwiftUI

public struct FliperThumbnail<Content: View>: View {
    let index: Int
    let namespace: Namespace.ID
    @Binding var isPresented: Bool
    let content: () -> Content

    public init(
        index: Int,
        namespace: Namespace.ID,
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.index = index
        self.namespace = namespace
        self._isPresented = isPresented
        self.content = content
    }

    public var body: some View {
        content()
            .matchedGeometryEffect(id: "fliper-\(index)", in: namespace)
            .onTapGesture {
                withAnimation(.spring()) {
                    isPresented = true
                }
            }
    }
}
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperThumbnail.swift
git commit -m "feat: add FliperThumbnail with matched geometry and tap-to-present"
```

---

### Task 8: Fix ZoomContainer — MagnificationGesture Scale Tracking

**Files:**
- Modify: `Sources/Fliper/Internal/ZoomContainer.swift`

The initial `ZoomContainer` implementation has a bug: `MagnificationGesture` provides a relative scale from the gesture start, but the `onChanged` doesn't use it. The `magnificationScale` `@GestureState` needs to track the live magnification value during the gesture, and `scale` needs to be updated on `onEnded`.

- [ ] **Step 1: Fix magnification gesture to properly track scale**

Replace the magnification gesture and related state in `ZoomContainer.swift`. The `@GestureState private var magnificationScale` should be used with `.updating()` to track the live pinch value, and `scale` should only be updated on `onEnded`:

```swift
// Replace the magnificationGesture computed property with:
private var magnificationGesture: some Gesture {
    MagnificationGesture()
        .updating($magnificationScale) { value, state, _ in
            state = value
        }
        .onEnded { value in
            let newScale = min(scale * value, maxScale)
            if newScale < 1.0 {
                withAnimation(.spring()) {
                    scale = 1.0
                    offset = .zero
                }
            } else {
                scale = newScale
            }
        }
}
```

Also remove the unused `initialScale` state property.

- [ ] **Step 2: Remove the `.onChangedOfScale` modifier (doesn't exist in SwiftUI)**

Replace the `.onChangedOfScale` call with an `.onChange(of:)` modifier on the `scale` state:

```swift
// Replace .onChangedOfScale with this, added after .clipped():
.onChange(of: effectiveScale) { newScale in
    currentScale = newScale
}
```

- [ ] **Step 3: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/Fliper/Internal/ZoomContainer.swift
git commit -m "fix: correct MagnificationGesture scale tracking in ZoomContainer"
```

---

### Task 9: Demo App — Manual Testing Harness

**Files:**
- Create: `Demo/FliperDemo/FliperDemoApp.swift`
- Create: `Demo/FliperDemo/ContentView.swift`

A minimal demo app for manual testing of the full flow: thumbnail grid → tap → fullscreen viewer with all gestures.

- [ ] **Step 1: Create the demo app entry point**

Create `Demo/FliperDemo/FliperDemoApp.swift`:
```swift
import SwiftUI

@main
struct FliperDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 2: Create the demo content view**

Create `Demo/FliperDemo/ContentView.swift`:
```swift
import SwiftUI
import Fliper

struct ContentView: View {
    @Namespace private var namespace
    @State private var selectedIndex: Int = 0
    @State private var isPresented: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    private let imageNames = (1...12).map { "photo\($0)" }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<imageNames.count, id: \.self) { index in
                    FliperThumbnail(
                        index: index,
                        namespace: namespace,
                        isPresented: $isPresented
                    ) {
                        Image(imageNames[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .clipped()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            FliperViewer(
                selection: $selectedIndex,
                namespace: namespace,
                itemCount: imageNames.count
            ) { index in
                Image(imageNames[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onChange(of: isPresented) { presented in
            if !presented {
                // Reset selection when dismissed if needed
            }
        }
    }
}
```

Note: This demo requires actual image assets named "photo1" through "photo12" in the asset catalog. The developer can substitute with SF Symbols or other assets for testing.

- [ ] **Step 3: Commit**

```bash
git add Demo/
git commit -m "feat: add demo app for manual testing"
```

---

### Task 10: Gesture Conflict Resolution — Integrate Scale Reporting

**Files:**
- Modify: `Sources/Fliper/Internal/PagedScroll.swift`
- Modify: `Sources/Fliper/Internal/DismissController.swift`
- Modify: `Sources/Fliper/Public/FliperViewer.swift`

The current implementation uses `isZoomed: Bool` for gesture gating. This needs to be changed to use the actual `currentScale` value from `ZoomContainer` so the gesture priority is precise and real-time. Also, `PagedScroll` and `DismissController` currently have independent `DragGesture` recognizers that will conflict — they need to be composed into a single gesture that routes horizontal vs. vertical drags.

- [ ] **Step 1: Add a unified gesture handler in FliperViewer**

Add a `DragGesture` at the `FliperViewer` level that determines whether a drag is horizontal (→ PagedScroll) or vertical (→ DismissController). This replaces the separate drag gestures in those components.

In `FliperViewer.swift`, add state and gesture routing:

```swift
// Add these state properties:
@State private var viewerDragOffset: CGSize = .zero
@GestureState private var gestureDragOffset: CGSize = .zero

// Add this computed property:
private var isZoomed: Bool {
    currentZoomScale > 1.0
}
```

- [ ] **Step 2: Update PagedScroll to receive drag state instead of owning its own gesture**

Replace the `dragGesture` in `PagedScroll.swift` with external binding control:

```swift
struct PagedScroll<Content: View>: View {
    @Binding var currentIndex: Int
    let itemCount: Int
    let isZoomed: Bool
    let externalDragOffset: CGFloat  // horizontal component from parent
    let isDragging: Bool
    @ViewBuilder let content: (Int) -> Content

    private let swipeThreshold: CGFloat = 0.2

    init(
        currentIndex: Binding<Int>,
        itemCount: Int,
        isZoomed: Bool,
        externalDragOffset: CGFloat = 0,
        isDragging: Bool = false,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._currentIndex = currentIndex
        self.itemCount = itemCount
        self.isZoomed = isZoomed
        self.externalDragOffset = externalDragOffset
        self.isDragging = isDragging
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let pageWidth = geometry.size.width

            HStack(spacing: 0) {
                ForEach(0..<itemCount, id: \.self) { index in
                    content(index)
                        .frame(width: pageWidth, height: geometry.size.height)
                }
            }
            .offset(x: pageOffset(in: geometry))
            .animation(isDragging ? .none : .spring(), value: currentIndex)
        }
    }

    private func pageOffset(in geometry: GeometryProxy) -> CGFloat {
        let pageWidth = geometry.size.width
        let baseOffset = -CGFloat(currentIndex) * pageWidth
        let proposed = isZoomed ? 0 : externalDragOffset
        let atStart = currentIndex == 0 && proposed > 0
        let atEnd = currentIndex == itemCount - 1 && proposed < 0
        let elastic = (atStart || atEnd) ? proposed * 0.3 : proposed
        return baseOffset + elastic
    }
}
```

Remove the `@State private var dragOffset` and `@State private var isDragging` and `dragGesture` from `PagedScroll` — they are now managed by `FliperViewer`.

- [ ] **Step 3: Update DismissController to receive drag state similarly**

Replace the internal drag gesture in `DismissController.swift`:

```swift
struct DismissController: ViewModifier {
    let isZoomed: Bool
    let dismissThreshold: CGFloat
    let verticalDragOffset: CGFloat
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        content
            .scaleEffect(dismissScale)
            .offset(y: isZoomed ? 0 : verticalDragOffset)
    }

    private var dismissScale: CGFloat {
        guard !isZoomed else { return 1.0 }
        let progress = abs(verticalDragOffset) / 1000
        return max(0.5, 1.0 - progress * 0.5)
    }
}
```

- [ ] **Step 4: Add the unified drag gesture to FliperViewer**

In `FliperViewer.swift`, add a single `DragGesture` that routes to horizontal (paging) or vertical (dismiss):

```swift
// Add to FliperViewer body, wrapping the PagedScroll overlay:
.gesture(
    DragGesture(minimumDistance: 10)
        .updating($gestureDragOffset) { value, state, _ in
            if currentZoomScale <= 1.0 {
                state = value.translation
            }
        }
        .onChanged { value in
            guard currentZoomScale <= 1.0 else { return }
            viewerDragOffset = value.translation
        }
        .onEnded { value in
            let screenHeight = UIScreen.main.bounds.height
            let screenWidth = UIScreen.main.bounds.width

            if value.translation.height > screenHeight * dismissThreshold {
                withAnimation(.spring()) {
                    // Trigger dismiss — parent handles via isPresented
                }
            } else if abs(value.translation.width) > abs(value.translation.height) {
                // Horizontal swipe — update page
                let threshold = screenWidth * 0.2
                withAnimation(.spring()) {
                    if value.translation.width < -threshold && selection < itemCount - 1 {
                        selection += 1
                    } else if value.translation.width > threshold && selection > 0 {
                        selection -= 1
                    }
                }
            }

            withAnimation(.spring()) {
                viewerDragOffset = .zero
            }
        }
)
```

Update the `PagedScroll` and `DismissController` call sites in `FliperViewer` to pass the new parameters:

```swift
PagedScroll(
    currentIndex: $selection,
    itemCount: itemCount,
    isZoomed: currentZoomScale > 1.0,
    externalDragOffset: viewerDragOffset.width,
    isDragging: viewerDragOffset != .zero
) { ... }
.modifier(DismissController(
    isZoomed: currentZoomScale > 1.0,
    dismissThreshold: dismissThreshold,
    verticalDragOffset: viewerDragOffset.height
) {
    // onDismiss
})
```

- [ ] **Step 5: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sources/Fliper/
git commit -m "feat: unified gesture routing for zoom, paging, and dismiss"
```

---

### Task 11: Background Fade on Dismiss

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewer.swift`

The background should fade from opaque black to transparent as the user drags down to dismiss, proportional to the dismiss progress.

- [ ] **Step 1: Add background opacity based on dismiss progress**

In `FliperViewer.swift`, compute background opacity from the vertical drag offset:

```swift
// Add computed property:
private var backgroundOpacity: Double {
    guard viewerDragOffset.height > 0 else { return 1.0 }
    let progress = min(1.0, viewerDragOffset.height / UIScreen.main.bounds.height)
    return 1.0 - progress
}
```

Replace `backgroundColor` in the body with:

```swift
backgroundColor.opacity(backgroundOpacity)
    .ignoresSafeArea()
```

- [ ] **Step 2: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewer.swift
git commit -m "feat: background fade proportional to dismiss drag progress"
```

---

### Task 12: Dismiss Callback — Wire isPresented Binding

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewer.swift`
- Modify: `Sources/Fliper/Public/FliperThumbnail.swift`

The `FliperViewer` currently has no way to signal dismissal back to the parent. Add an `onDismiss` callback or use the `isPresented` pattern so the `fullScreenCover` closes.

- [ ] **Step 1: Add onDismiss callback to FliperViewer**

Add an `onDismiss` closure parameter to `FliperViewer`:

```swift
public struct FliperViewer<Content: View>: View {
    @Binding var selection: Int
    let namespace: Namespace.ID
    let itemCount: Int
    let maxScale: CGFloat
    let doubleTapScale: CGFloat
    let dismissThreshold: CGFloat
    let backgroundColor: Color
    let onDismiss: () -> Void
    let content: (Int) -> Content

    public init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        onDismiss: @escaping () -> Void = {},
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        self._selection = selection
        self.namespace = namespace
        self.itemCount = itemCount
        self.maxScale = maxScale
        self.doubleTapScale = doubleTapScale
        self.dismissThreshold = dismissThreshold
        self.backgroundColor = backgroundColor
        self.onDismiss = onDismiss
        self.content = content
    }
    // ...
}
```

- [ ] **Step 2: Call onDismiss when swipe-to-dismiss threshold is crossed**

In the `DragGesture.onEnded` in `FliperViewer`, replace the dismiss comment with:

```swift
if value.translation.height > screenHeight * dismissThreshold {
    onDismiss()
    return
}
```

- [ ] **Step 3: Update demo to use onDismiss**

In `Demo/FliperDemo/ContentView.swift`, update the `FliperViewer` usage:

```swift
FliperViewer(
    selection: $selectedIndex,
    namespace: namespace,
    itemCount: imageNames.count,
    onDismiss: {
        isPresented = false
    }
) { index in
    Image(imageNames[index])
        .resizable()
        .aspectRatio(contentMode: .fit)
}
```

- [ ] **Step 4: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/Fliper/Public/FliperViewer.swift Sources/Fliper/Public/FliperThumbnail.swift Demo/FliperDemo/ContentView.swift
git commit -m "feat: wire onDismiss callback for swipe-to-dismiss"
```

---

### Task 13: Polish — Reset Zoom on Page Change and Spring Animations

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewer.swift`
- Modify: `Sources/Fliper/Internal/ZoomContainer.swift`

When the user swipes to a different image, the previous image's zoom should reset. Also ensure all animations use consistent spring parameters.

- [ ] **Step 1: Reset zoom scale when selection changes**

In `FliperViewer.swift`, add:

```swift
.onChange(of: selection) { _ in
    withAnimation(.spring()) {
        currentZoomScale = 1.0
    }
}
```

- [ ] **Step 2: Add resetZoom method to ZoomContainer**

Add a method to `ZoomContainer` that can be called externally:

```swift
// In ZoomContainer, add:
func resetZoom() {
    withAnimation(.spring()) {
        scale = 1.0
        offset = .zero
    }
}
```

Since `ZoomContainer` is used inside `PagedScroll`'s content closure, the reset is handled by the `currentScale` binding going to 1.0 from the `FliperViewer` `onChange`.

- [ ] **Step 3: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/Fliper/
git commit -m "feat: reset zoom on page change with consistent spring animations"
```

---

### Task 14: Demo App Xcode Project

**Files:**
- Create: `Demo/FliperDemo/Assets.xcassets/` with placeholder images
- Create: `Demo/FliperDemo/Info.plist`

Create an actual Xcode project for the demo app so it can be opened and run in Xcode or simulator.

- [ ] **Step 1: Generate Xcode project for the package**

Run:
```bash
swift package generate-xcodeproj
```

If that's not available (modern SPM), instead open the package directly:
```bash
open Package.swift
```

- [ ] **Step 2: Create an Xcode project for the demo app**

Use Xcode to create a new iOS App project in `Demo/FliperDemo/` that imports the Fliper package via local dependency. Alternatively, create the project file manually.

For the demo to work, add the Fliper package as a local dependency. In the demo project's `Package.resolved` or Xcode settings, point to the root `Package.swift`.

Note: This step is best done interactively in Xcode. The source files are already in place from Task 9.

- [ ] **Step 3: Add sample images to the demo asset catalog**

Add 12 sample photos to `Demo/FliperDemo/Assets.xcassets/` named "photo1" through "photo12". Any images work for testing — the developer can use their own.

- [ ] **Step 4: Build and run the demo in simulator**

Run the demo app in an iOS 16+ simulator and verify:
1. Thumbnails appear in a 3-column grid
2. Tapping a thumbnail opens the viewer with hero transition
3. Pinch-zoom works on the fullscreen image
4. Double-tap toggles zoom in/out
5. Horizontal swipe moves between images
6. Vertical swipe down dismisses the viewer
7. Dismiss animates back to the correct thumbnail

- [ ] **Step 5: Commit**

```bash
git add Demo/
git commit -m "feat: add demo Xcode project with sample images"
```

---

### Task 15: Offscreen Thumbnail Fallback

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewer.swift`

When the target thumbnail for the hero transition is offscreen, `matchedGeometryEffect` won't animate. Detect this and fall back to a simple fade+scale transition.

- [ ] **Step 1: Add transition fallback state**

In `FliperViewer.swift`, add state to track whether the hero transition should be used:

```swift
@State private var useHeroTransition = true
```

- [ ] **Step 2: Apply conditional transition**

When `useHeroTransition` is false, remove the `matchedGeometryEffect` from the fullscreen content and apply a `.transition(.opacity.combined(with: .scale))` instead. This requires restructuring how `matchedGeometryEffect` is applied:

```swift
// In the content closure passed to ZoomContainer:
let imageContent = content(index)
    .if(useHeroTransition) { view in
        view.matchedGeometryEffect(
            id: "fliper-\(index)",
            in: namespace
        )
    }
```

Note: SwiftUI doesn't have a built-in `.if` modifier. Add a small extension:

```swift
// In a new file Sources/Fliper/Internal/ViewExtensions.swift:
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
```

- [ ] **Step 3: Verify package builds**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/Fliper/
git commit -m "feat: offscreen thumbnail fallback with fade+scale transition"
```

---

### Task 16: Final Integration Test and Polish

**Files:**
- All files

Full manual testing pass to verify all features work together correctly. Fix any gesture conflicts, animation jank, or visual issues found.

- [ ] **Step 1: Test the complete flow in simulator**

Run through this checklist:
1. Thumbnail grid renders correctly
2. Tap thumbnail → hero transition to fullscreen
3. Pinch zoom: scale follows fingers, spring-back at boundaries
4. Double-tap zoom in → animates to 2x
5. Double-tap zoom out → animates back to 1x
6. Pan while zoomed: image follows finger, bounded at edges
7. Swipe between images at scale 1.0: smooth page snap
8. Swipe while zoomed: pans image, does not change page
9. Swipe past first/last image: elastic bounce
10. Drag down to dismiss: image shrinks, background fades, spring back if released early
11. Drag down past threshold: dismiss with hero transition back to thumbnail
12. Navigate to different image, dismiss: hero transition targets the new image's thumbnail
13. Scroll thumbnail grid so target is offscreen, dismiss: fallback fade transition

- [ ] **Step 2: Fix any issues found during testing**

Address each issue found in Step 1. Common areas:
- Gesture conflict between zoom drag and page swipe
- Animation timing mismatches
- `matchedGeometryEffect` not animating when source view isn't visible

- [ ] **Step 3: Verify package builds clean**

Run: `swift build`
Expected: Build succeeds with no warnings.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: integration test polish and gesture conflict resolution"
```
