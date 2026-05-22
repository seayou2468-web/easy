import SwiftUI

struct RuntimeViewport: Equatable {
    var size: CGSize = .zero

    var isLandscape: Bool {
        size.width > size.height
    }

    static let zero = RuntimeViewport()
}

enum IOSDisplayCoordinator {
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
        gameplayFrame(in: viewport.size)
    }

    static func gameplayFrame(in containerSize: CGSize, safeInsets: UIEdgeInsets = .zero) -> CGRect {
        guard containerSize.width > 0, containerSize.height > 0 else { return .zero }

        // Keep RPG frame aspect ratio (4:3) while fitting inside safe bounds.
        // This prevents overlap with notch/dynamic-island and avoids overflow on
        // repeated orientation changes.
        // iOS can transiently report unstable safeAreaInsets during window
        // creation/rotation. Clamp and fallback so gameplay frame never vanishes.
        let left = min(max(0, safeInsets.left), containerSize.width)
        let right = min(max(0, safeInsets.right), containerSize.width)
        let top = min(max(0, safeInsets.top), containerSize.height)
        let bottom = min(max(0, safeInsets.bottom), containerSize.height)

        let safeWidth = containerSize.width - left - right
        let safeHeight = containerSize.height - top - bottom

        let safeRect: CGRect
        if safeWidth > 1, safeHeight > 1 {
            safeRect = CGRect(x: left, y: top, width: safeWidth, height: safeHeight)
        } else {
            // Fallback to full bounds instead of returning .zero (black screen).
            safeRect = CGRect(x: 0, y: 0, width: containerSize.width, height: containerSize.height)
        }

        let aspect: CGFloat = 4.0 / 3.0
        let safeAspect = safeRect.width / safeRect.height

        let frameSize: CGSize
        if safeAspect > aspect {
            // Safe area is wider than 4:3, height-constrained fit.
            let height = safeRect.height
            frameSize = CGSize(width: height * aspect, height: height)
        } else {
            // Safe area is taller/narrower than 4:3, width-constrained fit.
            let width = safeRect.width
            frameSize = CGSize(width: width, height: width / aspect)
        }

        // Keep top edge at safe-area top (portrait: below notch/island), and
        // center horizontally within safe width to avoid side clipping.
        let x = safeRect.minX + (safeRect.width - frameSize.width) / 2.0
        let y = safeRect.minY

        // Keep final frame strictly inside safeRect. CGRect.integral expands
        // outward, which can reintroduce 1px overflow into notch/island area.
        let maxX = safeRect.maxX
        let maxY = safeRect.maxY
        let originX = ceil(x)
        let originY = ceil(y)
        let width = floor(min(frameSize.width, maxX - originX))
        let height = floor(min(frameSize.height, maxY - originY))
        guard width > 0, height > 0 else { return .zero }
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func applyGameplayFrameToSDLView() -> CGRect {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else { return .zero }

        var appliedFrame: CGRect = .zero
        for window in scene.windows where !window.isHidden {
            guard let sdlView = findSDLView(in: window), let container = sdlView.superview else { continue }

            // Android parity: updateScreenPosition() uses display width directly.
            // Compute in window/display space first, then convert to SDL container space.
            // Android parity intent: size from the active SDL display window.
            // If SDL is hosted in a different UIWindow than SwiftUI, using the
            // SwiftUI window here can push the surface off-screen.
            let baseWindow = sdlView.window ?? window
            let displayFrame = gameplayFrame(in: baseWindow.bounds.size, safeInsets: baseWindow.safeAreaInsets)
            guard displayFrame.width > 0, displayFrame.height > 0 else { continue }

            // Android parity: updateScreenPosition() applies x=0,y=0 in the
            // same parent layout that hosts the surface. Prefer direct parent-
            // local frame when container/window already match, fallback to
            // conversion only when needed.
            let frame: CGRect
            if container.window === baseWindow {
                // Keep safe-area-aware origin (x/y), not only size.
                frame = displayFrame
            } else {
                frame = container.convert(displayFrame, from: baseWindow)
            }

            if sdlView.frame != frame {
                UIView.performWithoutAnimation {
                    sdlView.frame = frame
                    sdlView.setNeedsLayout()
                    sdlView.layoutIfNeeded()
                }
            }

            // Android parity layering:
            // gameplay surface is below virtual-controller overlay.
            // iOS/SDL can host render view in a dedicated UIWindow, so enforce both
            // intra-container z-order and window stacking.
            if container.subviews.last !== sdlView {
                container.sendSubviewToBack(sdlView)
            }

            applyOverlayInputSafety(to: sdlView)
            appliedFrame = displayFrame
        }
        return appliedFrame
    }


    static func enforceSDLTouchPassthrough() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else { return }

        for window in scene.windows where !window.isHidden {
            guard let sdlView = findSDLView(in: window) else { continue }
            applyOverlayInputSafety(to: sdlView)
        }
    }

    private static func applyOverlayInputSafety(to sdlView: UIView) {
        // Keep the SDL surface from stealing touch events from the SwiftUI
        // virtual-controller overlay when SDL is hosted in its own UIWindow.
        // Gameplay input is routed through virtual button key events.
        sdlView.isUserInteractionEnabled = false
        if let sdlWindow = sdlView.window {
            let targetLevel = UIWindow.Level.normal - 1
            if sdlWindow.windowLevel >= UIWindow.Level.normal {
                sdlWindow.windowLevel = targetLevel
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

@MainActor
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
    @State private var showLayoutEditor = false
    @State private var showButtonMapping = false
    @State private var showSettings = false
    @State private var hasInitializedPlayer = false
    @State private var hasProjectSecurityScopeAccess = false
    @State private var projectSecurityScopeURL: URL?
    @State private var fastForwardAToggleActive = false
    @State private var runtimeViewport: RuntimeViewport = .zero
    @State private var gameplayFrame: CGRect = .zero
    @State private var lastSurfaceGeometryRevision: UInt32 = 0
    @StateObject private var layoutStore = VirtualControllerLayoutStore()
    @StateObject private var buttonMappingStore = ButtonMappingStore()
    @StateObject private var config = ConfigManager.shared

    private var touchUIEnabled: Bool {
        config.touchUI
    }

    @ViewBuilder
    private var virtualControllerLayer: some View {
        if touchUIEnabled {
            VirtualControllerView(
                layoutStore: layoutStore,
                config: config,
                onDirectionInput: handleDirectionInput,
                onButtonInput: handleButtonInput,
                viewport: runtimeViewport,
                gameplayFrame: gameplayFrame
            )
            .ignoresSafeArea()
            .allowsHitTesting(true)
            .zIndex(2000)
        }
    }

    @ViewBuilder
    private var runtimeSceneLayer: some View {
        // Keep SwiftUI layer transparent so the native EasyRPG render surface stays visible.
        Color.clear
            .ignoresSafeArea()

        virtualControllerLayer
    }

    var body: some View {
        GeometryReader { rootGeo in
            ZStack {
                runtimeSceneLayer
            }
            .onAppear {
                runtimeViewport = RuntimeViewport(size: rootGeo.size)
                applyAndroidParityScreenPositionAndInputLayout()
                IOSDisplayCoordinator.enforceSDLTouchPassthrough()
            }
            .onChange(of: rootGeo.size) { _, newSize in
                runtimeViewport = RuntimeViewport(size: newSize)
                applyAndroidParityScreenPositionAndInputLayout()
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
        .onReceive(layoutStore.$profiles) { _ in
            applyVirtualLayoutToPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let d = UIDevice.current.orientation
            if d == .landscapeLeft || d == .landscapeRight || d == .portrait || d == .portraitUpsideDown {
                applyAndroidParityScreenPositionAndInputLayout()
                IOSDisplayCoordinator.enforceSDLTouchPassthrough()
            }
        }
        .onChange(of: buttonMappingStore.mappings) { _, _ in
            buttonMappingStore.applyToPlayer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .configManagerDidSaveSettings)) { _ in
            applySettings()
            applyPreferredOrientationMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            applyAndroidParityScreenPositionAndInputLayout()
            IOSDisplayCoordinator.enforceSDLTouchPassthrough()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            applyAndroidParityScreenPositionAndInputLayout()
            IOSDisplayCoordinator.enforceSDLTouchPassthrough()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeVisibleNotification)) { _ in
            applyAndroidParityScreenPositionAndInputLayout()
            IOSDisplayCoordinator.enforceSDLTouchPassthrough()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)) { _ in
            applyAndroidParityScreenPositionAndInputLayout()
            IOSDisplayCoordinator.enforceSDLTouchPassthrough()
        }

        .onChange(of: config.touchUI) { _, _ in
            applyAndroidParityScreenPositionAndInputLayout()
        }
        .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in
            let rev = PlayerBridge.surfaceGeometryRevision()
            if rev != lastSurfaceGeometryRevision {
                lastSurfaceGeometryRevision = rev
                applyAndroidParityScreenPositionAndInputLayout()
            }
        }
    }

    private func applyAndroidParityScreenPositionAndInputLayout() {
        // Android parity: EasyRpgPlayerActivity calls updateScreenPosition()
        // and showInputLayout() once per event (onCreate/onConfigurationChanged/
        // surfaceChanged/onRestart). Mirror that ordering and call count.
        let frame = IOSDisplayCoordinator.applyGameplayFrameToSDLView()
        if frame.width > 0, frame.height > 0 {
            gameplayFrame = frame
        }
        applyVirtualLayoutToPlayer()
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
        PlayerBridge.setConfigBool(section: "Input", key: "TouchUI", value: config.touchUI)

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
