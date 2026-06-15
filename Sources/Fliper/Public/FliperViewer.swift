import SwiftUI

@available(iOS 16, macOS 13, *)
public struct FliperViewer<Content: View>: View {
    public init(
        selection: Binding<Int>,
        namespace: Namespace.ID,
        itemCount: Int,
        maxScale: CGFloat = 5.0,
        doubleTapScale: CGFloat = 2.0,
        dismissThreshold: CGFloat = 0.25,
        backgroundColor: Color = .black,
        @ViewBuilder content: @escaping (Int) -> Content
    ) {
        fatalError("Not yet implemented")
    }

    public var body: some View {
        EmptyView()
    }
}
