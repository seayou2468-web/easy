import SwiftUI

private struct RuntimeViewport: Equatable {
    var size: CGSize = .zero

    var isLandscape: Bool {
        size.width > size.height
    }

    static let zero = RuntimeViewport()
}

private enum IOSDisplayCoordinator {
    static func isLandscape(viewport: RuntimeViewport) -> Bool {
        if viewport.size.width > 0 && viewport.size.height > 0 {
            return viewport.isLandscape
        }
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            return scene.interfaceOrientation.isLandscape
        }
        return UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    static func gameplayFrame(in viewport: RuntimeViewport) -> CGRect {
        let size = viewport.size
        guard size.width > 0, size.height > 0 else { return .zero }
        // Android parity: EasyRpgPlayerActivity#updateScreenPosition()
        // width = screenWidth, height = screenWidth * 0.75, anchored top-left.
        let width = size.width
        let height = min(size.height, width * 0.75)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    static func applyGameplayFrameToSDLView(viewport: RuntimeViewport) {
        let frame = gameplayFrame(in: viewport)
        guard frame.width > 0, frame.height > 0 else { return }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        for window in scene.windows where !window.isHidden {
            if let sdlView = findSDLView(in: window) {
                if sdlView.frame != frame {
                    sdlView.frame = frame
                    sdlView.setNeedsLayout()
                    sdlView.layoutIfNeeded()
                }
            }
        }
    }

    private static func findSDLView(in root: UIView) -> UIView? {
        let name = NSStringFromClass(type(of: root))
        if name.localizedCaseInsensitiveContains("SDL") { return root }
        for v in root.subviews {
            if let found = findSDLView(in: v) { return found }
        }
        return nil
    }
}

private enum IOSInputCoordinator {
    static func applyVirtualLayout(layoutStore: VirtualControllerLayoutStore, viewport: RuntimeViewport) {
        let isLandscape = IOSDisplayCoordinator.isLandscape(viewport: viewport)
        for button in layoutStore.buttons(isLandscape: isLandscape) {
            let normalizedX = min(max(0.0, button.x), 1.0)
            let normalizedY = min(max(0.0, button.y), 1.0)
            PlayerBridge.setVirtualButtonPoint(buttonId: button.id, x: normalizedX, y: normalizedY)
        }
    }

    static func sendButton(buttonId: String, isPressed: Bool, showMenu: () -> Void, config: ConfigManager, fastForwardAToggleActive: inout Bool) {
        if buttonId == "menu" {
            if !isPressed { showMenu() }
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

        if isPressed { PlayerBridge.sendKeyDown(buttonId) } else { PlayerBridge.sendKeyUp(buttonId) }
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
    @State private var runtimeViewport: RuntimeViewport = .zero
    @StateObject private var layoutStore = VirtualControllerLayoutStore()
    @StateObject private var buttonMappingStore = ButtonMappingStore()
    @StateObject private var config = ConfigManager.shared

    @ViewBuilder
    private var virtualControllerLayer: some View {
        if config.touchUI {
            VirtualControllerView(
                layoutStore: layoutStore,
                config: config,
                onDirectionInput: handleDirectionInput,
                onButtonInput: handleButtonInput,
                viewport: runtimeViewport
            )
            .ignoresSafeArea()
        }
    }

    var body: some View {
        GeometryReader { rootGeo in
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
                .allowsHitTesting(!config.touchUI)

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

            virtualControllerLayer
            }
            .onAppear {
                runtimeViewport = RuntimeViewport(size: rootGeo.size)
                IOSDisplayCoordinator.applyGameplayFrameToSDLView(viewport: runtimeViewport)
            }
            .onChange(of: rootGeo.size) { _, newSize in
                runtimeViewport = RuntimeViewport(size: newSize)
                IOSDisplayCoordinator.applyGameplayFrameToSDLView(viewport: runtimeViewport)
                scheduleOrientationRealignment()
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
            applySettings()
            applyPreferredOrientationMode()
            buttonMappingStore.applyToPlayer()
        }
        .onDisappear {
            AppLogger.log("PlayerView onDisappear")
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
            let d = UIDevice.current.orientation
            if d == .landscapeLeft || d == .landscapeRight || d == .portrait || d == .portraitUpsideDown {
                scheduleOrientationRealignment()
            }
        }
        .onChange(of: buttonMappingStore.mappings) { _, _ in
            buttonMappingStore.applyToPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .configManagerDidSaveSettings)) { _ in
            applySettings()
            applyPreferredOrientationMode()
        }
    }

    private func scheduleOrientationRealignment() {
        orientationSettleTask?.cancel()

        // Android parity-style behavior: apply one deterministic realignment
        // after rotation settles, avoid repeated overlay churn.
        let task = DispatchWorkItem {
            applyVirtualLayoutToPlayer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                applyVirtualLayoutToPlayer()
            }
        }

        orientationSettleTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: task)
    }

    private func applyPreferredOrientationMode() {
        // Android parity: do not force runtime geometry updates here.
        // Orientation policy is handled by app-level settings/system rotation.
    }


    private func restoreDefaultOrientationMode() {
        // Android parity: no per-view geometry reset requests.
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
        IOSInputCoordinator.applyVirtualLayout(layoutStore: layoutStore, viewport: runtimeViewport)
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
        IOSInputCoordinator.sendButton(buttonId: buttonId, isPressed: isPressed, showMenu: { showMenu = true }, config: config, fastForwardAToggleActive: &fastForwardAToggleActive)
    }
}

struct VirtualControllerView: View {
    @ObservedObject var layoutStore: VirtualControllerLayoutStore
    @ObservedObject var config: ConfigManager
    let onDirectionInput: (String, Bool) -> Void
    let onButtonInput: (String, Bool) -> Void
    let viewport: RuntimeViewport

    @State private var pressedButtons: Set<String> = []
    @State private var activeDirection: String?

    private var effectiveOpacity: Double {
        // Keep controller visible even when a broken/legacy value is loaded.
        max(0.0, min(1.0, Double(255 - config.layoutTransparency) / 255.0))
    }

    var body: some View {
        GeometryReader { geo in
            let gameplayFrame = IOSDisplayCoordinator.gameplayFrame(
                in: RuntimeViewport(size: geo.size)
            )
            let geometryWidth = gameplayFrame.width > 0 ? gameplayFrame.width : geo.size.width
            let geometryHeight = gameplayFrame.height > 0 ? gameplayFrame.height : geo.size.height
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
            .frame(width: geometryWidth, height: geometryHeight, alignment: .topLeading)
            .position(x: geometryWidth / 2.0, y: geometryHeight / 2.0)
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
            .contentShape(Rectangle())
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
        // Android parity (VirtualCross#setBounds):
        // iconSize_33 = int(realSize * 0.33), padding = int(realSize * 0.20)
        let iconSize33 = Int(size * 0.33)
        let padding = Int(size * 0.20)
        let realSize = Int(size)
        let px = Int(point.x)
        let py = Int(point.y)

        let leftRect = CGRect(
            x: CGFloat(-padding),
            y: CGFloat(iconSize33),
            width: CGFloat(realSize - 2 * iconSize33 + padding),
            height: CGFloat(realSize - 2 * iconSize33 + padding)
        )
        let rightRect = CGRect(
            x: CGFloat(2 * iconSize33),
            y: CGFloat(iconSize33),
            width: CGFloat(realSize - 2 * iconSize33 + padding),
            height: CGFloat(realSize - 2 * iconSize33 + padding)
        )
        let upRect = CGRect(
            x: CGFloat(iconSize33),
            y: CGFloat(-padding),
            width: CGFloat(realSize - 2 * iconSize33),
            height: CGFloat(realSize - 2 * iconSize33)
        )
        let downRect = CGRect(
            x: CGFloat(iconSize33),
            y: CGFloat(2 * iconSize33),
            width: CGFloat(realSize - 2 * iconSize33),
            height: CGFloat(realSize - 2 * iconSize33 + padding)
        )

        let p = CGPoint(x: px, y: py)
        if leftRect.contains(p) { return "left" }
        if rightRect.contains(p) { return "right" }
        if upRect.contains(p) { return "up" }
        if downRect.contains(p) { return "down" }
        return nil
    }

    private func sizeFor(_ button: VirtualButtonLayout) -> CGFloat {
        Self.visualSize(for: button, config: config, viewport: viewport)
    }

    static func visualSize(for button: VirtualButtonLayout, config: ConfigManager, viewport: RuntimeViewport) -> CGFloat {
        let baseSize = viewport.size == .zero ? UIScreen.main.bounds.size : viewport.size
        let screenMin = min(baseSize.width, baseSize.height)
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
        .highPriorityGesture(
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
        // SwiftUI DragGesture location is already in local coordinates of the button view.
        // Using startLocation+translation can drift on rotation/layout updates and miss taps.
        let currentPoint = value.location

        // Android parity (VirtualButton): keep press only while pointer stays within button bounds.
        let buttonRect = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)
        let isInside = buttonRect.contains(currentPoint)

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
        pressedButtons.remove(button.instanceId)
        sendPress(for: button.id, isPressed: false)
    }

    private func releaseAllVirtualInputs() {
        if let dir = activeDirection {
            onDirectionInput(dir, false)
            activeDirection = nil
        }

        if !pressedButtons.isEmpty {
            let buttons = layoutStore.buttons(isLandscape: IOSDisplayCoordinator.isLandscape(viewport: viewport))
            let pressedIds = Set(pressedButtons)
            for button in buttons where pressedIds.contains(button.instanceId) {
                sendPress(for: button.id, isPressed: false)
            }
            pressedButtons.removeAll()
        }
    }
}

private struct DPadCrossView: View {
    let opacity: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            AndroidDPadShape()
                .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
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
            AndroidStrokeText(text: displayTitle(), size: size * (25.0 / 60.0), opacity: opacity)
        }
        .frame(width: size, height: size)
        .background(
            Group {
                if button.id == "menu" {
                    MenuGlyphButtonShape()
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
                } else if button.id == "fast_forward_a" {
                    AndroidInsetRectShape()
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
                } else {
                    AndroidInsetCircleShape()
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
                }
            }
        )
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

    func makeUIView(context: Context) -> AndroidStrokeTextView {
        AndroidStrokeTextView()
    }

    func updateUIView(_ view: AndroidStrokeTextView, context: Context) {
        view.text = text
        view.fontSize = size
        view.alphaColor = max(0.0, min(1.0, opacity))
        view.setNeedsDisplay()
    }
}

private final class AndroidStrokeTextView: UIView {
    var text: String = ""
    var fontSize: CGFloat = 16
    var alphaColor: Double = 1.0

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), !text.isEmpty else { return }

        let color = UIColor.white.withAlphaComponent(alphaColor)
        let font = UIFont.boldSystemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let ns = text as NSString
        var bounds = ns.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     attributes: attrs,
                                     context: nil)

        // Android centers text manually and uses stroke paint only.
        let x = rect.midX - bounds.width / 2.0
        let y = rect.midY - bounds.height / 2.0

        ctx.setLineWidth(3.0)
        ctx.setLineJoin(.round)
        ctx.setTextDrawingMode(.stroke)
        color.setStroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        bounds.origin = CGPoint(x: x, y: y)
        ns.draw(in: bounds, withAttributes: [
            .font: font,
            .foregroundColor: UIColor.clear,
            .strokeColor: color,
            .strokeWidth: 3.0,
            .paragraphStyle: paragraph
        ])
    }
}

private struct AndroidInsetCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 5
        let r = rect.insetBy(dx: inset, dy: inset)
        return Path(ellipseIn: r)
    }
}

private struct AndroidInsetRectShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 5
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.addRect(r)
        return p
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
