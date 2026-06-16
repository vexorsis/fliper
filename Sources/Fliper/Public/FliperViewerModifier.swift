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

// MARK: - Presentation Coordinator

final class FliperPresentationCoordinator: ObservableObject, FliperViewerDelegate {
    var selectedIndex: Binding<Int?>?
    weak var presentedViewer: FliperViewerController?

    func viewerDidDismiss(_ viewer: FliperViewerController) {
        selectedIndex?.wrappedValue = nil
        presentedViewer = nil
    }

    func present(images: [UIImage], currentIndex: Int, selectedIndex: Binding<Int?>) {
        guard let presenter = topViewController() else { return }
        let dataSource = FliperSwiftUIDataSource(images: images)
        let viewer = FliperViewerController(dataSource: dataSource, currentIndex: currentIndex)
        viewer.delegate = self
        self.selectedIndex = selectedIndex
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
    @Binding var selectedIndex: Int?
    let images: [UIImage]
    @StateObject private var coordinator = FliperPresentationCoordinator()

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedIndex) { newValue in
                if let index = newValue {
                    coordinator.present(images: images, currentIndex: index, selectedIndex: $selectedIndex)
                } else {
                    coordinator.dismiss()
                }
            }
    }
}

// MARK: - View Extension

extension View {
    public func fliperViewer(
        selectedIndex: Binding<Int?>,
        images: [UIImage]
    ) -> some View {
        modifier(FliperViewerModifier(
            selectedIndex: selectedIndex,
            images: images
        ))
    }
}
