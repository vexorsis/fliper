# Fliper SwiftUI Integration Design

## Goal

Make Fliper usable from SwiftUI via a view modifier API that wraps the existing `FliperViewerController`, preserving the custom fade+scale transition and interactive dismiss gesture.

## API

```swift
extension View {
    func fliperViewer(
        isPresented: Binding<Bool>,
        images: [UIImage],
        currentIndex: Int = 0
    ) -> some View
}
```

- `isPresented` — binding controlling presentation. Fliper sets it to `false` on dismiss.
- `images` — array of `UIImage` to display. Empty array means nothing to show.
- `currentIndex` — which image to start on. Defaults to `0`.

## Architecture

One new public file: `Sources/Fliper/Public/FliperViewerModifier.swift` containing three types:

### FliperViewerModifier

A `ViewModifier` that holds `isPresented`, `images`, and `currentIndex`. When `isPresented` is `true`, it renders a `FliperViewerRepresentable` inside a transparent `UIHostingController` overlay added as a child to the root view controller.

### FliperViewerRepresentable

A `UIViewControllerRepresentable` bridging to `FliperViewerController`:

- `makeUIViewController` — creates `FliperViewerController` with a `FliperSwiftUIDataSource`
- `updateUIViewController` — syncs `currentIndex` and `images` changes via `reloadData()`
- Conforms to `FliperViewerDelegate` to set `isPresented = false` on dismiss

### FliperSwiftUIDataSource

A minimal `FliperViewerDataSource` implementation wrapping a `[UIImage]` array.

## Presentation & Lifecycle

**Present** (`isPresented` → `true`):
1. Create `FliperViewerRepresentable`
2. Present via transparent `UIHostingController` added as child to root VC
3. Custom fade+scale transition plays

**User dismisses via gesture**:
1. `FliperViewerController` calls `viewerDidDismiss(_:)` on delegate
2. Representable sets `isPresented = false`
3. Overlay is removed

**External dismiss** (`isPresented` → `false`):
1. Overlay is removed, triggering controller dismissal

**State update while presented** (`images` or `currentIndex` change):
1. `updateUIViewController` calls `reloadData()` and/or updates `currentIndex`

## Scope

- No changes to existing internal UIKit files
- No callbacks (onDismiss, onPageChange, onLongPress) — future enhancement
- UIImage only — no URL-based loading
