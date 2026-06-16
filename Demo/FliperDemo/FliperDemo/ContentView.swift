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
