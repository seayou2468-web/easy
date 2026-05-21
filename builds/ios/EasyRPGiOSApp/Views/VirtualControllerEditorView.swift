import SwiftUI
import UniformTypeIdentifiers

struct VirtualControllerEditorView: View {
    struct DevicePreset: Identifiable, Hashable {
        let id: String
        let name: String
        let points: CGSize

        var aspectRatio: CGFloat { points.width / points.height }
    }

    private static let devicePresets: [DevicePreset] = [
        .init(id: "iphone_se_3", name: "iPhone SE (3rd)", points: CGSize(width: 375, height: 667)),
        .init(id: "iphone_12_mini", name: "iPhone 12 mini", points: CGSize(width: 360, height: 780)),
        .init(id: "iphone_12_12_pro", name: "iPhone 12 / 12 Pro", points: CGSize(width: 390, height: 844)),
        .init(id: "iphone_13_14", name: "iPhone 13/14", points: CGSize(width: 390, height: 844)),
        .init(id: "iphone_14_pro", name: "iPhone 14 Pro", points: CGSize(width: 393, height: 852)),
        .init(id: "iphone_14_pro_max", name: "iPhone 14 Pro Max", points: CGSize(width: 430, height: 932)),
        .init(id: "iphone_15_16", name: "iPhone 15/16", points: CGSize(width: 393, height: 852)),
        .init(id: "iphone_15_16_plus", name: "iPhone 15/16 Plus", points: CGSize(width: 430, height: 932))
    ]

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
    @State private var autoDetectedPresetId: String = Self.detectCurrentDevicePreset().id
    @ObservedObject private var config = ConfigManager.shared

    private var selectedButton: VirtualButtonLayout? {
        guard let selectedButtonInstanceId else { return nil }
        return workingButtons.first(where: { $0.instanceId == selectedButtonInstanceId })
    }

    var body: some View {
        let profileBinding = $store.activeProfileId
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()

            VStack(spacing: 8) {
                DeviceFrameEditorCanvas(
                    preset: activePreset,
                    workingButtons: $workingButtons,
                    selectedButtonInstanceId: $selectedButtonInstanceId
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .navigationTitle("レイアウト編集")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            autoDetectedPresetId = Self.detectCurrentDevicePreset().id
            loadWorkingButtons()
        }
        .onChange(of: isLandscapeEditing) { _, _ in loadWorkingButtons() }
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

    private var activePreset: DevicePreset {
        Self.devicePresets.first(where: { $0.id == autoDetectedPresetId }) ?? Self.devicePresets[0]
    }

    private static func detectCurrentDevicePreset() -> DevicePreset {
        let bounds = UIScreen.main.bounds
        let portraitSize = CGSize(width: min(bounds.width, bounds.height), height: max(bounds.width, bounds.height))
        return devicePresets.min(by: {
            let lhsDelta = abs($0.points.width - portraitSize.width) + abs($0.points.height - portraitSize.height)
            let rhsDelta = abs($1.points.width - portraitSize.width) + abs($1.points.height - portraitSize.height)
            return lhsDelta < rhsDelta
        }) ?? devicePresets[0]
    }

    @ViewBuilder
    private func menuDialog() -> some View {
        Button(isLandscapeEditing ? "縦向きを編集" : "横向きを編集") {
            isLandscapeEditing.toggle()
        }
        Button(config.ignoreLayoutSize ? "自動サイズON" : "自動サイズOFF") {
            config.ignoreLayoutSize.toggle()
            config.saveSettings()
        }
        Button("全ボタンを少し大きく") {
            workingButtons = workingButtons.map { b in
                var m = b
                m.size = min(180, m.size + 5)
                return m
            }
        }
        Button("全ボタンを少し小さく") {
            workingButtons = workingButtons.map { b in
                var m = b
                m.size = max(50, m.size - 5)
                return m
            }
        }
        Button("ボタンを追加") { showAddMenu = true }
        Button("この向きをデフォルトにリセット") {
            workingButtons = VirtualButtonLayout.default
            saveLayout()
        }
        if selectedButton != nil {
            Button("選択中ボタンを削除", role: .destructive) {
                guard let id = selectedButtonInstanceId else { return }
                workingButtons.removeAll { $0.instanceId == id }
                selectedButtonInstanceId = nil
                saveLayout()
            }
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
    @ObservedObject private var config = ConfigManager.shared
    @State private var dragAnchor: CGPoint?

    private var editorButtonSize: CGFloat {
        VirtualControllerView.visualSize(for: button, config: config)
    }

    var body: some View {
        Text(displayTitle(for: button))
            .font(.headline)
            .frame(width: editorButtonSize, height: editorButtonSize)
            .background(buttonBackground(for: button))
            .overlay(Circle().stroke(selectedButtonInstanceId == button.instanceId ? Color.yellow : .clear, lineWidth: 2))
            .position(x: button.x * canvasSize.width, y: button.y * canvasSize.height)
            .onTapGesture { selectedButtonInstanceId = button.instanceId }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                    selectedButtonInstanceId = button.instanceId
                    if dragAnchor == nil {
                        dragAnchor = CGPoint(x: button.x * canvasSize.width, y: button.y * canvasSize.height)
                    }
                    guard let dragAnchor else { return }
                    let translatedPoint = CGPoint(
                        x: dragAnchor.x + value.translation.width,
                        y: dragAnchor.y + value.translation.height
                    )
                    button.x = min(max(0.0, translatedPoint.x / canvasSize.width), 1.0)
                    button.y = min(max(0.0, translatedPoint.y / canvasSize.height), 1.0)
                }
                .onEnded { _ in dragAnchor = nil }
            )
    }
}

private struct DeviceFrameEditorCanvas: View {
    let preset: VirtualControllerEditorView.DevicePreset
    @Binding var workingButtons: [VirtualButtonLayout]
    @Binding var selectedButtonInstanceId: String?

    var body: some View {
        GeometryReader { outerGeo in
            let frameWidth = min(outerGeo.size.width, outerGeo.size.height * preset.aspectRatio)
            let frameHeight = frameWidth / preset.aspectRatio

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(white: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )

                VStack {
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                        .frame(width: frameWidth * 0.28, height: 22)
                        .padding(.top, 12)
                    Spacer()
                }

                ZStack {
                    Color.black
                    ForEach($workingButtons, id: \.instanceId) { $button in
                        EditorButtonView(button: $button, selectedButtonInstanceId: $selectedButtonInstanceId, canvasSize: CGSize(width: frameWidth - 28, height: frameHeight - 28))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(14)
            }
            .frame(width: frameWidth, height: frameHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(preset.aspectRatio, contentMode: .fit)
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
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
            if button.id == "up" || button.id == "down" {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 16, height: 30)
            }
            if button.id == "left" || button.id == "right" {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 30, height: 16)
            }
        }
    } else {
        Circle().fill(.ultraThinMaterial)
    }
}

private func displayTitle(for button: VirtualButtonLayout) -> String {
    button.title
}
