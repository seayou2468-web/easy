import UIKit
import SwiftUI

struct ParitySettingsRootView: View {
    var body: some View {
        NavigationStack {
            SettingsMainView()
        }
    }
}

struct SettingsMainView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                settingsNavButton("ビデオ", "video.fill", destination: SettingsVideoView())
                settingsNavButton("オーディオ", "speaker.wave.2.fill", destination: SettingsAudioView())
                settingsNavButton("入力", "gamecontroller.fill", destination: SettingsInputView())
                settingsNavButton("フォント", "textformat", destination: SettingsFontView())
                settingsNavButton("EasyRPG フォルダ", "folder.fill", destination: SettingsGamesFolderView())
            }
        }
        .navigationTitle("設定")
    }

    private func settingsNavButton<Destination: View>(_ title: String, _ icon: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon).frame(width: 24)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsVideoView: View {
    @StateObject private var config = ConfigManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section(header: Text("表示設定").font(.headline)) {
                    Toggle("フルスクリーンモード", isOn: $config.fullscreen)
                        .onChange(of: config.fullscreen) { _, _ in config.saveSettings() }

                    Toggle("強制的に横置きにする", isOn: $config.forcedLandscape)
                        .onChange(of: config.forcedLandscape) { _, _ in config.saveSettings() }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("画面スケール").font(.headline)) {
                    VStack(spacing: 8) {
                        Picker("スケール方法", selection: $config.scaleMode) {
                            Text("Nearest Neighbor").tag(0)
                            Text("Integer").tag(1)
                            Text("Bilinear").tag(2)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: config.scaleMode) { _, _ in config.saveSettings() }

                        Text("Nearest: 元の画像に最も近い補間\nInteger: 整数倍スケール\nBilinear: 滑らかな補間")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("ストレッチ設定").font(.headline)) {
                    Toggle("ストレッチを有効", isOn: $config.stretch)
                        .onChange(of: config.stretch) { _, _ in config.saveSettings() }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("ゲーム解像度").font(.headline)) {
                    VStack(spacing: 8) {
                        Picker("解像度", selection: $config.gameResolution) {
                            Text("オリジナル (320x240, 4:3)").tag(0)
                            Text("ワイドスクリーン (416x240, 16:9)").tag(1)
                            Text("ウルトラワイド (560x240)").tag(2)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: config.gameResolution) { _, _ in config.saveSettings() }

                        Text("デフォルトは4:3。拡張モードでワイド表示ができます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("ビデオ")
    }
}

struct SettingsAudioView: View {
    @StateObject private var config = ConfigManager.shared
    @State private var soundfonts: [String] = []
    @State private var showSoundfontPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section(header: Text("音量設定").font(.headline)) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("音楽のボリューム")
                            Spacer()
                            Text("\(Int(config.musicVolume))").foregroundStyle(.secondary)
                        }
                        Slider(value: $config.musicVolume, in: 0...100, step: 1)
                            .onChange(of: config.musicVolume) { _, _ in config.saveSettings() }
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("サウンドエフェクトのボリューム")
                            Spacer()
                            Text("\(Int(config.soundVolume))").foregroundStyle(.secondary)
                        }
                        Slider(value: $config.soundVolume, in: 0...100, step: 1)
                            .onChange(of: config.soundVolume) { _, _ in config.saveSettings() }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("カスタムサウンドフォント").font(.headline)) {
                    Text("SoundFonts フォルダ内の .sf2 ファイルを選択して、MIDI 音声レンダリングに使用します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: { showSoundfontPicker = true }) {
                        HStack {
                            Image(systemName: "folder.circle.fill")
                            Text("SoundFonts フォルダから選択")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let soundfont = config.selectedSoundFont {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(soundfont.lastPathComponent)
                                .lineLimit(1)
                        }
                        .font(.caption)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("オーディオ")
        .sheet(isPresented: $showSoundfontPicker) {
            DocumentPicker(allowedContentTypes: ["audio.soundfont"]) { url in
                config.selectedSoundFont = url
                config.saveSettings()
            }
        }
    }
}

struct SettingsInputView: View {
    @StateObject private var config = ConfigManager.shared
    @State private var showLayoutEditor = false
    @State private var showButtonMapping = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section(header: Text("振動設定").font(.headline)) {
                    Toggle("バイブレーション", isOn: $config.enableVibration)
                        .onChange(of: config.enableVibration) { _, _ in config.saveSettings() }

                    Toggle("スライド時に振動", isOn: $config.vibrateWhenSliding)
                        .disabled(!config.enableVibration)
                        .onChange(of: config.vibrateWhenSliding) { _, _ in config.saveSettings() }

                    Toggle("A/B を Z/X として表示", isOn: $config.showABasZX)
                        .onChange(of: config.showABasZX) { _, _ in config.saveSettings() }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("高速化設定").font(.headline)) {
                    VStack(spacing: 8) {
                        Picker("高速化モード", selection: $config.fastForwardMode) {
                            Text("ホールド（長押し）").tag(0)
                            Text("タップ（タップして切替）").tag(1)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: config.fastForwardMode) { _, _ in config.saveSettings() }

                        HStack {
                            Text("高速化倍率")
                            Spacer()
                            Text("\(config.fastForwardMultiplier)x").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(get: { Double(config.fastForwardMultiplier) }, set: { config.fastForwardMultiplier = Int($0) }), in: 2...100, step: 1)
                            .onChange(of: config.fastForwardMultiplier) { _, _ in config.saveSettings() }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("レイアウト設定").font(.headline)) {
                    HStack {
                        Text("レイアウト透明度")
                        Spacer()
                        Text("\(Int(config.layoutTransparency))%").foregroundStyle(.secondary)
                    }
                    Slider(value: $config.layoutTransparency, in: 0...255, step: 1)
                        .onChange(of: config.layoutTransparency) { _, _ in config.saveSettings() }

                    Toggle("レイアウトサイズ設定を無視", isOn: $config.ignoreLayoutSize)
                        .onChange(of: config.ignoreLayoutSize) { _, _ in config.saveSettings() }

                    if !config.ignoreLayoutSize {
                        HStack {
                            Text("レイアウトサイズ")
                            Spacer()
                            Text("\(Int(config.layoutSize))%").foregroundStyle(.secondary)
                        }
                        Slider(value: $config.layoutSize, in: 50...150, step: 1)
                            .onChange(of: config.layoutSize) { _, _ in config.saveSettings() }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("カスタマイズ").font(.headline)) {
                    Button(action: { showLayoutEditor = true }) {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("レイアウトエディターを開く")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: { showButtonMapping = true }) {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text("ボタン設定を開く")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("入力")
        .sheet(isPresented: $showLayoutEditor) {
            VirtualControllerEditorView()
        }
        .sheet(isPresented: $showButtonMapping) {
            ButtonMappingEditorView()
        }
    }
}

struct SettingsFontView: View {
    @StateObject private var config = ConfigManager.shared
    @State private var availableFonts: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section(header: Text("フォント設定").font(.headline)) {
                    Toggle("外部フォントを優先", isOn: $config.preferExternalFonts)
                        .onChange(of: config.preferExternalFonts) { _, _ in config.saveSettings() }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("ゲームフォント 1 (通常)").font(.headline)) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("フォント")
                            Spacer()
                            Text(config.font1Name ?? "デフォルト")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("フォントサイズ")
                            Spacer()
                            Text("\(config.font1Size)").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(get: { Double(config.font1Size) }, set: { config.font1Size = Int($0) }), in: 6...32, step: 1)
                            .onChange(of: config.font1Size) { _, _ in config.saveSettings() }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("ゲームフォント 2 (モノスペース)").font(.headline)) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("フォント")
                            Spacer()
                            Text(config.font2Name ?? "デフォルト")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("フォントサイズ")
                            Spacer()
                            Text("\(config.font2Size)").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(get: { Double(config.font2Size) }, set: { config.font2Size = Int($0) }), in: 6...32, step: 1)
                            .onChange(of: config.font2Size) { _, _ in config.saveSettings() }
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("フォント")
    }
}

struct SettingsGamesFolderView: View {
    @StateObject private var config = ConfigManager.shared
    @State private var showEasyRPGFolderPicker = false
    @State private var showRTPFolderPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Section(header: Text("EasyRPG フォルダ").font(.headline)) {
                    Text("ゲームと保存ファイルを格納するメインフォルダを選択してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button(action: { showEasyRPGFolderPicker = true }) {
                        HStack {
                            Image(systemName: "folder.circle.fill")
                            Text("フォルダを選択")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if let folder = config.easyRPGFolderURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("選択済み:").font(.caption).foregroundStyle(.secondary)
                            Text(folder.lastPathComponent)
                                .font(.caption)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("RTP (ランタイムパッケージ)").font(.headline)) {
                    Toggle("RTP スキャンを有効", isOn: $config.enableRtpScanning)
                        .onChange(of: config.enableRtpScanning) { _, _ in config.saveSettings() }

                    if config.enableRtpScanning {
                        Button(action: { showRTPFolderPicker = true }) {
                            HStack {
                                Image(systemName: "folder.circle.fill")
                                Text("RTP フォルダを選択")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        if let folder = config.rtpFolderURL {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("選択済み:").font(.caption).foregroundStyle(.secondary)
                                Text(folder.lastPathComponent)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("フォルダ構成").font(.headline)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("推奨フォルダ構成:").font(.caption).fontWeight(.semibold)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("EasyRPG/").font(.caption2).monospaced()
                            Text("├── games/       (ゲームフォルダ)").font(.caption2).monospaced().foregroundStyle(.secondary)
                            Text("├── saves/       (保存ファイル)").font(.caption2).monospaced().foregroundStyle(.secondary)
                            Text("├── soundfonts/  (カスタムサウンドフォント)").font(.caption2).monospaced().foregroundStyle(.secondary)
                            Text("├── fonts/       (カスタムフォント)").font(.caption2).monospaced().foregroundStyle(.secondary)
                            Text("└── rtp/         (ランタイムパッケージ)").font(.caption2).monospaced().foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(4)
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("EasyRPG フォルダ")
        .sheet(isPresented: $showEasyRPGFolderPicker) {
            FolderPickerView { url in
                config.setEasyRPGFolder(url)
            }
        }
        .sheet(isPresented: $showRTPFolderPicker) {
            FolderPickerView { url in
                config.setRTPFolder(url)
            }
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let allowedContentTypes: [String]
    let onPicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void

        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPicked(url)
            }
        }
    }
}

struct FolderPickerView: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void
        let dismiss: DismissAction

        init(onPicked: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onPicked = onPicked
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPicked(url)
            }
            dismiss()
        }
    }
}

                HStack {
                    Text("早送りボタンモード")
                    Spacer()
                    Picker("モード", selection: $settings.fastForwardMode) {
                        Text("ホールド").tag("hold")
                        Text("タップ").tag("tap")
                    }
                    .pickerStyle(.menu)
                }
                HStack {
                    Text("倍速")
                    Spacer()
                    Text("x\(String(format: "%.1f", settings.fastForwardFactor))")
                    Slider(value: $settings.fastForwardFactor, in: 1...10, step: 0.5)
                        .frame(maxWidth: 180)
                }
                Divider()
                Text("入力レイアウトの透過").font(.title3)
                HStack {
                    Text("\(Int(settings.inputLayoutTransparency))")
                    Slider(value: $settings.inputLayoutTransparency, in: 0...255, step: 1)
                }
                Divider()
                Toggle("ボタンサイズの設定を無視", isOn: $settings.ignoreLayoutSize)
                HStack {
                    Text("入力サイズ")
                    Text("\(Int(settings.layoutSize))")
                    Slider(value: $settings.layoutSize, in: 50...300, step: 1)
                }
                Divider()
                Text("入力レイアウトの管理").font(.title3)
                NavigationLink { InputLayoutManagerView(layoutName: $settings.horizontalLayoutName) } label: { HStack { Text("横画面レイアウト"); Spacer(); Text(settings.horizontalLayoutName); Image(systemName: "gearshape") } }
                NavigationLink { InputLayoutManagerView(layoutName: $settings.verticalLayoutName) } label: { HStack { Text("縦画面レイアウト"); Spacer(); Text(settings.verticalLayoutName); Image(systemName: "gearshape") } }
                Text("レイアウト編集からボタン配置を細かく調整できます。")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                Divider()
            }.padding(10)
        }
        .navigationTitle("入力")
    }
}

struct SettingsFontView: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Button("フォントフォルダを開く") { openFolder("~/Documents/Fonts") }
                Text("外部フォントを読み込み、ゲーム内フォントとして利用できます。")
                    .font(.subheadline)
                Text("フォントは Font1 / Font2 を個別に設定できます。")
                    .font(.subheadline)
                Divider()
                Text("Font 1").font(.title3)
                let fonts = listFiles(in: "~/Documents/Fonts", extensions: ["ttf", "otf"])
                if fonts.isEmpty {
                    Text("選択中: \(settings.font1)")
                } else {
                    Picker("Font 1", selection: $settings.font1) {
                        ForEach(fonts, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }
                Text("フォントサイズ")
                HStack {
                    Text("\(Int(settings.font1Size))")
                    Slider(value: $settings.font1Size, in: 50...200, step: 1)
                }
                fontPreviewCard(title: "Font 1 Preview", sizePercent: settings.font1Size)
                Text("プレビューで文字サイズを確認して調整してください。")
                    .font(.subheadline)
                Divider()
                Text("Font 2").font(.title3)
                if fonts.isEmpty {
                    Text("選択中: \(settings.font2)")
                } else {
                    Picker("Font 2", selection: $settings.font2) {
                        ForEach(fonts, id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.menu)
                }
                Text("フォントサイズ")
                HStack {
                    Text("\(Int(settings.font2Size))")
                    Slider(value: $settings.font2Size, in: 50...200, step: 1)
                }
                fontPreviewCard(title: "Font 2 Preview", sizePercent: settings.font2Size)
                Text("プレビューで文字サイズを確認して調整してください。")
                    .font(.subheadline)
            }.padding(20)
        }
        .navigationTitle("フォント")
    }
}

@ViewBuilder
private func fontPreviewCard(title: String, sizePercent: Double) -> some View {
    let size = CGFloat(max(10, min(sizePercent, 200))) * 0.2
    RoundedRectangle(cornerRadius: 10)
        .fill(.gray.opacity(0.2))
        .frame(height: 90)
        .overlay(
            VStack(spacing: 6) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text("あいうえお ABC 123")
                    .font(.system(size: size, weight: .regular, design: .default))
            }
            .padding(.horizontal, 8)
        )
}

struct SettingsGamesFolderView: View {
    @ObservedObject var settings: AppSettings
    @State private var showGamePicker = false
    @State private var showRtpPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Button("gamesフォルダを開く") { openFolder(settings.gameFolder) }
                Divider()
                Toggle("RTPサポートを有効", isOn: $settings.enableRtpScanning)
                Button("RTPフォルダを開く") { openFolder(settings.rtpFolder) }
                Button("RTPフォルダを選択") { showRtpPicker = true }
                Text("RTPが見つからないゲームのためにRTPフォルダを設定してください。")
                    .font(.subheadline)
                let rtp = detectRtpStatus(settings.rtpFolder)
                Text("RTP2000: \(rtp.0)")
                Text("RTP2003: \(rtp.1)")
                Divider()
                Button("ゲームフォルダを選択") { showGamePicker = true }
                TextField("ゲームフォルダ", text: $settings.gameFolder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                Text("ゲームは EasyRPG フォルダ配下の games に配置してください。")
                    .font(.subheadline)
                Button("説明動画を見る") {
                    if let url = URL(string: "https://easyrpg.org") { UIApplication.shared.open(url) }
                }
            }.padding(20)
        }
                .sheet(isPresented: $showGamePicker) {
            FolderPicker { url in settings.gameFolder = url.path }
        }
        .sheet(isPresented: $showRtpPicker) {
            FolderPicker { url in settings.rtpFolder = url.path }
        }
        .navigationTitle("EasyRPG フォルダ")
    }
}

@MainActor
private func openFolder(_ rawPath: String) {
    let expanded = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
    let url = URL(fileURLWithPath: expanded, isDirectory: true)
    let fm = FileManager.default

    if !fm.fileExists(atPath: url.path) {
        try? fm.createDirectory(at: url, withIntermediateDirectories: true)
    }

    UIApplication.shared.open(url)
}


private func listFiles(in rawPath: String, extensions: Set<String>) -> [String] {
    let expanded = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
    let url = URL(fileURLWithPath: expanded, isDirectory: true)
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
    return items.filter { extensions.contains($0.pathExtension.lowercased()) }.map { $0.lastPathComponent }.sorted()
}


private func detectRtpStatus(_ rawPath: String) -> (String, String) {
    let expanded = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
    let base = URL(fileURLWithPath: expanded, isDirectory: true)
    let fm = FileManager.default
    let rtp2000 = fm.fileExists(atPath: base.appendingPathComponent("RPG2000", isDirectory: true).path) ? "検出" : "未検出"
    let rtp2003 = fm.fileExists(atPath: base.appendingPathComponent("RPG2003", isDirectory: true).path) ? "検出" : "未検出"
    return (rtp2000, rtp2003)
}
