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
        .fullScreenCover(isPresented: $isPresented) {
            FliperViewerWrapper(
                imageNames: imageNames,
                currentIndex: selectedIndex,
                isPresented: $isPresented
            )
            .ignoresSafeArea()
        }
    }
}

struct FliperViewerWrapper: UIViewControllerRepresentable {
    let imageNames: [String]
    let currentIndex: Int
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> FliperViewerController {
        let dataSource = FliperDemoDataSource(imageNames: imageNames)
        let viewer = FliperViewerController(dataSource: dataSource, currentIndex: currentIndex)
        viewer.delegate = context.coordinator
        return viewer
    }

    func updateUIViewController(_ uiViewController: FliperViewerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }

    class Coordinator: NSObject, FliperViewerDelegate {
        @Binding var isPresented: Bool

        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }

        func viewerDidDismiss(_ viewer: FliperViewerController) {
            isPresented = false
        }
    }
}

final class FliperDemoDataSource: FliperViewerDataSource {
    let imageNames: [String]

    init(imageNames: [String]) {
        self.imageNames = imageNames
    }

    func numberOfItems(in viewer: FliperViewerController) -> Int {
        imageNames.count
    }

    func viewer(_ viewer: FliperViewerController, imageAt index: Int) -> UIImage {
        UIImage(named: imageNames[index]) ?? UIImage()
    }
}
