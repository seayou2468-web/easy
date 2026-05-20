import SwiftUI

struct InputLayoutManagerView: View {
    @Binding var layoutName: String
    @State private var showEditor = false

    var body: some View {
        Form {
            TextField("レイアウト名", text: $layoutName)
            Button("レイアウト編集を開く") { showEditor = true }
        }
        .navigationTitle("入力レイアウト管理")
        .fullScreenCover(isPresented: $showEditor) {
            NavigationStack { VirtualControllerEditorView() }
                .interactiveDismissDisabled(true)
        }
    }
}
