import SwiftUI
import UIKit

// MARK: - Data Source Adapter

public final class FliperSwiftUIDataSource: FliperViewerDataSource {
    public let images: [UIImage]

    public init(images: [UIImage]) {
        self.images = images
    }

    public func numberOfItems(in viewer: FliperViewerController) -> Int {
        images.count
    }

    public func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage {
        images[index]
    }
}

// MARK: - View Modifier

public struct FliperViewerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let images: [UIImage]
    var currentIndex: Int = 0

    public func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _ in
                if isPresented {
                    presentViewer()
                } else {
                    dismissViewer()
                }
            }
    }

    private func presentViewer() {
        guard let presenter = Self.topViewController() else { return }
        let dataSource = FliperSwiftUIDataSource(images: images)
        let viewer = FliperViewerController(dataSource: dataSource, currentIndex: currentIndex)
        viewer.delegate = Self.delegate
        Self.delegate.isPresented = $isPresented
        Self.delegate.presentedViewer = viewer
        presenter.present(viewer, animated: true)
    }

    private func dismissViewer() {
        Self.delegate.presentedViewer?.dismiss(animated: true)
        Self.delegate.presentedViewer = nil
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private static let delegate = Delegate()

    private class Delegate: FliperViewerDelegate {
        var isPresented: Binding<Bool>?
        weak var presentedViewer: FliperViewerController?

        func viewerDidDismiss(_ viewer: FliperViewerController) {
            isPresented?.wrappedValue = false
            presentedViewer = nil
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
