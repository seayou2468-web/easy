import SwiftUI

private final class TouchPassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        // Pass through only when this window itself was hit.
        // Returning nil for the SwiftUI hosting root breaks DragGesture and taps.
        if hitView === self {
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
            window.frame = scene.coordinateSpace.bounds
            window.windowLevel = preferredOverlayLevel(in: scene)
            let host = UIHostingController(rootView: AnyView(EmptyView()))
            host.view.backgroundColor = .clear
            window.rootViewController = host
            overlayHost = host
            overlayWindow = window
            overlayScene = scene
        }

        if let window = overlayWindow {
            window.frame = scene.coordinateSpace.bounds
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
    @State private var showMenu = false
    @State private var showHud = true
    @State private var showLayoutEditor = false
    @State private var showButtonMapping = false
    @State private var showSettings = false
    @State private var showFpsIndicator = false
    @State private var hasInitializedPlayer = false
    @State private var orientationSettleTask: DispatchWorkItem?
    @State private var hasProjectSecurityScopeAccess = false
    @State private var projectSecurityScopeURL: URL?
    @State private var fastForwardAToggleActive = false
    @StateObject private var layoutStore = VirtualControllerLayoutStore()
    @StateObject private var buttonMappingStore = ButtonMappingStore()
    @StateObject private var config = ConfigManager.shared

    var body: some View {
        ZStack {
            // Keep SwiftUI layer transparent so the native EasyRPG render surface stays visible.
            Color.clear
                .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHud.toggle()
                    }
                }

            VStack {
                HStack(spacing: 10) {
                    if showHud {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.getDisplayTitle(labelMode: config.gameBrowserLabelMode))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("タップでHUDを表示/非表示")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    Button(action: { PlayerBridge.toggleFps(); showFpsIndicator = true }) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .opacity(showHud ? 1.0 : 0.0)
                    .allowsHitTesting(showHud)

                    Button(action: { showMenu = true }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .opacity(showHud ? 1.0 : 0.0)
                    .allowsHitTesting(showHud)

                    Spacer()
                }
                Spacer()
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false)
            )
            .opacity(showHud ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: showHud)

            if !showHud {
                VStack {
                    HStack {
                        Spacer()
                        Text("HUD")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(16)
                .allowsHitTesting(false)
            }

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
                onReset: { showResetConfirm = true },
                onEnd: { showEndConfirm = true }
            )
        }
        .fullScreenCover(isPresented: $showLayoutEditor) {
            NavigationStack {
                VirtualControllerEditorView()
            }
            
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
            AppLogger.log("PlayerView onAppear game=\(game.path)")
            setupPlayerWithGame()
            presentVirtualControllerOverlayWindow()
            keepOverlayInFrontTemporarily()
            applySettings()
            applyPreferredOrientationMode()
            buttonMappingStore.applyToPlayer()
        }
        .onDisappear {
            AppLogger.log("PlayerView onDisappear")
            VirtualControllerOverlayWindowManager.shared.dismiss()
            restoreDefaultOrientationMode()
            releaseProjectSecurityScope()
        }
        .onChange(of: showFpsIndicator) { _, isVisible in
            guard isVisible else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showFpsIndicator = false
            }
        }
        .onReceive(layoutStore.$profiles) { _ in
            applyVirtualLayoutToPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            scheduleOrientationRealignment()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didChangeStatusBarOrientationNotification)) { _ in
            scheduleOrientationRealignment()
        }
        .onChange(of: buttonMappingStore.mappings) { _, _ in
            buttonMappingStore.applyToPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .configManagerDidSaveSettings)) { _ in
            applySettings()
            applyPreferredOrientationMode()
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

    private func scheduleOrientationRealignment() {
        orientationSettleTask?.cancel()

        // iOS orientation transitions can report transient geometry values.
        // Re-apply overlay + layout several times so final settled bounds win.
        let task = DispatchWorkItem {
            presentVirtualControllerOverlayWindow()
            applyVirtualLayoutToPlayer()
            keepOverlayInFrontTemporarily()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                presentVirtualControllerOverlayWindow()
                applyVirtualLayoutToPlayer()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                presentVirtualControllerOverlayWindow()
                applyVirtualLayoutToPlayer()
            }
        }

        orientationSettleTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: task)
    }

    private func applyPreferredOrientationMode() {
        guard #available(iOS 16.0, *) else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        let mask: UIInterfaceOrientationMask = config.forcedLandscape ? .landscape : .allButUpsideDown
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        scene.requestGeometryUpdate(prefs) { error in
            AppLogger.log("requestGeometryUpdate failed: \(error.localizedDescription)")
        }
    }


    private func restoreDefaultOrientationMode() {
        guard #available(iOS 16.0, *) else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .allButUpsideDown)
        scene.requestGeometryUpdate(prefs) { error in
            AppLogger.log("restore orientation failed: \(error.localizedDescription)")
        }
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
        PlayerBridge.setConfigBool(section: "Video", key: "Fullscreen", value: config.fullscreen)
        PlayerBridge.setConfigBool(section: "Video", key: "ForceLandscape", value: config.forcedLandscape)
        PlayerBridge.setConfigBool(section: "Video", key: "Stretch", value: config.stretch)
        PlayerBridge.setConfigInt(section: "Video", key: "ScalingMode", value: config.scaleMode)
        PlayerBridge.setConfigInt(section: "Video", key: "GameResolution", value: config.gameResolution)
        PlayerBridge.setConfigInt(section: "Video", key: "GameBrowserLabelMode", value: config.gameBrowserLabelMode)

        PlayerBridge.setMusicVolume(config.musicVolume)
        PlayerBridge.setSoundVolume(config.soundVolume)
        PlayerBridge.setConfigInt(section: "Audio", key: "MusicVolume", value: config.musicVolume)
        PlayerBridge.setConfigInt(section: "Audio", key: "SoundVolume", value: config.soundVolume)
        PlayerBridge.setConfigBool(section: "Audio", key: "Fluidsynth", value: config.fluidsynthMidi)
        PlayerBridge.setConfigBool(section: "Audio", key: "WildMidi", value: config.wildMidi)
        PlayerBridge.setConfigBool(section: "Audio", key: "NativeMidi", value: config.nativeMidi)
        if let soundFont = config.selectedSoundFont {
            PlayerBridge.setSoundFont(pathForLaunch(fromAbsolutePath: soundFont.path))
            PlayerBridge.setConfigString(section: "Audio", key: "SoundFont", value: pathForLaunch(fromAbsolutePath: soundFont.path))
            PlayerBridge.setConfigString(section: "Audio", key: "Soundfont", value: pathForLaunch(fromAbsolutePath: soundFont.path))
        } else {
            PlayerBridge.setSoundFont("")
            PlayerBridge.setConfigString(section: "Audio", key: "SoundFont", value: "")
            PlayerBridge.setConfigString(section: "Audio", key: "Soundfont", value: "")
        }

        PlayerBridge.setLayoutTransparency(Double(config.layoutTransparency))
        PlayerBridge.setLayoutSize(Double(config.layoutSize))
        PlayerBridge.setVibrationEnabled(config.enableVibration)
        PlayerBridge.setVibrateWhenSlidingEnabled(config.vibrateWhenSliding)
        PlayerBridge.setConfigBool(section: "Input", key: "Vibration", value: config.enableVibration)
        PlayerBridge.setConfigBool(section: "Input", key: "VibrateWhenSliding", value: config.vibrateWhenSliding)
        PlayerBridge.setConfigBool(section: "Input", key: "ShowABasZX", value: config.showABasZX)
        PlayerBridge.setConfigBool(section: "Input", key: "GamepadSwapAnalog", value: config.gamepadSwapAnalog)
        PlayerBridge.setConfigBool(section: "Input", key: "GamepadSwapDpad", value: config.gamepadSwapDpad)
        PlayerBridge.setConfigBool(section: "Input", key: "GamepadSwapAbxy", value: config.gamepadSwapAbxy)
        PlayerBridge.setConfigInt(section: "Input", key: "FastForwardMode", value: config.fastForwardMode)
        PlayerBridge.setConfigInt(section: "Input", key: "LayoutTransparency", value: config.layoutTransparency)
        PlayerBridge.setConfigInt(section: "Input", key: "LayoutSize", value: config.layoutSize)
        PlayerBridge.setConfigBool(section: "Input", key: "IgnoreLayoutSize", value: config.ignoreLayoutSize)

        PlayerBridge.setFont1(config.font1Name ?? "")
        PlayerBridge.setFont2(config.font2Name ?? "")
        PlayerBridge.setConfigString(section: "Player", key: "Font1", value: config.font1Name ?? "")
        PlayerBridge.setConfigString(section: "Player", key: "Font2", value: config.font2Name ?? "")
        PlayerBridge.setFont1Size(config.font1Size)
        PlayerBridge.setFont2Size(config.font2Size)
        PlayerBridge.setConfigInt(section: "Player", key: "Font1Size", value: config.font1Size)
        PlayerBridge.setConfigInt(section: "Player", key: "Font2Size", value: config.font2Size)
        PlayerBridge.setConfigBool(section: "Player", key: "PreferExternalFonts", value: config.preferExternalFonts)
        PlayerBridge.setFastForwardSpeedA(config.fastForwardMultiplier)
        PlayerBridge.setFastForwardSpeedB(config.fastForwardMultiplierB)
        PlayerBridge.setConfigInt(section: "Input", key: "FastForwardMultiplier", value: config.fastForwardMultiplier)
        PlayerBridge.setConfigInt(section: "Input", key: "FastForwardMultiplierB", value: config.fastForwardMultiplierB)
        PlayerBridge.setConfigInt(section: "Input", key: "SpeedModifierA", value: config.fastForwardMultiplier)
        PlayerBridge.setConfigInt(section: "Input", key: "SpeedModifierB", value: config.fastForwardMultiplierB)
        PlayerBridge.setSettingsInMenu(config.settingsInMenu)
        PlayerBridge.setConfigBool(section: "Player", key: "SettingsAutosave", value: config.settingsAutosave)
        PlayerBridge.setConfigBool(section: "Player", key: "SettingsInMenu", value: config.settingsInMenu)
        PlayerBridge.setLanguageSelectOnStart(config.languageSelectOnStart)
        PlayerBridge.setConfigInt(section: "Player", key: "LanguageSelectOnStart", value: config.languageSelectOnStart)
        PlayerBridge.setConfigBool(section: "Player", key: "SettingsInTitle", value: config.settingsInTitle)
        PlayerBridge.setConfigBool(section: "Player", key: "LanguageInTitle", value: config.languageInTitle)
        PlayerBridge.setConfigBool(section: "Player", key: "Logging", value: config.loggingEnabled)
        PlayerBridge.setConfigBool(section: "Player", key: "ScreenshotTimestamp", value: config.screenshotTimestamp)
        PlayerBridge.setConfigBool(section: "Player", key: "AutomaticScreenshots", value: config.automaticScreenshots)
        PlayerBridge.setConfigInt(section: "Player", key: "ScreenshotScale", value: config.screenshotScale)
        PlayerBridge.setConfigInt(section: "Player", key: "AutomaticScreenshotsInterval", value: config.automaticScreenshotsInterval)
        PlayerBridge.setConfigInt(section: "Player", key: "StartupLogos", value: config.startupLogos)
        PlayerBridge.setConfigInt(section: "Player", key: "GameBrowserLabelMode", value: config.gameBrowserLabelMode)
        PlayerBridge.setConfigBool(section: "Player", key: "EnableRtpScanning", value: config.enableRtpScanning)
        PlayerBridge.setConfigBool(section: "Player", key: "HasCompletedOnboarding", value: config.hasCompletedOnboarding)
        if let easyRPGFolder = config.easyRPGFolderURL {
            PlayerBridge.setConfigString(section: "Player", key: "EasyRPGFolder", value: pathForLaunch(fromAbsolutePath: easyRPGFolder.path))
        } else {
            PlayerBridge.setConfigString(section: "Player", key: "EasyRPGFolder", value: "")
        }
        if let rtpFolder = config.rtpFolderURL {
            PlayerBridge.setConfigString(section: "Player", key: "RTPFolder", value: pathForLaunch(fromAbsolutePath: rtpFolder.path))
        } else {
            PlayerBridge.setConfigString(section: "Player", key: "RTPFolder", value: "")
        }
        applyVirtualLayoutToPlayer()
    }

    private func applyVirtualLayoutToPlayer() {
        AppLogger.log("ENTER applyVirtualLayoutToPlayer")
        let isLandscape: Bool = {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
                return UIScreen.main.bounds.width > UIScreen.main.bounds.height
            }
            return scene.interfaceOrientation.isLandscape
        }()
        for button in layoutStore.buttons(isLandscape: isLandscape) {
            // Keep bridge coordinates aligned with editor/runtime normalized layout.
            // Legacy fixed canvas mapping (450x500) caused large position drift.
            let normalizedX = min(max(0.0, button.x), 1.0)
            let normalizedY = min(max(0.0, button.y), 1.0)
            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: normalizedX, y: normalizedY)
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
        // Android parity: the virtual menu button opens/closes app menu on release
        // instead of sending an in-game key event.
        if buttonId == "menu" {
            if !isPressed {
                showMenu = true
            }
            return
        }

        if buttonId == "fast_forward_a" && config.fastForwardMode == 1 {
            if !isPressed {
                if fastForwardAToggleActive {
                    PlayerBridge.sendKeyUp(buttonId)
                    fastForwardAToggleActive = false
                } else {
                    PlayerBridge.sendKeyDown(buttonId)
                    fastForwardAToggleActive = true
                }
            }
            return
        }

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
    @State private var activeDirection: String?
    @State private var buttonTouchAnchors: [String: CGPoint] = [:]

    private var effectiveOpacity: Double {
        // Keep controller visible even when a broken/legacy value is loaded.
        max(0.0, min(1.0, Double(255 - config.layoutTransparency) / 255.0))
    }

    var body: some View {
        GeometryReader { geo in
            let geometryWidth = geo.size.width
            let geometryHeight = geo.size.height
            let isLandscape = geometryWidth > geometryHeight
            let buttons = layoutStore.buttons(isLandscape: isLandscape)
            let directional = buttons.filter { ["up", "down", "left", "right"].contains($0.id) }
            let others = buttons.filter { !["up", "down", "left", "right"].contains($0.id) }

            ZStack {
                if !directional.isEmpty {
                    runtimeDPadView(directional, geometryWidth: geometryWidth, geometryHeight: geometryHeight)
                }
                ForEach(others, id: \.instanceId) { button in
                    runtimeButtonView(button, geometryWidth: geometryWidth, geometryHeight: geometryHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(8)
        .onDisappear {
            releaseAllVirtualInputs()
        }
        // Do not add runtime-only horizontal offset: editor and runtime must share
        // the same coordinate space for position parity.
    }

    @ViewBuilder
    private func runtimeDPadView(_ buttons: [VirtualButtonLayout], geometryWidth: CGFloat, geometryHeight: CGFloat) -> some View {
        let centerX = buttons.map(\.x).reduce(0, +) / CGFloat(buttons.count)
        let centerY = buttons.map(\.y).reduce(0, +) / CGFloat(buttons.count)
        let refSize = buttons.map { sizeFor($0) }.max() ?? 64
        let dpadSize = refSize * 2.2

        DPadCrossView(opacity: effectiveOpacity, size: dpadSize)
            .position(x: centerX * geometryWidth, y: centerY * geometryHeight)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let direction = resolveDPadDirection(from: value.location, size: dpadSize)
                        if direction != activeDirection {
                            if let old = activeDirection { onDirectionInput(old, false) }
                            activeDirection = direction
                            if let direction {
                                onDirectionInput(direction, true)
                                if config.enableVibration && (config.vibrateWhenSliding || activeDirection == nil) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if let old = activeDirection { onDirectionInput(old, false) }
                        activeDirection = nil
                    }
            )
    }

    private func resolveDPadDirection(from point: CGPoint, size: CGFloat) -> String? {
        let third = size * 0.33
        let pad = size * 0.20
        let x = point.x
        let y = point.y
        let leftRect = CGRect(x: -pad, y: third, width: third + pad, height: third + pad)
        let rightRect = CGRect(x: third * 2, y: third, width: third + pad, height: third + pad)
        let upRect = CGRect(x: third, y: -pad, width: third, height: third + pad)
        let downRect = CGRect(x: third, y: third * 2, width: third, height: third + pad)

        if leftRect.contains(CGPoint(x: x, y: y)) { return "left" }
        if rightRect.contains(CGPoint(x: x, y: y)) { return "right" }
        if upRect.contains(CGPoint(x: x, y: y)) { return "up" }
        if downRect.contains(CGPoint(x: x, y: y)) { return "down" }
        return nil
    }

    private func sizeFor(_ button: VirtualButtonLayout) -> CGFloat {
        Self.visualSize(for: button, config: config)
    }

    static func visualSize(for button: VirtualButtonLayout, config: ConfigManager) -> CGFloat {
        let screenMin = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let androidParityBase = max(44, min(104, screenMin * 0.135))
        let manualBase = max(32, min(CGFloat(config.layoutSize) * 0.35, 96))
        let base: CGFloat = config.ignoreLayoutSize ? manualBase : androidParityBase
        return max(28, min(160, base * (CGFloat(button.size) / 100.0)))
    }

    private func sendPress(for buttonId: String, isPressed: Bool) {
        if ["up", "down", "left", "right"].contains(buttonId) {
            onDirectionInput(buttonId, isPressed)
        } else {
            onButtonInput(buttonId, isPressed)
        }
    }

    @ViewBuilder
    private func runtimeButtonView(_ button: VirtualButtonLayout, geometryWidth: CGFloat, geometryHeight: CGFloat) -> some View {
        let buttonSize = sizeFor(button)
        VirtualButtonView(
            button: button,
            isPressed: pressedButtons.contains(button.instanceId),
            opacity: effectiveOpacity,
            size: buttonSize,
            config: config
        )
        .position(
            x: button.x * geometryWidth,
            y: button.y * geometryHeight
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value: value, button: button, buttonSize: buttonSize)
                }
                .onEnded { _ in
                    handleDragEnded(button: button)
                }
        )
    }

    private func handleDragChanged(value: DragGesture.Value, button: VirtualButtonLayout, buttonSize: CGFloat) {
        // Android-like touch lifecycle:
        // - anchor at initial touch-down
        // - slide keeps press while within tolerance zone
        // - release when out; re-press if finger returns into zone
        if buttonTouchAnchors[button.instanceId] == nil {
            buttonTouchAnchors[button.instanceId] = value.startLocation
        }

        let anchor = buttonTouchAnchors[button.instanceId] ?? value.startLocation
        let translatedPoint = CGPoint(x: anchor.x + value.translation.width, y: anchor.y + value.translation.height)
        let slop = buttonSize * 0.22
        let minX = -slop
        let maxX = buttonSize + slop
        let minY = -slop
        let maxY = buttonSize + slop
        let isInside = translatedPoint.x >= minX && translatedPoint.x <= maxX && translatedPoint.y >= minY && translatedPoint.y <= maxY

        if isInside && !pressedButtons.contains(button.instanceId) {
            pressedButtons.insert(button.instanceId)
            sendPress(for: button.id, isPressed: true)
            if config.enableVibration {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else if !isInside && pressedButtons.contains(button.instanceId) {
            pressedButtons.remove(button.instanceId)
            sendPress(for: button.id, isPressed: false)
        }
    }

    private func handleDragEnded(button: VirtualButtonLayout) {
        buttonTouchAnchors.removeValue(forKey: button.instanceId)
        pressedButtons.remove(button.instanceId)
        sendPress(for: button.id, isPressed: false)
    }

    private func releaseAllVirtualInputs() {
        if let dir = activeDirection {
            onDirectionInput(dir, false)
            activeDirection = nil
        }

        if !pressedButtons.isEmpty {
            let buttons = layoutStore.buttons(isLandscape: UIScreen.main.bounds.width > UIScreen.main.bounds.height)
            let pressedIds = Set(pressedButtons)
            for button in buttons where pressedIds.contains(button.instanceId) {
                sendPress(for: button.id, isPressed: false)
            }
            pressedButtons.removeAll()
        }
        buttonTouchAnchors.removeAll()
    }
}

private struct DPadCrossView: View {
    let opacity: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            AndroidDPadShape()
                .stroke(Color.white.opacity(opacity), lineWidth: 3)
        }
        .frame(width: size, height: size)
    }

}

private struct AndroidDPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let oneThird = floor(s * 0.33)
        let twoThird = oneThird * 2
        let border: CGFloat = 5
        let minX = rect.minX + border
        let minY = rect.minY + border
        let maxX = rect.maxX - border
        let maxY = rect.maxY - border

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + oneThird, y: minY))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: minY))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: rect.minY + oneThird))
        p.addLine(to: CGPoint(x: maxX, y: rect.minY + oneThird))
        p.addLine(to: CGPoint(x: maxX, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: maxY))
        p.addLine(to: CGPoint(x: rect.minX + oneThird, y: maxY))
        p.addLine(to: CGPoint(x: rect.minX + oneThird, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: minX, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: minX, y: rect.minY + oneThird))
        p.addLine(to: CGPoint(x: rect.minX + oneThird, y: rect.minY + oneThird))
        p.closeSubpath()
        return p
    }
}

struct VirtualButtonView: View {
    let button: VirtualButtonLayout
    let isPressed: Bool
    let opacity: Double
    let size: CGFloat
    @ObservedObject var config: ConfigManager

    var body: some View {
        ZStack {
            AndroidStrokeText(text: displayTitle(), size: size * 0.26, opacity: opacity)
        }
        .frame(width: size, height: size)
        .background(
            Group {
                if isDirectional {
                    Circle()
                        .stroke(Color.white.opacity(opacity), lineWidth: 3)
                } else {
                    if button.id == "menu" {
                        MenuGlyphButtonShape()
                            .stroke(Color.white.opacity(opacity), lineWidth: 3)
                    } else if button.id == "fast_forward_a" {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.white.opacity(opacity), lineWidth: 3)
                    } else {
                        Circle()
                            .stroke(Color.white.opacity(opacity), lineWidth: 3)
                    }
                }
            }
        )
    }

    private var isDirectional: Bool {
        ["up", "down", "left", "right"].contains(button.id)
    }

    private func displayTitle() -> String {
        if config.showABasZX {
            if button.id == "z" || button.id == "decision" { return "Z" }
            if button.id == "x" || button.id == "cancel" { return "X" }
        }
        if button.id == "fast_forward_a" && config.fastForwardMode == 1 {
            return "»"
        }
        if button.id == "debug_menu" { return "M" }
        if button.id == "debug_through" { return "T" }
        return button.title
    }
}


private struct AndroidStrokeText: UIViewRepresentable {
    let text: String
    let size: CGFloat
    let opacity: Double

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.1
        label.numberOfLines = 1
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let color = UIColor.white.withAlphaComponent(max(0.0, min(1.0, opacity)))
        let font = UIFont.boldSystemFont(ofSize: size)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        // Android uses Paint.Style.STROKE with width ~3 and white color.
        // Using negative strokeWidth draws fill+stroke with the same color,
        // giving the same "double/outlined" appearance seen on Android.
        let attr = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .strokeColor: color,
            .strokeWidth: -3.0,
            .paragraphStyle: paragraph
        ])
        label.attributedText = attr
    }
}

private struct MenuGlyphButtonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height / 7
        for i in 0..<7 where i % 2 == 1 {
            let y = CGFloat(i) * h
            p.addRect(CGRect(x: rect.width / 6, y: y, width: rect.width * 4 / 6, height: h))
        }
        return p
    }
}

struct PlayerMenuSheet: View {
    let game: Game
    let onEditLayout: () -> Void
    let onEditButtonMapping: () -> Void
    let onOpenSettings: () -> Void
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
