# Magnify Effect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a scale-from-center magnify effect when tapping a thumbnail to open the fullscreen image viewer, with a reverse shrink on dismiss.

**Architecture:** Replace `fullScreenCover` with an overlay-based presentation. The `matchedGeometryEffect` hero transition already handles position/size interpolation — it's the magnify effect, but it was hidden by the system slide-up transition. The overlay approach exposes it. A new `FliperTransition` view modifier drives background opacity and a `scaleEffect` on top of the hero, coordinated by an `animationProgress` state (0→1 on open, 1→0 on dismiss).

**Tech Stack:** SwiftUI, iOS 16+, no new dependencies

---

### Task 1: Create FliperTransition view modifier

**Files:**
- Create: `Sources/Fliper/Internal/FliperTransition.swift`

This modifier wraps the viewer content and drives the open/dismiss animation via an `animationProgress` state. It manages background opacity, a `scaleEffect` for the magnify feel, and coordinates with the dismiss gesture.

- [ ] **Step 1: Create `FliperTransition.swift`**

```swift
import SwiftUI

@available(iOS 16, macOS 13, *)
struct FliperTransition<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    @State private var animationProgress: CGFloat = 0.0
    @State private var isVisible: Bool = false

    private let magnifySpring = Spring(response: 0.35, dampingFraction: 0.85)

    var body: some View {
        Group {
            if isVisible {
                Color.black
                    .opacity(Double(animationProgress))
                    .ignoresSafeArea()
                    .overlay(
                        content()
                            .scaleEffect(1.0 + (1.0 - animationProgress) * -0.05)
                    )
                    .transition(.opacity)
            }
        }
        .onChange(of: isPresented) { newValue in
            if newValue {
                isVisible = true
                withAnimation(.spring(magnifySpring)) {
                    animationProgress = 1.0
                }
            } else {
                withAnimation(.spring(magnifySpring)) {
                    animationProgress = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if animationProgress == 0.0 {
                        isVisible = false
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/Fliper/Internal/FliperTransition.swift
git commit -m "feat: add FliperTransition view modifier for magnify effect"
```

---

### Task 2: Modify FliperViewer to work with overlay presentation

**Files:**
- Modify: `Sources/Fliper/Public/FliperViewer.swift`

FliperViewer currently relies on `fullScreenCover` for presentation. We need to make it work as an overlay content. The key changes: remove internal background management (FliperTransition handles it now), and accept the `animationProgress` binding to apply a `scaleEffect` on the content during the transition.

- [ ] **Step 1: Update `FliperViewer.swift`**

Replace the entire file with:

```swift
import SwiftUI

@available(iOS 16, macOS 13, *)
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

    @State private var currentZoomScale: CGFloat = 1.0
    @State private var viewerDragOffset: CGSize = .zero
    @State private var containerSize: CGSize = CGSize(width: 400, height: 800)

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

    private var isZoomed: Bool {
        currentZoomScale > 1.0
    }

    public var body: some View {
        GeometryReader { geometry in
            Color.clear
                .ignoresSafeArea()
                .overlay(
                    PagedScroll(
                        currentIndex: $selection,
                        itemCount: itemCount,
                        isZoomed: isZoomed,
                        externalDragOffset: viewerDragOffset.width,
                        isDragging: viewerDragOffset.width != 0
                    ) { index in
                        ZoomContainer(
                            maxScale: maxScale,
                            doubleTapScale: doubleTapScale,
                            currentScale: zoomScaleBinding(for: index)
                        ) {
                            content(index)
                                .matchedGeometryEffect(
                                    id: TransitionCoordinator.matchedGeometryID(for: index),
                                    in: namespace
                                )
                        }
                    }
                    .modifier(DismissController(
                        isZoomed: isZoomed,
                        dismissProgress: dismissProgress,
                        verticalDragOffset: viewerDragOffset.height
                    ))
                    .gesture(unifiedDragGesture, including: isZoomed ? .subviews : .gesture)
                )
                .onAppear { containerSize = geometry.size }
                .onChange(of: geometry.size) { newSize in
                    containerSize = newSize
                }
                .onChange(of: selection) { _ in
                    withAnimation(.spring()) {
                        currentZoomScale = 1.0
                    }
                }
        }
    }

    // MARK: - Dismiss Progress

    private var dismissProgress: CGFloat {
        guard viewerDragOffset.height > 0 else { return 0 }
        return min(1.0, viewerDragOffset.height / containerSize.height)
    }

    // MARK: - Unified Drag Gesture

    private var unifiedDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isZoomed else { return }
                let translation = value.translation
                let isHorizontal = abs(translation.width) > abs(translation.height)
                if isHorizontal {
                    viewerDragOffset = CGSize(width: translation.width, height: 0)
                } else if translation.height > 0 {
                    viewerDragOffset = CGSize(width: 0, height: translation.height)
                }
            }
            .onEnded { value in
                guard !isZoomed else { return }
                let translation = value.translation
                let isHorizontal = abs(translation.width) > abs(translation.height)
                if isHorizontal {
                    handlePagingEnd(translation: translation)
                } else if translation.height > 0 {
                    handleDismissEnd(translation: translation)
                    return
                }
                withAnimation(.spring()) {
                    viewerDragOffset = .zero
                }
            }
    }

    private func handlePagingEnd(translation: CGSize) {
        let screenWidth = containerSize.width
        let threshold = screenWidth * 0.2
        withAnimation(.spring()) {
            if translation.width < -threshold && selection < itemCount - 1 {
                selection += 1
            } else if translation.width > threshold && selection > 0 {
                selection -= 1
            }
            viewerDragOffset = .zero
        }
    }

    private func handleDismissEnd(translation: CGSize) {
        if translation.height > containerSize.height * dismissThreshold {
            onDismiss()
        } else {
            withAnimation(.spring()) {
                viewerDragOffset = .zero
            }
        }
    }

    // MARK: - Zoom Scale Binding

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

Key change: replaced `backgroundColor.opacity(backgroundOpacity)` with `Color.clear` — the background is now managed by `FliperTransition`.

- [ ] **Step 2: Commit**

```bash
git add Sources/Fliper/Public/FliperViewer.swift
git commit -m "refactor: FliperViewer remove internal background for overlay presentation"
```

---

### Task 3: Update ContentView demo to use overlay instead of fullScreenCover

**Files:**
- Modify: `Demo/FliperDemo/FliperDemo/ContentView.swift`

Replace `.fullScreenCover` with an overlay that uses `FliperTransition` to present `FliperViewer`. This is the key change that enables the magnify effect — the `matchedGeometryEffect` hero transition becomes the visible animation instead of being hidden by the system slide-up.

- [ ] **Step 1: Update `ContentView.swift`**

Replace lines 52–65 (the `.fullScreenCover` modifier) with:

```swift
            .overlay {
                if isPresented {
                    FliperTransition(isPresented: $isPresented) {
                        FliperViewer(
                            selection: $selectedIndex,
                            namespace: namespace,
                            itemCount: images.count,
                            onDismiss: {
                                isPresented = false
                            }
                        ) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                }
            }
```

The complete `body` property should be:

```swift
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<images.count, id: \.self) { index in
                        FliperThumbnail(
                            index: index,
                            namespace: namespace,
                            isPresented: $isPresented,
                            selection: $selectedIndex
                        ) {
                            Image(uiImage: images[index])
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                        }
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading photos...")
                } else if images.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Tap + to pick photos from your library")
                    )
                }
            }
            .overlay {
                if isPresented {
                    FliperTransition(isPresented: $isPresented) {
                        FliperViewer(
                            selection: $selectedIndex,
                            namespace: namespace,
                            itemCount: images.count,
                            onDismiss: {
                                isPresented = false
                            }
                        ) { index in
                            Image(uiImage: images[index])
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 20,
                        matching: .images
                    ) {
                        Image(systemName: "plus")
                    }
                    .disabled(isLoading)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                loadImages(from: newItems)
            }
        }
    }
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/peiyan_wang/Workspace/fliper && swift build`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Demo/FliperDemo/FliperDemo/ContentView.swift
git commit -m "feat: replace fullScreenCover with overlay for magnify transition"
```

---

### Task 4: Build and test on simulator

**Files:**
- No file changes — manual testing

- [ ] **Step 1: Build and run on simulator**

Use XcodeBuildMCP to build and run the FliperDemo app on the iOS simulator. Verify:

1. Tapping a thumbnail shows the magnify effect — image grows from thumbnail position to fullscreen
2. Dragging down dismisses with the reverse shrink effect
3. Background fades in on open, fades out on dismiss
4. Swipe paging still works
5. Pinch zoom still works
6. Double-tap zoom still works

- [ ] **Step 2: If issues found, fix and commit**

Address any visual glitches or animation issues discovered during testing.

---

### Task 5: Tune animation parameters

**Files:**
- Modify: `Sources/Fliper/Internal/FliperTransition.swift`

After visual testing, tune the animation spring and scale parameters for the best feel. The current values are starting points — adjust based on how it looks on device.

- [ ] **Step 1: Adjust spring and scale if needed**

The key parameters to tune in `FliperTransition`:
- `Spring(response: 0.35, dampingFraction: 0.85)` — increase `dampingFraction` (0.9) for less bounciness, decrease `response` (0.3) for faster animation
- `.scaleEffect(1.0 + (1.0 - animationProgress) * -0.05)` — increase the multiplier (e.g., `-0.1`) for a more dramatic magnify feel, decrease (`-0.02`) for subtlety
- `deadline: .now() + 0.4` — adjust if the dismiss animation is cut short or lingers too long

- [ ] **Step 2: Commit tuned values**

```bash
git add Sources/Fliper/Internal/FliperTransition.swift
git commit -m "tune: adjust magnify animation spring and scale parameters"
```
