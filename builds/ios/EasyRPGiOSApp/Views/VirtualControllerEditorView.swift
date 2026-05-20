import SwiftUI

struct VirtualControllerEditorView: View {
    @StateObject private var store = VirtualControllerLayoutStore()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.9).ignoresSafeArea()

                ForEach($store.buttons) { $button in
                    Text(button.title)
                        .font(.headline)
                        .frame(width: 54, height: 54)
                        .background(.ultraThinMaterial, in: Circle())
                        .position(x: button.x, y: button.y)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    button.x = min(max(30, value.location.x), geo.size.width - 30)
                                    button.y = min(max(30, value.location.y), geo.size.height - 30)
                                }
                                .onEnded { _ in store.save() }
                        )
                }
            }
        }
        .navigationTitle("レイアウト編集")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("リセット") { store.reset() }
            }
        }
    }
}
