import SwiftUI
import Fliper

struct ContentView: View {
    @Namespace private var namespace
    @State private var selectedIndex: Int = 0
    @State private var isPresented: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .indigo, .mint, .teal, .brown]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<colors.count, id: \.self) { index in
                    FliperThumbnail(
                        index: index,
                        namespace: namespace,
                        isPresented: $isPresented
                    ) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colors[index].gradient)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            FliperViewer(
                selection: $selectedIndex,
                namespace: namespace,
                itemCount: colors.count,
                onDismiss: {
                    isPresented = false
                }
            ) { index in
                RoundedRectangle(cornerRadius: 0)
                    .fill(colors[index].gradient)
            }
        }
    }
}
