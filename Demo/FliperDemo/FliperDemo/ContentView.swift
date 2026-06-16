import SwiftUI
import Fliper

struct ContentView: View {
    @State private var isPresented = false
    @State private var selectedIndex = 0
    @State private var loadedImages: [UIImage?] = []

    private let urls = [
        URL(string: "https://picsum.photos/id/10/800/600")!,
        URL(string: "https://picsum.photos/id/20/800/600")!,
        URL(string: "https://picsum.photos/id/30/800/600")!,
        URL(string: "https://picsum.photos/id/40/800/600")!,
        URL(string: "https://picsum.photos/id/50/800/600")!,
        URL(string: "https://picsum.photos/id/60/800/600")!,
        URL(string: "https://picsum.photos/id/70/800/600")!,
        URL(string: "https://picsum.photos/id/80/800/600")!,
        URL(string: "https://picsum.photos/id/90/800/600")!,
        URL(string: "https://picsum.photos/id/100/800/600")!,
        URL(string: "https://picsum.photos/id/110/800/600")!,
        URL(string: "https://picsum.photos/id/120/800/600")!,
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    private var validImages: [UIImage] {
        loadedImages.compactMap { $0 }
    }

    private var allLoaded: Bool {
        loadedImages.count == urls.count && loadedImages.allSatisfy { $0 != nil }
    }

    var body: some View {
        Group {
            if !allLoaded {
                ProgressView("Loading images...")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<urls.count, id: \.self) { index in
                            if let image = loadedImages[index] {
                                Image(uiImage: image)
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
                }
                .fliperViewer(isPresented: $isPresented, images: validImages, currentIndex: selectedIndex)
            }
        }
        .task { await loadImages() }
    }

    private func loadImages() async {
        loadedImages = Array(repeating: nil as UIImage?, count: urls.count)
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask {
                    guard let data = try? Data(contentsOf: url),
                          let image = UIImage(data: data) else {
                        return (index, nil)
                    }
                    return (index, image)
                }
            }
            for await (index, image) in group {
                loadedImages[index] = image
            }
        }
    }
}
