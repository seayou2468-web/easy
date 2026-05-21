import SwiftUI
import UniformTypeIdentifiers

struct VirtualControllerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = VirtualControllerLayoutStore()
    @State private var workingButtons: [VirtualButtonLayout] = []
    @State private var selectedButtonInstanceId: String?
    @State private var showMenu = false
    @State private var showAddMenu = false
    @State private var isLandscapeEditing = false
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var showImporter = false

    private var selectedButton: VirtualButtonLayout? {
        guard let selectedButtonInstanceId else { return nil }
        return workingButtons.first(where: { $0.instanceId == selectedButtonInstanceId })
    }

    var body: some View {
        VStack(spacing: 10) {
            Picker("対象", selection: $isLandscapeEditing) {
                Text("縦").tag(false)
                Text("横").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .onChange(of: isLandscapeEditing) { _, _ in loadWorkingButtons() }

            Picker("レイアウト", selection: $store.activeProfileId) {
                ForEach(store.profiles) { profile in
                    Text(profile.name).tag(profile.id)
                }
            }
            .onChange(of: store.activeProfileId) { _, newId in
                store.setActiveProfile(newId)
                loadWorkingButtons()
            }
            .padding(.horizontal, 12)

            GeometryReader { geo in
                ZStack {
                    Color.black.opacity(0.9).ignoresSafeArea()
                    ForEach($workingButtons, id: \.instanceId) { $button in
                        EditorButtonView(button: $button, selectedButtonInstanceId: $selectedButtonInstanceId, canvasSize: geo.size)
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
        .onAppear { loadWorkingButtons() }
        .confirmationDialog("編集メニュー", isPresented: $showMenu, actions: menuDialog)
        .confirmationDialog("追加するボタン", isPresented: $showAddMenu, actions: addButtonDialog)
        .toolbar(content: toolbarContent)
        .fileExporter(isPresented: $showExporter, document: exportDocument(), contentType: .json, defaultFilename: exportURL?.lastPathComponent ?? "layout.json") { _ in }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result {
                _ = store.importProfile(from: url)
                loadWorkingButtons()
            }
        }
    }

    private func loadWorkingButtons() {
        workingButtons = store.buttons(isLandscape: isLandscapeEditing)
    }

    @ViewBuilder
    private func menuDialog() -> some View {
        Button("ボタンを追加") { showAddMenu = true }
        Button("この向きをデフォルトにリセット") {
            workingButtons = VirtualButtonLayout.default
            saveLayout()
        }
        Button("レイアウトを新規作成") {
            store.addProfile(name: "Layout \(store.profiles.count + 1)")
            loadWorkingButtons()
        }
        Button("エクスポート") {
            exportURL = store.exportActiveProfile()
            showExporter = exportURL != nil
        }
        Button("インポート") { showImporter = true }
        Button("保存して閉じる") {
            saveLayout()
            dismiss()
        }
        Button("保存せず閉じる", role: .destructive) { dismiss() }
    }

    @ViewBuilder
    private func addButtonDialog() -> some View {
        ForEach(VirtualControllerLayoutStore.addableButtons, id: \.instanceId) { item in
            Button("\(item.title) (\(item.id))") {
                var copy = item
                copy.instanceId = UUID().uuidString
                workingButtons.append(copy)
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showMenu = true } label: { Label("メニュー", systemImage: "line.3.horizontal") }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("保存") { saveLayout() }
        }
    }

    private func saveLayout() {
        store.updateButtons(workingButtons, isLandscape: isLandscapeEditing)
    }

    private func exportDocument() -> LayoutExportDocument {
        let data = (exportURL.flatMap { try? Data(contentsOf: $0) }) ?? Data()
        return LayoutExportDocument(data: data)
    }
}

private struct EditorButtonView: View {
    @Binding var button: VirtualButtonLayout
    @Binding var selectedButtonInstanceId: String?
    let canvasSize: CGSize

    var body: some View {
        Text(displayTitle(for: button))
            .font(.headline)
            .frame(width: button.id == "menu" ? 48 : 54, height: button.id == "menu" ? 48 : 54)
            .background(buttonBackground(for: button))
            .overlay(Circle().stroke(selectedButtonInstanceId == button.instanceId ? Color.yellow : .clear, lineWidth: 2))
            .position(x: button.x * canvasSize.width, y: button.y * canvasSize.height)
            .onTapGesture { selectedButtonInstanceId = button.instanceId }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    selectedButtonInstanceId = button.instanceId
                    button.x = min(max(0.0, value.location.x / canvasSize.width), 1.0)
                    button.y = min(max(0.0, value.location.y / canvasSize.height), 1.0)
                }
            )
    }
}

private struct LayoutExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { .init(regularFileWithContents: data) }
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
