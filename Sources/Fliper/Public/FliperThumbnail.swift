import SwiftUI

@available(iOS 16, macOS 13, *)
public struct FliperThumbnail<Content: View>: View {
    let index: Int
    let namespace: Namespace.ID
    @Binding var isPresented: Bool
    let content: () -> Content

    public init(
        index: Int,
        namespace: Namespace.ID,
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.index = index
        self.namespace = namespace
        self._isPresented = isPresented
        self.content = content
    }

    public var body: some View {
        content()
            .matchedGeometryEffect(id: "fliper-\(index)", in: namespace)
            .onTapGesture {
                withAnimation(.spring()) {
                    isPresented = true
                }
            }
    }
}
