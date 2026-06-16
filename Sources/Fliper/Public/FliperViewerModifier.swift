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
            .onChange(of: isPresented) { _ in
                if isPresented {
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
