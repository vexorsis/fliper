import SwiftUI
import Fliper
import PhotosUI
import os

private let logger = Logger(subsystem: "FliperDemo", category: "ContentView")

struct ContentView: View {
    @Namespace private var namespace
    @State private var selectedIndex: Int = 0
    @State private var isPresented: Bool = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var images: [UIImage] = []
    @State private var isLoading: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

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
            .fullScreenCover(isPresented: $isPresented) {
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

    private func loadImages(from items: [PhotosPickerItem]) {
        logger.info("onChange fired with \(items.count) items")
        guard !items.isEmpty else { return }
        isLoading = true
        Task {
            var loaded: [UIImage] = []
            for item in items {
                let result = await loadImage(from: item)
                if let result {
                    loaded.append(result)
                }
            }
            logger.info("Loaded \(loaded.count) images total")
            images = loaded
            isLoading = false
        }
    }

    private func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        // Try loadTransferable with Data
        if let data = try? await item.loadTransferable(type: Data.self) {
            logger.info("loadTransferable(Data) succeeded, size: \(data.count)")
            if let image = UIImage(data: data) {
                return image
            }
        }

        // Fallback: try loadTransferable with URL
        if let url = try? await item.loadTransferable(type: URL.self) {
            logger.info("loadTransferable(URL) succeeded: \(url.path)")
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    return image
                }
            }
        }

        logger.error("All load methods failed for item")
        return nil
    }
}
