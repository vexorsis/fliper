import SwiftUI
import UIKit

// MARK: - Data Source Adapter

final class FliperSwiftUIDataSource: FliperViewerDataSource {
    let items: [FliperViewerItem]

    init(items: [FliperViewerItem]) {
        self.items = items
    }

    func numberOfItems(in viewer: FliperViewerController) -> Int {
        items.count
    }

    func viewer(_ viewer: FliperViewerController, itemAt index: Int) -> FliperViewerItem {
        items[index]
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

    func present(items: [FliperViewerItem], imageLoader: FliperImageLoader?, currentIndex: Int, selectedIndex: Binding<Int?>) {
        guard let presenter = topViewController() else { return }
        let dataSource = FliperSwiftUIDataSource(items: items)
        let viewer = FliperViewerController(dataSource: dataSource, imageLoader: imageLoader, currentIndex: currentIndex)
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
    let items: [FliperViewerItem]
    var imageLoader: FliperImageLoader? = nil
    @StateObject private var coordinator = FliperPresentationCoordinator()

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedIndex) { newValue in
                if let index = newValue {
                    coordinator.present(items: items, imageLoader: imageLoader, currentIndex: index, selectedIndex: $selectedIndex)
                } else {
                    coordinator.dismiss()
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    public func fliperViewer(
        selectedIndex: Binding<Int?>,
        items: [FliperViewerItem],
        imageLoader: FliperImageLoader? = nil
    ) -> some View {
        modifier(FliperViewerModifier(
            selectedIndex: selectedIndex,
            items: items,
            imageLoader: imageLoader
        ))
    }

    public func fliperViewer(
        selectedIndex: Binding<Int?>,
        images: [UIImage]
    ) -> some View {
        let items = images.map { FliperViewerItem.image($0) }
        return modifier(FliperViewerModifier(
            selectedIndex: selectedIndex,
            items: items
        ))
    }
}
