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

// MARK: - Presentation Coordinator

final class FliperPresentationCoordinator: ObservableObject, FliperViewerDelegate {
    var isPresented: Binding<Bool>?
    weak var presentedViewer: FliperViewerController?

    func viewerDidDismiss(_ viewer: FliperViewerController) {
        isPresented?.wrappedValue = false
        presentedViewer = nil
    }

    func present(images: [UIImage], currentIndex: Int, isPresented: Binding<Bool>) {
        guard let presenter = topViewController() else { return }
        let dataSource = FliperSwiftUIDataSource(images: images)
        let viewer = FliperViewerController(dataSource: dataSource, currentIndex: currentIndex)
        viewer.delegate = self
        self.isPresented = isPresented
        self.presentedViewer = viewer
        presenter.present(viewer, animated: true)
    }

    func dismiss() {
        presentedViewer?.dismissViewer()
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - View Modifier

struct FliperViewerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let images: [UIImage]
    var currentIndex: Int = 0
    @StateObject private var coordinator = FliperPresentationCoordinator()

    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _ in
                if isPresented {
                    coordinator.present(images: images, currentIndex: currentIndex, isPresented: $isPresented)
                } else {
                    coordinator.dismiss()
                }
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
