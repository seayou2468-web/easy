import SwiftUI

private final class TouchPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        if hitView === rootViewController?.view {
            return nil
        }
        return hitView
    }
}

private final class VirtualControllerOverlayWindowManager {
    static let shared = VirtualControllerOverlayWindowManager()
    private var overlayWindow: TouchPassthroughWindow?
    private weak var overlayScene: UIWindowScene?
    private var overlayHost: UIHostingController<AnyView>?
    private var keepAliveTimer: Timer?

    func present(
        layoutStore: VirtualControllerLayoutStore,
        config: ConfigManager,
        onDirectionInput: @escaping (String, Bool) -> Void,
        onButtonInput: @escaping (String, Bool) -> Void
    ) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        if overlayWindow == nil || overlayScene !== scene {
            let window = TouchPassthroughWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.windowLevel = preferredOverlayLevel(in: scene)
            let host = UIHostingController(rootView: AnyView(EmptyView()))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            overlayHost = host
            overlayWindow = window
            overlayScene = scene
        }

        if let window = overlayWindow {
            window.windowLevel = preferredOverlayLevel(in: scene)
        }

        overlayHost?.rootView = AnyView(
            VirtualControllerView(
                layoutStore: layoutStore,
                config: config,
                onDirectionInput: onDirectionInput,
                onButtonInput: onButtonInput
            )
            .ignoresSafeArea()
            .background(Color.clear)
        )

        if let rootView = overlayHost?.view {
            rootView.setNeedsLayout()
            rootView.layoutIfNeeded()
        }

        overlayWindow?.isHidden = false
    }

    func dismiss() {
        stopKeepAlive()
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayHost = nil
        overlayScene = nil
        overlayWindow = nil
    }

    func keepInFrontTemporarily(
        layoutStore: VirtualControllerLayoutStore,
        config: ConfigManager,
        onDirectionInput: @escaping (String, Bool) -> Void,
        onButtonInput: @escaping (String, Bool) -> Void
    ) {
        stopKeepAlive()
        var tick = 0
        let maxTick = 30
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.present(
                layoutStore: layoutStore,
                config: config,
                onDirectionInput: onDirectionInput,
                onButtonInput: onButtonInput
            )
            tick += 1
            if tick >= maxTick {
                timer.invalidate()
                self.keepAliveTimer = nil
            }
        }
    }

    private func stopKeepAlive() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil
    }

    private func preferredOverlayLevel(in scene: UIWindowScene) -> UIWindow.Level {
        // `scene.windows` also contains our own overlay window once it is visible.
        // Exclude it to avoid self-referential level escalation on repeated present().
        let highestSceneLevel = scene.windows
            .map(\.windowLevel)
            .max() ?? .normal
        let minimumOverlayLevel = UIWindow.Level.alert + 1
        return max(minimumOverlayLevel, highestSceneLevel + 1)
    }
}

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
    @State private var hasInitializedPlayer = false
    @State private var hasProjectSecurityScopeAccess = false
    @State private var projectSecurityScopeURL: URL?
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
        .zIndex(1000)
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
        .fullScreenCover(isPresented: $showLayoutEditor) {
            NavigationStack {
                VirtualControllerEditorView()
            }
            .interactiveDismissDisabled(true)
            .onDisappear {
                layoutStore.load()
            }
        }
        .fullScreenCover(isPresented: $showButtonMapping) {
            NavigationStack { ButtonMappingEditorView() }
        }
        .fullScreenCover(isPresented: $showSettings) {
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
            guard !hasInitializedPlayer else { return }
            hasInitializedPlayer = true
            uiVisible = true
            AppLogger.log("PlayerView onAppear game=\(game.path)")
            setupPlayerWithGame()
            presentVirtualControllerOverlayWindow()
            keepOverlayInFrontTemporarily()
            applySettings()
            buttonMappingStore.applyToPlayer()
        }
        .onDisappear {
            AppLogger.log("PlayerView onDisappear")
            VirtualControllerOverlayWindowManager.shared.dismiss()
            releaseProjectSecurityScope()
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

    private func presentVirtualControllerOverlayWindow() {
        VirtualControllerOverlayWindowManager.shared.present(
            layoutStore: layoutStore,
            config: config,
            onDirectionInput: handleDirectionInput,
            onButtonInput: handleButtonInput
        )
    }

    private func keepOverlayInFrontTemporarily() {
        VirtualControllerOverlayWindowManager.shared.keepInFrontTemporarily(
            layoutStore: layoutStore,
            config: config,
            onDirectionInput: handleDirectionInput,
            onButtonInput: handleButtonInput
        )
    }

    private func setupPlayerWithGame() {
        AppLogger.log("ENTER setupPlayerWithGame")
        let projectURL = URL(fileURLWithPath: game.path).standardizedFileURL
        projectSecurityScopeURL = projectURL
        hasProjectSecurityScopeAccess = projectURL.startAccessingSecurityScopedResource()

        let absoluteProjectPath = projectURL.path
        guard FileManager.default.fileExists(atPath: absoluteProjectPath) else {
            AppLogger.log("Project path does not exist: \(absoluteProjectPath)")
            return
        }

        let projectPath = normalizedPathForLaunch(projectURL)

        AppLogger.log("setupPlayerWithGame projectPath=\(projectPath)")
        var args: [String] = ["--project-path", projectPath]

        let resolvedSavePath = resolveSavePath(projectPath: absoluteProjectPath, rawSavePath: game.savePath)
        if let savePath = resolvedSavePath, !savePath.isEmpty {
            args.append("--save-path")
            args.append(pathForLaunch(fromAbsolutePath: savePath))
        }

        if let configPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.path {
            args.append("--config-path")
            args.append(pathForLaunch(fromAbsolutePath: configPath))
            args.append("--log-file")
            args.append(pathForLaunch(fromAbsolutePath: "\(configPath)/easyrpg-player.log"))
        }

        if game.encoding != "auto" {
            args.append("--encoding")
            args.append(game.encoding)
        }

        // Launch args must be registered before runtime starts, otherwise
        // the core can boot into the generic PC-style menu without project context.
        // LaunchGame registers args first and starts runtime internally.
        // This guarantees Player::Init sees --project-path on first boot.
        PlayerBridge.launchGame(withArgs: args)
    }

    private func releaseProjectSecurityScope() {
        AppLogger.log("ENTER releaseProjectSecurityScope")
        guard hasProjectSecurityScopeAccess, let scopeURL = projectSecurityScopeURL else {
            projectSecurityScopeURL = nil
            return
        }

        scopeURL.stopAccessingSecurityScopedResource()
        hasProjectSecurityScopeAccess = false
        projectSecurityScopeURL = nil
    }


    private func normalizedPathForLaunch(_ url: URL) -> String {
        pathForLaunch(fromAbsolutePath: url.standardizedFileURL.path)
    }

    private func pathForLaunch(fromAbsolutePath absolutePath: String) -> String {
        let standardized = URL(fileURLWithPath: absolutePath).standardizedFileURL.path
        let homePath = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.path

        // Match in-engine fallback browser behavior: prefer sandbox-home-relative paths
        // when launching content inside the app container. This avoids environment-
        // specific absolute prefixes (e.g. LiveContainer mount differences).
        if standardized == homePath {
            return "."
        }

        if standardized.hasPrefix(homePath + "/") {
            return String(standardized.dropFirst(homePath.count + 1))
        }

        // Keep absolute paths for locations outside the app home.
        return standardized
    }

    private func resolveSavePath(projectPath: String, rawSavePath: String) -> String? {
        AppLogger.log("ENTER resolveSavePath")
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
        AppLogger.log("ENTER applySettings")
        PlayerBridge.setFullscreen(config.fullscreen)
        PlayerBridge.setForcedLandscape(config.forcedLandscape)
        PlayerBridge.setImageScaleMode(config.scaleMode)
        PlayerBridge.setStretch(config.stretch)
        PlayerBridge.setGameResolution(config.gameResolution)

        PlayerBridge.setMusicVolume(config.musicVolume)
        PlayerBridge.setSoundVolume(config.soundVolume)
        if let soundFont = config.selectedSoundFont {
            PlayerBridge.setSoundFont(pathForLaunch(fromAbsolutePath: soundFont.path))
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
        // Force highest diagnostics during current iOS troubleshooting.
        PlayerBridge.setConfigBool(section: "Player", key: "Logging", value: true)
        PlayerBridge.setConfigBool(section: "Player", key: "ScreenshotTimestamp", value: config.screenshotTimestamp)
        PlayerBridge.setConfigBool(section: "Player", key: "AutomaticScreenshots", value: config.automaticScreenshots)
        PlayerBridge.setConfigInt(section: "Player", key: "ScreenshotScale", value: config.screenshotScale)
        PlayerBridge.setConfigInt(section: "Player", key: "AutomaticScreenshotsInterval", value: config.automaticScreenshotsInterval)
        PlayerBridge.setConfigInt(section: "Player", key: "StartupLogos", value: config.startupLogos)
        applyVirtualLayoutToPlayer()
    }

    private func applyVirtualLayoutToPlayer() {
        AppLogger.log("ENTER applyVirtualLayoutToPlayer")
        for button in layoutStore.buttons {
            let mappedX = button.x <= 1.0 ? button.x * 450.0 : button.x
            let mappedY = button.y <= 1.0 ? button.y * 500.0 : button.y
            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: mappedX, y: mappedY)
        }
    }

    private func handleDirectionInput(direction: String, isPressed: Bool) {
        AppLogger.log("ENTER handleDirectionInput")
        let buttonId = ["up": "up", "down": "down", "left": "left", "right": "right"][direction] ?? direction
        if isPressed {
            PlayerBridge.sendKeyDown(buttonId)
        } else {
            PlayerBridge.sendKeyUp(buttonId)
        }
    }

    private func handleButtonInput(buttonId: String, isPressed: Bool) {
        AppLogger.log("ENTER handleButtonInput")
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

    private var effectiveOpacity: Double {
        // Keep controller visible even when a broken/legacy value is loaded.
        max(0.25, min(1.0, Double(config.layoutTransparency) / 255.0))
    }

    var body: some View {
        GeometryReader { geo in
            let geometryWidth = geo.size.width
            let geometryHeight = geo.size.height

            ZStack {
                ForEach(layoutStore.buttons) { button in
                    VirtualButtonView(
                        button: button,
                        isPressed: pressedButtons.contains(button.id),
                        opacity: effectiveOpacity,
                        size: calculateButtonSize(),
                        config: config
                    )
                    .position(
                        x: button.x <= 1.0 ? button.x * geometryWidth : button.x,
                        y: button.y <= 1.0 ? button.y * geometryHeight : button.y
                    )
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }

    private func calculateButtonSize() -> CGFloat {
        AppLogger.log("ENTER calculateButtonSize")
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
            Group {
                if isDirectional {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(opacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    Circle()
                        .fill(Color.white.opacity(opacity))
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        )
        .scaleEffect(isPressed ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }

    private var isDirectional: Bool {
        ["up", "down", "left", "right"].contains(button.id)
    }

    private func displayTitle() -> String {
        AppLogger.log("ENTER displayTitle")
        if config.showABasZX {
            if button.id == "z" || button.id == "decision" { return "A" }
            if button.id == "x" || button.id == "cancel" { return "B" }
        }
        if button.id == "fast_forward_a" && config.fastForwardMode == 1 {
            return "⏩"
        }
        if button.id == "menu" { return "≡" }
        if button.id == "debug_menu" { return "M" }
        if button.id == "debug_through" { return "T" }
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
