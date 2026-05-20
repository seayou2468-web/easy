import SwiftUI

struct PlayerView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss

    @State private var showEndConfirm = false
    @State private var showResetConfirm = false
    @State private var uiVisible = false
    @State private var showMenu = false
    @State private var showLayoutEditor = false
    @State private var showButtonMapping = false
    @State private var showSettings = false
    @State private var showFpsIndicator = false
    @State private var hasProjectSecurityScopeAccess = false
    @StateObject private var layoutStore = VirtualControllerLayoutStore()
    @StateObject private var buttonMappingStore = ButtonMappingStore()
    @StateObject private var config = ConfigManager.shared

    var body: some View {
        ZStack {
            // Keep SwiftUI layer transparent so the native EasyRPG render surface stays visible.
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if uiVisible {
                    // Header
                    VStack(spacing: 4) {
                        Text(game.getDisplayTitle(labelMode: config.gameBrowserLabelMode))
                            .font(.title3)
                            .bold()
                            .foregroundStyle(.white)

                        Text("プレイヤー実行中")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.vertical, 8)
                }

                Spacer()

                // Virtual Controller Area
                if uiVisible {
                    VirtualControllerView(
                        layoutStore: layoutStore,
                        config: config,
                        onDirectionInput: handleDirectionInput,
                        onButtonInput: handleButtonInput
                    )
                }

                Spacer()

                
            }
            .padding(.vertical, 16)

            // Show UI Button (when hidden)
            if !uiVisible {
                VStack {
                    HStack {
                        Button(action: { uiVisible = true }) {
                            Image(systemName: "eye")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(16)
            }


            VStack {
                HStack(spacing: 10) {
                    Button(action: { PlayerBridge.toggleFps(); showFpsIndicator = true }) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: { showMenu = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                Spacer()
            }
            .padding(16)

            if showFpsIndicator {
                VStack {
                    Text("FPS表示を切り替えました")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.top, 20)
                .transition(.opacity)
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .topBarLeading) {
                if uiVisible {
                    Button { showMenu = true } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                }
            }
        })
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .background(Color.clear)
        .sheet(isPresented: $showMenu) {
            PlayerMenuSheet(
                game: game,
                onEditLayout: { showLayoutEditor = true },
                onEditButtonMapping: { showButtonMapping = true },
                onOpenSettings: { showSettings = true },
                onToggleUI: { uiVisible.toggle() },
                onReset: { showResetConfirm = true },
                onEnd: { showEndConfirm = true }
            )
        }
        .sheet(isPresented: $showLayoutEditor) {
            VirtualControllerEditorView()
                .onDisappear {
                    layoutStore.load()
                }
        }
        .sheet(isPresented: $showButtonMapping) {
            ButtonMappingEditorView()
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ParitySettingsRootView()
            }
        }
        .alert("ゲームをリセットしますか？", isPresented: $showResetConfirm) {
            Button("キャンセル", role: .cancel) {}
            Button("リセット", role: .destructive) {
                PlayerBridge.resetGame()
            }
        }
        .alert("ゲームを終了してもよろしいですか？", isPresented: $showEndConfirm) {
            Button("いいえ", role: .cancel) {}
            Button("はい", role: .destructive) {
                PlayerBridge.endGame()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
        .onAppear {
            uiVisible = true
            setupPlayerWithGame()
            applySettings()
            buttonMappingStore.applyToPlayer()
        }
        .onDisappear {
            if hasProjectSecurityScopeAccess {
                URL(fileURLWithPath: game.path).standardizedFileURL.stopAccessingSecurityScopedResource()
                hasProjectSecurityScopeAccess = false
            }
        }
        .onChange(of: showFpsIndicator) { _, isVisible in
            guard isVisible else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showFpsIndicator = false
            }
        }
        .onChange(of: layoutStore.buttons) { _, _ in
            applyVirtualLayoutToPlayer()
        }
        .onChange(of: buttonMappingStore.mappings) { _, _ in
            buttonMappingStore.applyToPlayer()
        }
        .onReceive(config.objectWillChange) { _ in
            applySettings()
        }
    }

    private func setupPlayerWithGame() {
        let projectURL = URL(fileURLWithPath: game.path).standardizedFileURL
        hasProjectSecurityScopeAccess = projectURL.startAccessingSecurityScopedResource()

        let projectPath = projectURL.path
        guard FileManager.default.fileExists(atPath: projectPath) else {
            print("[iOS] Project path does not exist: \(projectPath)")
            return
        }

        PlayerBridge.startRuntime()

        var args: [String] = ["--project-path", projectPath]

        let resolvedSavePath = resolveSavePath(projectPath: projectPath, rawSavePath: game.savePath)
        if let savePath = resolvedSavePath, !savePath.isEmpty {
            args.append("--save-path")
            args.append(savePath)
        }

        if let configPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.path {
            args.append("--config-path")
            args.append(configPath)
            args.append("--log-file")
            args.append("\(configPath)/easyrpg-player.log")
        }

        if game.encoding != "auto" {
            args.append("--encoding")
            args.append(game.encoding)
        }

        // Keep launch behavior aligned with Android: one explicit launch command.
        PlayerBridge.launchGame(withArgs: args)
    }

    private func resolveSavePath(projectPath: String, rawSavePath: String) -> String? {
        guard !rawSavePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let savePathURL: URL
        if rawSavePath.hasPrefix("/") {
            savePathURL = URL(fileURLWithPath: rawSavePath)
        } else {
            savePathURL = URL(fileURLWithPath: projectPath).appendingPathComponent(rawSavePath)
        }

        return savePathURL.standardizedFileURL.path
    }

    private func applySettings() {
        PlayerBridge.setFullscreen(config.fullscreen)
        PlayerBridge.setForcedLandscape(config.forcedLandscape)
        PlayerBridge.setImageScaleMode(config.scaleMode)
        PlayerBridge.setStretch(config.stretch)
        PlayerBridge.setGameResolution(config.gameResolution)

        PlayerBridge.setMusicVolume(config.musicVolume)
        PlayerBridge.setSoundVolume(config.soundVolume)
        if let soundFont = config.selectedSoundFont {
            PlayerBridge.setSoundFont(soundFont.path)
        }

        PlayerBridge.setLayoutTransparency(Double(config.layoutTransparency))
        PlayerBridge.setLayoutSize(Double(config.layoutSize))
        PlayerBridge.setVibrationEnabled(config.enableVibration)
        PlayerBridge.setVibrateWhenSlidingEnabled(config.vibrateWhenSliding)

        PlayerBridge.setFont1(config.font1Name ?? "")
        PlayerBridge.setFont2(config.font2Name ?? "")
        PlayerBridge.setFont1Size(config.font1Size)
        PlayerBridge.setFont2Size(config.font2Size)
        PlayerBridge.setFastForwardSpeedA(config.fastForwardMultiplier)
        PlayerBridge.setFastForwardSpeedB(config.fastForwardMultiplierB)
        PlayerBridge.setSettingsInMenu(config.settingsInMenu)
        PlayerBridge.setLanguageSelectOnStart(config.languageSelectOnStart)
        PlayerBridge.setConfigBool(section: "Player", key: "SettingsInTitle", value: config.settingsInTitle)
        PlayerBridge.setConfigBool(section: "Player", key: "LanguageInTitle", value: config.languageInTitle)
        PlayerBridge.setConfigBool(section: "Player", key: "Logging", value: config.loggingEnabled)
        PlayerBridge.setConfigBool(section: "Player", key: "ScreenshotTimestamp", value: config.screenshotTimestamp)
        PlayerBridge.setConfigBool(section: "Player", key: "AutomaticScreenshots", value: config.automaticScreenshots)
        PlayerBridge.setConfigInt(section: "Player", key: "ScreenshotScale", value: config.screenshotScale)
        PlayerBridge.setConfigInt(section: "Player", key: "AutomaticScreenshotsInterval", value: config.automaticScreenshotsInterval)
        PlayerBridge.setConfigInt(section: "Player", key: "StartupLogos", value: config.startupLogos)
        applyVirtualLayoutToPlayer()
    }

    private func applyVirtualLayoutToPlayer() {
        for button in layoutStore.buttons {
            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: button.x, y: button.y)
        }
    }

    private func handleDirectionInput(direction: String, isPressed: Bool) {
        let buttonId = ["up": "up", "down": "down", "left": "left", "right": "right"][direction] ?? direction
        if isPressed {
            PlayerBridge.sendKeyDown(buttonId)
        } else {
            PlayerBridge.sendKeyUp(buttonId)
        }
    }

    private func handleButtonInput(buttonId: String, isPressed: Bool) {
        if isPressed {
            PlayerBridge.sendKeyDown(buttonId)
        } else {
            PlayerBridge.sendKeyUp(buttonId)
        }
    }
}

struct VirtualControllerView: View {
    @ObservedObject var layoutStore: VirtualControllerLayoutStore
    @ObservedObject var config: ConfigManager
    let onDirectionInput: (String, Bool) -> Void
    let onButtonInput: (String, Bool) -> Void

    @State private var pressedButtons: Set<String> = []

    var body: some View {
        ZStack {
            ForEach(layoutStore.buttons) { button in
                VirtualButtonView(
                    button: button,
                    isPressed: pressedButtons.contains(button.id),
                    opacity: Double(config.layoutTransparency) / 255.0,
                    size: calculateButtonSize(),
                    config: config
                )
                .position(x: button.x, y: button.y)
                .gesture(
                    LongPressGesture(minimumDuration: 0)
                        .onChanged { _ in
                            if !pressedButtons.contains(button.id) {
                                pressedButtons.insert(button.id)
                                onButtonInput(button.id, true)
                                if config.enableVibration {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                        .onEnded { _ in
                            pressedButtons.remove(button.id)
                            onButtonInput(button.id, false)
                        }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 240)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }

    private func calculateButtonSize() -> CGFloat {
        if config.ignoreLayoutSize {
            return 42
        }
        let size = CGFloat(config.layoutSize)
        return max(32, min(size * 0.35, 96))
    }
}

struct VirtualButtonView: View {
    let button: VirtualButtonLayout
    let isPressed: Bool
    let opacity: Double
    let size: CGFloat
    @ObservedObject var config: ConfigManager

    var body: some View {
        VStack(spacing: 2) {
            Text(displayTitle())
                .font(.caption2)
                .bold()
                .foregroundStyle(.black)
        }
        .frame(width: size, height: size)
        .background(
            Circle()
                .fill(Color.white.opacity(opacity))
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    private func displayTitle() -> String {
        if config.showABasZX {
            if button.id == "z" { return "A" }
            if button.id == "x" { return "B" }
        }
        if button.id == "fast_forward_a" && config.fastForwardMode == 1 {
            return "⏩"
        }
        return button.title
    }
}

struct PlayerMenuSheet: View {
    let game: Game
    let onEditLayout: () -> Void
    let onEditButtonMapping: () -> Void
    let onOpenSettings: () -> Void
    let onToggleUI: () -> Void
    let onReset: () -> Void
    let onEnd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("ゲーム情報")) {
                    HStack {
                        Text("タイトル")
                        Spacer()
                        Text(game.title).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("フォルダ")
                        Spacer()
                        Text(game.gameFolderName).font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("操作")) {
                    Button(action: { dismiss(); onToggleUI() }) {
                        HStack {
                            Image(systemName: "eye.slash")
                            Text("UI の表示/非表示")
                        }
                    }
                    Button(action: { dismiss(); onEditLayout() }) {
                        HStack {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("レイアウトエディター")
                        }
                    }
                    Button(action: { dismiss(); onEditButtonMapping() }) {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text("ボタン設定")
                        }
                    }
                }

                Section(header: Text("設定")) {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onOpenSettings() }
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("設定を開く")
                        }
                    }
                }

                Section(header: Text("ゲーム操作")) {
                    Button("FPS表示を切り替え") {
                        PlayerBridge.toggleFps()
                        dismiss()
                    }
                    Button("ゲームをリセット", role: .destructive) {
                        dismiss()
                        onReset()
                    }
                    Button("ゲームを終了", role: .destructive) {
                        dismiss()
                        onEnd()
                    }
                }
            }
            .navigationTitle("メニュー")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlayerView(game: Game(
        title: "Test Game",
        path: "/path/to/game",
        savePath: "/path/to/saves"
    ))
}
