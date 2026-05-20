import SwiftUI

struct VirtualControllerEditorView: View {
    @StateObject private var store = VirtualControllerLayoutStore()
    @State private var selectedButtonId: String?

    var body: some View {
        VStack(spacing: 10) {
            Text("ボタンをドラッグして位置を変更。タップで選択。")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()

                    ForEach($store.buttons) { $button in
                        Text(button.title)
                            .font(.headline)
                            .frame(width: 54, height: 54)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(selectedButtonId == button.id ? Color.yellow : .clear, lineWidth: 2))
                            .position(x: button.x, y: button.y)
                            .onTapGesture {
                                selectedButtonId = button.id
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        selectedButtonId = button.id
                                        button.x = min(max(30, value.location.x), geo.size.width - 30)
                                        button.y = min(max(30, value.location.y), geo.size.height - 30)
                                    }
                                    .onEnded { _ in store.save() }
                            )
                    }
                }
            }
            .frame(minHeight: 360)

            if let selectedButtonId,
               let selected = store.buttons.first(where: { $0.id == selectedButtonId }) {
                HStack {
                    Text("選択中: \(selected.title)")
                    Spacer()
                    Text(selected.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }
        }
        .navigationTitle("レイアウト編集")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("保存") { store.save() }
                Button("リセット") { store.reset() }
            }
        }
    }
}
