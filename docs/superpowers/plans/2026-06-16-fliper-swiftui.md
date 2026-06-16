# Fliper SwiftUI Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a SwiftUI view modifier API that wraps FliperViewerController, preserving the custom fade+scale transition and interactive dismiss gesture.

**Architecture:** A `ViewModifier` that presents `FliperViewerController` directly via the UIKit presentation system (not `fullScreenCover`), which preserves the custom `modalPresentationStyle = .custom` transition. A small `FliperSwiftUIDataSource` adapts `[UIImage]` to `FliperViewerDataSource`. A nested `SharedDelegate` class conforms to `FliperViewerDelegate` to sync dismiss state back to the SwiftUI binding.

**Tech Stack:** Swift 5.9, UIKit, SwiftUI (iOS 15+)

---

### Task 1: Create FliperViewerModifier with direct UIKit presentation

**Files:**
- Create: `Sources/Fliper/Public/FliperViewerModifier.swift`

The file contains four types:
1. `FliperSwiftUIDataSource` — adapts `[UIImage]` to `FliperViewerDataSource`
2. `FliperViewerModifier` — `ViewModifier` that uses `onChange(of: isPresented)` to present/dismiss `FliperViewerController` directly via UIKit
3. `FliperViewerModifier.SharedDelegate` — nested class conforming to `FliperViewerDelegate`, syncs dismiss back to the `isPresented` binding
4. `View` extension — convenience method `.fliperViewer(...)`

We use direct UIKit presentation (not `fullScreenCover`) because `fullScreenCover` ignores `modalPresentationStyle = .custom` and would lose the fade+scale transition.

- [ ] **Step 1: Write the implementation**

```swift
import SwiftUI
import UIKit

// MARK: - Data Source Adapter

final class FliperSwiftUIDataSource: FliperViewerDataSource {
    let images: [UIImage]

    init(images: [UIImage]) {
        self.images = images
    }

    func numberOfItems(in viewer: FliperViewerController) -> Int {
        images.count
    }

    func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage {
        images[index]
    }
}

// MARK: - View Modifier

struct FliperViewerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let images: [UIImage]
    var currentIndex: Int = 0

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { newValue in
                if newValue {
                    presentViewer()
                } else {
                    dismissViewer()
                }
            }
    }

    private func presentViewer() {
        guard let rootVC = Self.rootViewController() else { return }
        let dataSource = FliperSwiftUIDataSource(images: images)
        let viewer = FliperViewerController(dataSource: dataSource, currentIndex: currentIndex)
        viewer.delegate = Self.SharedDelegate.shared
        Self.SharedDelegate.shared.isPresented = $isPresented
        rootVC.present(viewer, animated: true)
    }

    private func dismissViewer() {
        guard let rootVC = Self.rootViewController() else { return }
        rootVC.dismiss(animated: true)
    }

    private static func rootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        return root
    }

    private class SharedDelegate: FliperViewerDelegate {
        static let shared = SharedDelegate()
        var isPresented: Binding<Bool>?

        func viewerDidDismiss(_ viewer: FliperViewerController) {
            isPresented?.wrappedValue = false
        }
    }
}

// MARK: - View Extension

extension View {
    public func fliperViewer(
        isPresented: Binding<Bool>,
        images: [UIImage],
        currentIndex: Int = 0
    ) -> some View {
        modifier(FliperViewerModifier(
            isPresented: isPresented,
            images: images,
            currentIndex: currentIndex
        ))
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/peiyan_wang/Workspace/fliper && swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/Fliper/Public/FliperViewerModifier.swift
git commit -m "feat: add SwiftUI view modifier API for FliperViewerController"
```

---

### Task 2: Update demo app to use the new SwiftUI API

**Files:**
- Modify: `Demo/FliperDemo/FliperDemo/ContentView.swift`

Replace the manual `FliperViewerWrapper` + `FliperDemoDataSource` with the new `.fliperViewer()` modifier. Pre-load the images from asset names into `[UIImage]` so the modifier can accept them.

- [ ] **Step 1: Rewrite ContentView.swift**

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

    private var images: [UIImage] {
        imageNames.compactMap { UIImage(named: $0) }
    }

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
        .fliperViewer(isPresented: $isPresented, images: images, currentIndex: selectedIndex)
    }
}
```

- [ ] **Step 2: Build demo app to verify compilation**

Run: `cd /Users/peiyan_wang/Workspace/fliper && xcodebuild -scheme FliperDemo -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Demo/FliperDemo/FliperDemo/ContentView.swift
git commit -m "feat: update demo to use .fliperViewer() modifier API"
```
