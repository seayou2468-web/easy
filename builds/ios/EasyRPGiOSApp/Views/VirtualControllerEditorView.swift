import SwiftUI

struct VirtualControllerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = VirtualControllerLayoutStore()
    @State private var workingButtons: [VirtualButtonLayout] = []
    @State private var selectedButtonId: String?
    @State private var showMenu = false
    @State private var showAddMenu = false

    private var selectedButton: VirtualButtonLayout? {
        guard let selectedButtonId else { return nil }
        return workingButtons.first(where: { $0.id == selectedButtonId })
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("Android同等: ドラッグで配置、メニューから追加/リセット/保存")
                .font(.caption)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()

                    ForEach($workingButtons) { $button in
                        EditorButtonView(button: $button, selectedButtonId: $selectedButtonId, canvasSize: geo.size)
                    }
                }
            }
            .frame(minHeight: 360)

            if let selected = selectedButton {
                HStack {
                    Text("選択中: \(selected.title)")
                    Spacer()
                    Text(selected.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }

            Button("メニュー") { showMenu = true }
                .buttonStyle(.borderedProminent)
        }
        .navigationTitle("レイアウト編集")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
        .onAppear { workingButtons = store.buttons }
        .confirmationDialog("編集メニュー", isPresented: $showMenu, actions: menuDialog)
        .confirmationDialog("追加するボタン", isPresented: $showAddMenu, actions: addButtonDialog)
        .toolbar(content: toolbarContent)
    }

    @ViewBuilder
    private func menuDialog() -> some View {
        Button("ボタンを追加") { showAddMenu = true }
        Button("デフォルトにリセット") { workingButtons = VirtualButtonLayout.default }
        Button("保存して閉じる") {
            saveLayout()
            dismiss()
        }
        Button("保存せず閉じる", role: .destructive) { dismiss() }
    }

    @ViewBuilder
    private func addButtonDialog() -> some View {
        ForEach(VirtualControllerLayoutStore.addableButtons, id: \.id) { item in
            Button("\(item.title) (\(item.id))") {
                guard !workingButtons.contains(where: { $0.id == item.id }) else { return }
                workingButtons.append(item)
            }
            .disabled(workingButtons.contains(where: { $0.id == item.id }))
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showMenu = true
            } label: {
                Label("メニュー", systemImage: "line.3.horizontal")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("保存") {
                saveLayout()
            }
        }
    }

    private func saveLayout() {
        store.buttons = workingButtons
        store.save()
    }
}

private struct EditorButtonView: View {
    @Binding var button: VirtualButtonLayout
    @Binding var selectedButtonId: String?
    let canvasSize: CGSize

    var body: some View {
        Text(displayTitle(for: button))
            .font(.headline)
            .frame(width: button.id == "menu" ? 48 : 54, height: button.id == "menu" ? 48 : 54)
            .background(buttonBackground(for: button))
            .overlay(Circle().stroke(selectedButtonId == button.id ? Color.yellow : .clear, lineWidth: 2))
            .position(x: button.x * canvasSize.width, y: button.y * canvasSize.height)
            .onTapGesture { selectedButtonId = button.id }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    selectedButtonId = button.id
                    button.x = min(max(0.0, value.location.x / canvasSize.width), 1.0)
                    button.y = min(max(0.0, value.location.y / canvasSize.height), 1.0)
                }
            )
    }
}

@ViewBuilder
private func buttonBackground(for button: VirtualButtonLayout) -> some View {
    if ["up", "down", "left", "right"].contains(button.id) {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
    } else {
        Circle().fill(.ultraThinMaterial)
    }
}

private func displayTitle(for button: VirtualButtonLayout) -> String {
    button.id == "menu" ? "≡" : button.title
}
