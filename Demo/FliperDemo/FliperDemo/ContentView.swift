import SwiftUI
import Fliper

struct ContentView: View {
    @State private var selectedIndex: Int?

    private let items: [FliperViewerItem] = [
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
        URL(string: "https://picsum.photos/id/106/600/800")!,
    ].map { FliperViewerItem.url($0) }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<items.count, id: \.self) { index in
                    Color.gray
                        .aspectRatio(1, contentMode: .fit)
                        .onTapGesture {
                            selectedIndex = index
                        }
                }
            }
        }
        .fliperViewer(selectedIndex: $selectedIndex, items: items, imageLoader: DemoImageLoader.shared)
    }
}

final class DemoImageLoader: FliperImageLoader {
    static let shared = DemoImageLoader()

    func loadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.badServerResponse)
        }
        return image
    }
}
