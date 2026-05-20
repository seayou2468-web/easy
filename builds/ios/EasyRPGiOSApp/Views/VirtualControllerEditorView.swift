import SwiftUI

struct VirtualControllerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = VirtualControllerLayoutStore()
    @State private var workingButtons: [VirtualButtonLayout] = []
    @State private var selectedButtonId: String?
    @State private var showMenu = false
    @State private var showAddMenu = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Android同等: ドラッグで配置、メニューから追加/リセット/保存")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()

                    ForEach($workingButtons) { $button in
                        Text(displayTitle(for: button))
                            .font(.headline)
                            .frame(width: button.id == "menu" ? 48 : 54, height: button.id == "menu" ? 48 : 54)
                            .background(.ultraThinMaterial, in: ["up", "down", "left", "right"].contains(button.id) ? AnyShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) : AnyShape(Circle()))
                            .overlay(Circle().stroke(selectedButtonId == button.id ? Color.yellow : .clear, lineWidth: 2))
                            .position(x: button.x * geo.size.width, y: button.y * geo.size.height)
                            .onTapGesture {
                                selectedButtonId = button.id
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        selectedButtonId = button.id
                                        button.x = min(max(0.0, value.location.x / geo.size.width), 1.0)
                                        button.y = min(max(0.0, value.location.y / geo.size.height), 1.0)
                                    }
                            )
                    }
                }
            }
            .frame(minHeight: 360)

            if let selectedButtonId,
               let selected = workingButtons.first(where: { $0.id == selectedButtonId }) {
                HStack {
                    Text("選択中: \(selected.title)")
                    Spacer()
                    Text(selected.id)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
            }

            HStack(spacing: 12) {
                Button("メニュー") { showMenu = true }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("レイアウト編集")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
        .onAppear { workingButtons = store.buttons }
        .confirmationDialog("編集メニュー", isPresented: $showMenu) {
            Button("ボタンを追加") { showAddMenu = true }
            Button("デフォルトにリセット") { workingButtons = VirtualButtonLayout.default }
            Button("保存して閉じる") { store.buttons = workingButtons; store.save(); dismiss() }
            Button("保存せず閉じる", role: .destructive) { dismiss() }
        }
        .confirmationDialog("追加するボタン", isPresented: $showAddMenu) {
            ForEach(VirtualButtonLayout.addableButtons, id: \.id) { item in
                Button("\(item.title) (\(item.id))") { workingButtons.append(item) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showMenu = true
                } label: {
                    Label("メニュー", systemImage: "line.3.horizontal")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("保存") { store.buttons = workingButtons; store.save() }
            }
        }
    }
}

private struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path
    init<S: Shape>(_ wrapped: S) { self.pathBuilder = { rect in wrapped.path(in: rect) } }
    func path(in rect: CGRect) -> Path { pathBuilder(rect) }
}

private func displayTitle(for button: VirtualButtonLayout) -> String {
    if button.id == "menu" { return "≡" }
    return button.title
}
