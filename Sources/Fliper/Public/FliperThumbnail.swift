import SwiftUI

@available(iOS 16, macOS 13, *)
public struct FliperThumbnail<Content: View>: View {
    let index: Int
    let namespace: Namespace.ID
    @Binding var isPresented: Bool
    @Binding var selection: Int
    let content: () -> Content

    public init(
        index: Int,
        namespace: Namespace.ID,
        isPresented: Binding<Bool>,
        selection: Binding<Int>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.index = index
        self.namespace = namespace
        self._isPresented = isPresented
        self._selection = selection
        self.content = content
    }

    public var body: some View {
        content()
            .matchedGeometryEffect(id: TransitionCoordinator.matchedGeometryID(for: index), in: namespace)
            .onTapGesture {
                selection = index
                withAnimation(.spring()) {
                    isPresented = true
                }
            }
    }
}
