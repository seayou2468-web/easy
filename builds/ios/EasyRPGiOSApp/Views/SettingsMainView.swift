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
        ZStack {
            LinearGradient(colors: [Color(.systemBackground), Color(.systemGray6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("環境設定")
                        .font(.largeTitle.bold())
                    Text("表示、音、入力、フォント、フォルダを用途別に調整できます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    settingsNavButton("ビデオ", "video.fill", subtitle: "画質・解像度・表示方式", destination: SettingsVideoView())
                    settingsNavButton("オーディオ", "speaker.wave.2.fill", subtitle: "音量・SoundFont", destination: SettingsAudioView())
                    settingsNavButton("入力", "gamecontroller.fill", subtitle: "振動・高速化・レイアウト", destination: SettingsInputView())
                    settingsNavButton("フォント", "textformat", subtitle: "フォントと文字サイズ", destination: SettingsFontView())
                    settingsNavButton("EasyRPG フォルダ", "folder.fill", subtitle: "ゲームフォルダ/RTPパス", destination: SettingsGamesFolderView())
                }
                .padding(14)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsNavButton<Destination: View>(_ title: String, _ icon: String, subtitle: String, destination: Destination) -> some View {
        AppLogger.log("ENTER settingsNavButton")
        NavigationLink(destination: destination) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon).frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .foregroundStyle(.primary)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

                    Picker("ゲーム一覧のタイトル表示", selection: $config.gameBrowserLabelMode) {
                        Text("ゲームタイトル").tag(0)
                        Text("フォルダ名").tag(1)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: config.gameBrowserLabelMode) { _, _ in config.saveSettings() }
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
                        Slider(value: .init(
                            get: { Double(config.musicVolume) },
                            set: { config.musicVolume = Int($0) }
                        ), in: 0...100, step: 1)
                            .onChange(of: config.musicVolume) { _, _ in config.saveSettings() }
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("サウンドエフェクトのボリューム")
                            Spacer()
                            Text("\(Int(config.soundVolume))").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(
                            get: { Double(config.soundVolume) },
                            set: { config.soundVolume = Int($0) }
                        ), in: 0...100, step: 1)
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

                        HStack {
                            Text("高速化倍率 B")
                            Spacer()
                            Text("\(config.fastForwardMultiplierB)x").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(get: { Double(config.fastForwardMultiplierB) }, set: { config.fastForwardMultiplierB = Int($0) }), in: 2...100, step: 1)
                            .onChange(of: config.fastForwardMultiplierB) { _, _ in config.saveSettings() }
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
                    Slider(value: .init(
                        get: { Double(config.layoutTransparency) },
                        set: { config.layoutTransparency = Int($0) }
                    ), in: 0...255, step: 1)
                        .onChange(of: config.layoutTransparency) { _, _ in config.saveSettings() }

                    Toggle("レイアウトサイズ設定を無視", isOn: $config.ignoreLayoutSize)
                        .onChange(of: config.ignoreLayoutSize) { _, _ in config.saveSettings() }

                    if !config.ignoreLayoutSize {
                        HStack {
                            Text("レイアウトサイズ")
                            Spacer()
                            Text("\(Int(config.layoutSize))%").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(
                            get: { Double(config.layoutSize) },
                            set: { config.layoutSize = Int($0) }
                        ), in: 50...150, step: 1)
                            .onChange(of: config.layoutSize) { _, _ in config.saveSettings() }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                Section(header: Text("カスタマイズ").font(.headline)) {
                    Text("仮想コントローラーに L/R・FPS・Reset ボタンを含む全ボタンを配置できます。位置が崩れた場合はレイアウトエディターのリセットを使ってください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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

                Divider()

                Section(header: Text("PC互換設定").font(.headline)) {
                    Toggle("メニューに設定項目を表示", isOn: $config.settingsInMenu)
                        .onChange(of: config.settingsInMenu) { _, _ in config.saveSettings() }

                    Picker("起動時言語選択", selection: $config.languageSelectOnStart) {
                        Text("しない").tag(0)
                        Text("初回のみ").tag(1)
                        Text("毎回").tag(2)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: config.languageSelectOnStart) { _, _ in config.saveSettings() }

                    Toggle("タイトル画面に設定項目を表示", isOn: $config.settingsInTitle)
                        .onChange(of: config.settingsInTitle) { _, _ in config.saveSettings() }
                    Toggle("タイトル画面に言語選択を表示", isOn: $config.languageInTitle)
                        .onChange(of: config.languageInTitle) { _, _ in config.saveSettings() }
                    Toggle("ログ出力を有効", isOn: $config.loggingEnabled)
                        .onChange(of: config.loggingEnabled) { _, _ in config.saveSettings() }
                    Toggle("スクリーンショットに日時付加", isOn: $config.screenshotTimestamp)
                        .onChange(of: config.screenshotTimestamp) { _, _ in config.saveSettings() }
                    Toggle("自動スクリーンショット", isOn: $config.automaticScreenshots)
                        .onChange(of: config.automaticScreenshots) { _, _ in config.saveSettings() }

                    HStack {
                        Text("スクリーンショット拡大率")
                        Spacer()
                        Text("\(config.screenshotScale)x").foregroundStyle(.secondary)
                    }
                    Slider(value: .init(get: { Double(config.screenshotScale) }, set: { config.screenshotScale = Int($0) }), in: 1...24, step: 1)
                        .onChange(of: config.screenshotScale) { _, _ in config.saveSettings() }

                    if config.automaticScreenshots {
                        HStack {
                            Text("自動撮影間隔(秒)")
                            Spacer()
                            Text("\(config.automaticScreenshotsInterval)").foregroundStyle(.secondary)
                        }
                        Slider(value: .init(get: { Double(config.automaticScreenshotsInterval) }, set: { config.automaticScreenshotsInterval = Int($0) }), in: 1...600, step: 1)
                            .onChange(of: config.automaticScreenshotsInterval) { _, _ in config.saveSettings() }
                    }

                    Picker("起動ロゴ表示", selection: $config.startupLogos) {
                        Text("なし").tag(0)
                        Text("カスタムのみ").tag(1)
                        Text("すべて").tag(2)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: config.startupLogos) { _, _ in config.saveSettings() }
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
                        TextField("フォント名（例: VL Gothic）", text: Binding(
                            get: { config.font1Name ?? "" },
                            set: { config.font1Name = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: config.font1Name) { _, _ in config.saveSettings() }

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
                        TextField("フォント名（例: M+ 1m）", text: Binding(
                            get: { config.font2Name ?? "" },
                            set: { config.font2Name = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: config.font2Name) { _, _ in config.saveSettings() }

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
        AppLogger.log("ENTER makeUIViewController")
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        AppLogger.log("ENTER updateUIViewController")
    }

    func makeCoordinator() -> Coordinator {
        AppLogger.log("ENTER makeCoordinator")
        Coordinator(onPicked: onPicked)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPicked: (URL) -> Void

        init(onPicked: @escaping (URL) -> Void) {
            self.onPicked = onPicked
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            AppLogger.log("ENTER documentPicker")
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
        AppLogger.log("ENTER makeUIViewController")
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        AppLogger.log("ENTER updateUIViewController")
    }

    func makeCoordinator() -> Coordinator {
        AppLogger.log("ENTER makeCoordinator")
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
            AppLogger.log("ENTER documentPicker")
            if let url = urls.first {
                onPicked(url)
            }
            dismiss()
        }
    }
}
