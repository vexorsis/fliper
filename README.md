# Fliper

An iOS image viewer library with a Photos-app-style fullscreen browsing experience. Built with UIKit and Swift Package Manager, with SwiftUI integration.

## Features

- Fullscreen horizontally-paged image gallery
- Pinch-to-zoom and double-tap-to-zoom
- Pan-to-dismiss gesture with spring-back animation
- Inter-page spacing between images
- Load images from local `UIImage`, remote `URL`, or thumbnail + remote original
- Loading spinner and error/retry UI for remote images
- Custom fade+scale present/dismiss transition
- Injectable image loader (URLSession, Kingfisher, SDWebImage, etc.)
- Zero third-party dependencies

## Requirements

- iOS 15+
- Swift 5.9+

## Installation

Add Fliper to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/vexorsis/fliper", from: "1.0.0")
]
```

Or add it directly in Xcode: **File > Add Package Dependencies** and paste the repository URL.

## Usage

### UIKit

Create a data source and present the viewer:

```swift
class PhotoDataSource: FliperViewerDataSource {
    private let images: [UIImage]

    func numberOfItems(in viewer: FliperViewerController) -> Int {
        images.count
    }

    func viewer(_ viewer: FliperViewerController, itemAt index: Int) -> FliperViewerItem {
        .image(images[index])
    }
}

let dataSource = PhotoDataSource(images: myImages)
let viewer = FliperViewerController(dataSource: dataSource, startIndex: 0)
viewer.delegate = self
viewer.modalPresentationStyle = .custom
viewer.transitioningDelegate = viewer
present(viewer, animated: true)
```

### SwiftUI

Use the `fliperViewer` view modifier:

```swift
// With local images
@State var selectedIndex: Int?

var body: some View {
    GridView()
        .fliperViewer(selectedIndex: $selectedIndex, images: myImages)
}

// With URL-based images
@State var selectedIndex: Int?

var body: some View {
    GridView()
        .fliperViewer(
            selectedIndex: $selectedIndex,
            items: urlItems,
            imageLoader: MyImageLoader()
        )
}
```

### Image Items

`FliperViewerItem` supports three cases:

```swift
// Local image
.image(uiImage)

// Remote URL
.url(imageURL)

// Thumbnail + remote original (shows thumbnail immediately, loads original in background)
.imageAndURL(thumbnail: thumbnailImage, original: imageURL)
```

### Custom Image Loader

Implement `FliperImageLoader` to load remote images with your preferred networking library:

```swift
class MyImageLoader: FliperImageLoader {
    func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageLoadError.invalidData
        }
        return image
    }
}

let viewer = FliperViewerController(dataSource: dataSource, startIndex: 0, imageLoader: MyImageLoader())
```

### Delegate

Conform to `FliperViewerDelegate` to respond to viewer events:

```swift
extension MyViewController: FliperViewerDelegate {
    func viewer(_ viewer: FliperViewerController, didScrollToIndex index: Int) {
        // Page changed
    }

    func viewer(_ viewer: FliperViewerController, didLongPressImageAt index: Int) {
        // Long press on image
    }

    func viewerDidDismiss(_ viewer: FliperViewerController) {
        // Viewer dismissed
    }
}
```

### Configuration

Customize viewer behavior through properties:

```swift
viewer.maxZoomScale = 5.0          // Maximum zoom scale (default: 5.0)
viewer.doubleTapZoomScale = 2.0    // Double-tap zoom scale (default: 2.0)
viewer.dismissThreshold = 0.25     // Drag ratio to trigger dismiss (default: 0.25)
viewer.interPageSpacing = 20       // Spacing between pages in points (default: 20)
viewer.backgroundColor = .black    // Background color (default: .black)
```

## License

MIT License

Copyright (c) 2026 Peiyan Wang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
