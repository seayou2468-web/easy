import Foundation

extension Notification.Name {
    static let configManagerDidSaveSettings = Notification.Name("ConfigManagerDidSaveSettings")
}

@MainActor
final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    // Video settings
    @Published var fullscreen = true
    @Published var forcedLandscape = false
    @Published var scaleMode = 0 // 0: nearest, 1: integer, 2: bilinear
    @Published var stretch = false
    @Published var gameResolution = 0 // 0: original, 1: widescreen, 2: ultrawide
    @Published var gameBrowserLabelMode = 0 // 0: title, 1: folder name

    // Audio settings
    @Published var musicVolume = 100
    @Published var soundVolume = 100
    @Published var selectedSoundFont: URL? = nil
    @Published var fluidsynthMidi = true
    @Published var wildMidi = true
    @Published var nativeMidi = true

    // Input settings
    @Published var enableVibration = true
    @Published var vibrateWhenSliding = false
    @Published var showABasZX = false
    @Published var fastForwardMode = 0 // 0: hold, 1: tap
    @Published var fastForwardMultiplier = 3
    @Published var fastForwardMultiplierB = 10
    @Published var gamepadSwapAnalog = false
    @Published var gamepadSwapDpad = false
    @Published var gamepadSwapAbxy = false
    @Published var settingsAutosave = false
    @Published var settingsInMenu = false
    @Published var languageSelectOnStart = 0 // 0: never, 1: first startup, 2: always
    @Published var settingsInTitle = false
    @Published var languageInTitle = true
    @Published var loggingEnabled = true
    @Published var screenshotTimestamp = true
    @Published var automaticScreenshots = false
    @Published var screenshotScale = 1
    @Published var automaticScreenshotsInterval = 30
    @Published var startupLogos = 1 // 0 none, 1 custom, 2 all

    // Layout settings
    @Published var layoutTransparency = 100
    @Published var layoutSize = 100
    @Published var ignoreLayoutSize = false
    @Published var touchUI = true

    // Font settings
    @Published var preferExternalFonts = false
    @Published var font1Name: String? = nil
    @Published var font2Name: String? = nil
    @Published var font1Size = 12
    @Published var font2Size = 12

    // Folder settings
    @Published var easyRPGFolderURL: URL? = nil
    @Published var enableRtpScanning = true
    @Published var rtpFolderURL: URL? = nil
    @Published var hasCompletedOnboarding = false

    private let configFileName = "config.ini"
    private let userDefaultsPrefix = "ios.settings."
    private let easyRPGFolderBookmarkKey = "ios.bookmark.easyRPGFolder"
    private let rtpFolderBookmarkKey = "ios.bookmark.rtpFolder"
    private func defaultEasyRPGDocumentsFolder() -> URL? {
        AppLogger.log("ENTER defaultEasyRPGDocumentsFolder")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("EasyRPG", isDirectory: true)
    }

    private func isInsideDocuments(_ url: URL) -> Bool {
        AppLogger.log("ENTER isInsideDocuments")
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        let standardizedURL = url.standardizedFileURL.path
        let standardizedDocuments = documents.standardizedFileURL.path
        return standardizedURL == standardizedDocuments || standardizedURL.hasPrefix(standardizedDocuments + "/")
    }

    private var configURL: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent(configFileName)
    }

    private init() {
        loadSettings()
    }

    // MARK: - Settings Management

    private func intValue(_ defaults: UserDefaults, key: String, default defaultValue: Int) -> Int {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.integer(forKey: key)
    }

    func saveSettings() {
        AppLogger.log("ENTER saveSettings")
        AppLogger.log("saveSettings called")
        // Save to UserDefaults for quick access
        let defaults = UserDefaults.standard
        defaults.set(fullscreen, forKey: userDefaultsPrefix + "fullscreen")
        defaults.set(forcedLandscape, forKey: userDefaultsPrefix + "forcedLandscape")
        defaults.set(scaleMode, forKey: userDefaultsPrefix + "scaleMode")
        defaults.set(stretch, forKey: userDefaultsPrefix + "stretch")
        defaults.set(gameResolution, forKey: userDefaultsPrefix + "gameResolution")
        defaults.set(gameBrowserLabelMode, forKey: userDefaultsPrefix + "gameBrowserLabelMode")

        defaults.set(musicVolume, forKey: userDefaultsPrefix + "musicVolume")
        defaults.set(soundVolume, forKey: userDefaultsPrefix + "soundVolume")
        defaults.set(fluidsynthMidi, forKey: userDefaultsPrefix + "fluidsynthMidi")
        defaults.set(wildMidi, forKey: userDefaultsPrefix + "wildMidi")
        defaults.set(nativeMidi, forKey: userDefaultsPrefix + "nativeMidi")
        if let url = selectedSoundFont {
            defaults.set(url.absoluteString, forKey: userDefaultsPrefix + "selectedSoundFont")
        } else {
            defaults.removeObject(forKey: userDefaultsPrefix + "selectedSoundFont")
        }

        defaults.set(enableVibration, forKey: userDefaultsPrefix + "enableVibration")
        defaults.set(vibrateWhenSliding, forKey: userDefaultsPrefix + "vibrateWhenSliding")
        defaults.set(showABasZX, forKey: userDefaultsPrefix + "showABasZX")
        defaults.set(fastForwardMode, forKey: userDefaultsPrefix + "fastForwardMode")
        defaults.set(fastForwardMultiplier, forKey: userDefaultsPrefix + "fastForwardMultiplier")
        defaults.set(fastForwardMultiplierB, forKey: userDefaultsPrefix + "fastForwardMultiplierB")
        defaults.set(gamepadSwapAnalog, forKey: userDefaultsPrefix + "gamepadSwapAnalog")
        defaults.set(gamepadSwapDpad, forKey: userDefaultsPrefix + "gamepadSwapDpad")
        defaults.set(gamepadSwapAbxy, forKey: userDefaultsPrefix + "gamepadSwapAbxy")
        defaults.set(settingsAutosave, forKey: userDefaultsPrefix + "settingsAutosave")
        defaults.set(settingsInMenu, forKey: userDefaultsPrefix + "settingsInMenu")
        defaults.set(languageSelectOnStart, forKey: userDefaultsPrefix + "languageSelectOnStart")
        defaults.set(settingsInTitle, forKey: userDefaultsPrefix + "settingsInTitle")
        defaults.set(languageInTitle, forKey: userDefaultsPrefix + "languageInTitle")
        defaults.set(loggingEnabled, forKey: userDefaultsPrefix + "loggingEnabled")
        defaults.set(screenshotTimestamp, forKey: userDefaultsPrefix + "screenshotTimestamp")
        defaults.set(automaticScreenshots, forKey: userDefaultsPrefix + "automaticScreenshots")
        defaults.set(screenshotScale, forKey: userDefaultsPrefix + "screenshotScale")
        defaults.set(automaticScreenshotsInterval, forKey: userDefaultsPrefix + "automaticScreenshotsInterval")
        defaults.set(startupLogos, forKey: userDefaultsPrefix + "startupLogos")

        defaults.set(layoutTransparency, forKey: userDefaultsPrefix + "layoutTransparency")
        defaults.set(layoutSize, forKey: userDefaultsPrefix + "layoutSize")
        defaults.set(ignoreLayoutSize, forKey: userDefaultsPrefix + "ignoreLayoutSize")
        defaults.set(touchUI, forKey: userDefaultsPrefix + "touchUI")

        defaults.set(preferExternalFonts, forKey: userDefaultsPrefix + "preferExternalFonts")
        if let font1Name, !font1Name.isEmpty {
            defaults.set(font1Name, forKey: userDefaultsPrefix + "font1Name")
        } else {
            defaults.removeObject(forKey: userDefaultsPrefix + "font1Name")
        }
        if let font2Name, !font2Name.isEmpty {
            defaults.set(font2Name, forKey: userDefaultsPrefix + "font2Name")
        } else {
            defaults.removeObject(forKey: userDefaultsPrefix + "font2Name")
        }
        defaults.set(font1Size, forKey: userDefaultsPrefix + "font1Size")
        defaults.set(font2Size, forKey: userDefaultsPrefix + "font2Size")

        if let url = easyRPGFolderURL {
            defaults.set(url.absoluteString, forKey: userDefaultsPrefix + "easyRPGFolder")
        } else {
            defaults.removeObject(forKey: userDefaultsPrefix + "easyRPGFolder")
        }
        defaults.set(enableRtpScanning, forKey: userDefaultsPrefix + "enableRtpScanning")
        defaults.set(hasCompletedOnboarding, forKey: userDefaultsPrefix + "hasCompletedOnboarding")
        if let url = rtpFolderURL {
            defaults.set(url.absoluteString, forKey: userDefaultsPrefix + "rtpFolder")
        } else {
            defaults.removeObject(forKey: userDefaultsPrefix + "rtpFolder")
        }

        saveConfigToIni()
        NotificationCenter.default.post(name: .configManagerDidSaveSettings, object: nil)
    }

    private func loadSettings() {
        AppLogger.log("ENTER loadSettings")
        AppLogger.log("loadSettings called")
        let defaults = UserDefaults.standard
        fullscreen = defaults.object(forKey: userDefaultsPrefix + "fullscreen") as? Bool ?? fullscreen
        forcedLandscape = defaults.bool(forKey: userDefaultsPrefix + "forcedLandscape")
        scaleMode = defaults.integer(forKey: userDefaultsPrefix + "scaleMode")
        stretch = defaults.bool(forKey: userDefaultsPrefix + "stretch")
        gameResolution = defaults.integer(forKey: userDefaultsPrefix + "gameResolution")
        gameBrowserLabelMode = defaults.integer(forKey: userDefaultsPrefix + "gameBrowserLabelMode")

        musicVolume = intValue(defaults, key: userDefaultsPrefix + "musicVolume", default: 100)
        soundVolume = intValue(defaults, key: userDefaultsPrefix + "soundVolume", default: 100)
        fluidsynthMidi = defaults.object(forKey: userDefaultsPrefix + "fluidsynthMidi") as? Bool ?? true
        wildMidi = defaults.object(forKey: userDefaultsPrefix + "wildMidi") as? Bool ?? true
        nativeMidi = defaults.object(forKey: userDefaultsPrefix + "nativeMidi") as? Bool ?? true
        if let soundFontStr = defaults.string(forKey: userDefaultsPrefix + "selectedSoundFont") {
            selectedSoundFont = URL(string: soundFontStr)
        }

        enableVibration = defaults.object(forKey: userDefaultsPrefix + "enableVibration") as? Bool ?? enableVibration
        vibrateWhenSliding = defaults.bool(forKey: userDefaultsPrefix + "vibrateWhenSliding")
        showABasZX = defaults.bool(forKey: userDefaultsPrefix + "showABasZX")
        fastForwardMode = defaults.integer(forKey: userDefaultsPrefix + "fastForwardMode")
        fastForwardMultiplier = max(2, intValue(defaults, key: userDefaultsPrefix + "fastForwardMultiplier", default: 3))
        fastForwardMultiplierB = max(2, intValue(defaults, key: userDefaultsPrefix + "fastForwardMultiplierB", default: 10))
        gamepadSwapAnalog = defaults.bool(forKey: userDefaultsPrefix + "gamepadSwapAnalog")
        gamepadSwapDpad = defaults.bool(forKey: userDefaultsPrefix + "gamepadSwapDpad")
        gamepadSwapAbxy = defaults.bool(forKey: userDefaultsPrefix + "gamepadSwapAbxy")
        settingsAutosave = defaults.bool(forKey: userDefaultsPrefix + "settingsAutosave")
        settingsInMenu = defaults.bool(forKey: userDefaultsPrefix + "settingsInMenu")
        languageSelectOnStart = defaults.integer(forKey: userDefaultsPrefix + "languageSelectOnStart")
        settingsInTitle = defaults.bool(forKey: userDefaultsPrefix + "settingsInTitle")
        languageInTitle = defaults.object(forKey: userDefaultsPrefix + "languageInTitle") as? Bool ?? true
        loggingEnabled = defaults.object(forKey: userDefaultsPrefix + "loggingEnabled") as? Bool ?? true
        screenshotTimestamp = defaults.object(forKey: userDefaultsPrefix + "screenshotTimestamp") as? Bool ?? true
        automaticScreenshots = defaults.bool(forKey: userDefaultsPrefix + "automaticScreenshots")
        screenshotScale = max(1, intValue(defaults, key: userDefaultsPrefix + "screenshotScale", default: 1))
        automaticScreenshotsInterval = max(1, intValue(defaults, key: userDefaultsPrefix + "automaticScreenshotsInterval", default: 30))
        startupLogos = min(2, max(0, intValue(defaults, key: userDefaultsPrefix + "startupLogos", default: 1)))

        layoutTransparency = intValue(defaults, key: userDefaultsPrefix + "layoutTransparency", default: 100)
        layoutSize = intValue(defaults, key: userDefaultsPrefix + "layoutSize", default: 100)
        ignoreLayoutSize = defaults.bool(forKey: userDefaultsPrefix + "ignoreLayoutSize")
        touchUI = defaults.object(forKey: userDefaultsPrefix + "touchUI") as? Bool ?? true

        preferExternalFonts = defaults.bool(forKey: userDefaultsPrefix + "preferExternalFonts")
        font1Name = defaults.string(forKey: userDefaultsPrefix + "font1Name")?.nilIfEmpty
        font2Name = defaults.string(forKey: userDefaultsPrefix + "font2Name")?.nilIfEmpty
        font1Size = max(1, intValue(defaults, key: userDefaultsPrefix + "font1Size", default: 12))
        font2Size = max(1, intValue(defaults, key: userDefaultsPrefix + "font2Size", default: 12))

        if let folderURL = restoreSecurityScopedURL(from: easyRPGFolderBookmarkKey) {
            easyRPGFolderURL = folderURL
        } else if let folderStr = defaults.string(forKey: userDefaultsPrefix + "easyRPGFolder") {
            easyRPGFolderURL = URL(string: folderStr)
            if let easyRPGFolderURL { beginSecurityScopedAccessIfNeeded(easyRPGFolderURL) }
        } else {
            easyRPGFolderURL = defaultEasyRPGDocumentsFolder()
        }
        enableRtpScanning = defaults.object(forKey: userDefaultsPrefix + "enableRtpScanning") as? Bool ?? enableRtpScanning
        if let rtpURL = restoreSecurityScopedURL(from: rtpFolderBookmarkKey) {
            rtpFolderURL = rtpURL
        } else if let rtpStr = defaults.string(forKey: userDefaultsPrefix + "rtpFolder") {
            rtpFolderURL = URL(string: rtpStr)
            if let rtpFolderURL { beginSecurityScopedAccessIfNeeded(rtpFolderURL) }
        }
        hasCompletedOnboarding = defaults.object(forKey: userDefaultsPrefix + "hasCompletedOnboarding") as? Bool ?? false
    }

    // MARK: - Custom Game Titles

    private let customTitlesKey = "ios.customGameTitles"

    func getCustomGameTitle(for gamePath: String) -> String? {
        AppLogger.log("ENTER getCustomGameTitle")
        let titles = UserDefaults.standard.dictionary(forKey: customTitlesKey) as? [String: String] ?? [:]
        return titles[gamePath]
    }

    func setCustomGameTitle(_ title: String, for gamePath: String) {
        AppLogger.log("ENTER setCustomGameTitle")
        var titles = UserDefaults.standard.dictionary(forKey: customTitlesKey) as? [String: String] ?? [:]
        if title.isEmpty {
            titles.removeValue(forKey: gamePath)
        } else {
            titles[gamePath] = title
        }
        UserDefaults.standard.set(titles, forKey: customTitlesKey)
    }

    // MARK: - Config INI File

    private func saveConfigToIni() {
        AppLogger.log("ENTER saveConfigToIni")
        guard let configURL = configURL else { return }

        var iniContent = ""
        iniContent += "[Video]\n"
        iniContent += "Fullscreen=\(fullscreen ? 1 : 0)\n"
        iniContent += "ForceLandscape=\(forcedLandscape ? 1 : 0)\n"
        iniContent += "ImageSize=\(["nearest", "integer", "bilinear"][scaleMode])\n"
        iniContent += "ScalingMode=\(scaleMode)\n"
        iniContent += "Stretch=\(stretch ? 1 : 0)\n"
        iniContent += "Resolution=\(["original", "widescreen", "ultrawide"][gameResolution])\n"
        iniContent += "GameResolution=\(gameResolution)\n"
        iniContent += "GameBrowserLabelMode=\(gameBrowserLabelMode)\n"
        iniContent += "\n"

        iniContent += "[Audio]\n"
        iniContent += "MusicVolume=\(musicVolume)\n"
        iniContent += "SoundVolume=\(soundVolume)\n"
        iniContent += "Fluidsynth=\(fluidsynthMidi ? 1 : 0)\n"
        iniContent += "WildMidi=\(wildMidi ? 1 : 0)\n"
        iniContent += "NativeMidi=\(nativeMidi ? 1 : 0)\n"
        if let url = selectedSoundFont {
            iniContent += "SoundFont=\(url.path)\n"
        } else {
            iniContent += "SoundFont=\n"
        }
        iniContent += "\n"

        iniContent += "[Input]\n"
        iniContent += "EnableVibration=\(enableVibration ? 1 : 0)\n"
        iniContent += "VibrateWhenSliding=\(vibrateWhenSliding ? 1 : 0)\n"
        iniContent += "ShowABasZX=\(showABasZX ? 1 : 0)\n"
        iniContent += "FastForwardMode=\(fastForwardMode)\n"
        iniContent += "FastForwardMultiplier=\(fastForwardMultiplier)\n"
        iniContent += "FastForwardMultiplierB=\(fastForwardMultiplierB)\n"
        iniContent += "SpeedModifierA=\(fastForwardMultiplier)\n"
        iniContent += "SpeedModifierB=\(fastForwardMultiplierB)\n"
        iniContent += "GamepadSwapAnalog=\(gamepadSwapAnalog ? 1 : 0)\n"
        iniContent += "GamepadSwapDpad=\(gamepadSwapDpad ? 1 : 0)\n"
        iniContent += "GamepadSwapAbxy=\(gamepadSwapAbxy ? 1 : 0)\n"
        iniContent += "LayoutTransparency=\(layoutTransparency)\n"
        iniContent += "LayoutSize=\(layoutSize)\n"
        iniContent += "IgnoreLayoutSize=\(ignoreLayoutSize ? 1 : 0)\n"
        iniContent += "TouchUI=\(touchUI ? 1 : 0)\n"
        iniContent += "\n"

        iniContent += "[Engine]\n"
        iniContent += "SettingsAutosave=\(settingsAutosave ? 1 : 0)\n"
        iniContent += "SettingsInMenu=\(settingsInMenu ? 1 : 0)\n"
        iniContent += "LanguageSelectOnStart=\(languageSelectOnStart)\n"
        iniContent += "SettingsInTitle=\(settingsInTitle ? 1 : 0)\n"
        iniContent += "LanguageInTitle=\(languageInTitle ? 1 : 0)\n"
        iniContent += "Logging=\(loggingEnabled ? 1 : 0)\n"
        iniContent += "ScreenshotTimestamp=\(screenshotTimestamp ? 1 : 0)\n"
        iniContent += "AutomaticScreenshots=\(automaticScreenshots ? 1 : 0)\n"
        iniContent += "ScreenshotScale=\(screenshotScale)\n"
        iniContent += "AutomaticScreenshotsInterval=\(automaticScreenshotsInterval)\n"
        iniContent += "StartupLogos=\(startupLogos)\n"
        iniContent += "GameBrowserLabelMode=\(gameBrowserLabelMode)\n"
        iniContent += "\n"

        iniContent += "[Font]\n"
        iniContent += "PreferExternalFonts=\(preferExternalFonts ? 1 : 0)\n"
        iniContent += "Font1=\(font1Name ?? "")\n"
        iniContent += "Font2=\(font2Name ?? "")\n"
        iniContent += "Font1Size=\(font1Size)\n"
        iniContent += "Font2Size=\(font2Size)\n"
        iniContent += "\n"

        iniContent += "[Folders]\n"
        iniContent += "EnableRtpScanning=\(enableRtpScanning ? 1 : 0)\n"
        iniContent += "HasCompletedOnboarding=\(hasCompletedOnboarding ? 1 : 0)\n"
        if let folder = easyRPGFolderURL {
            iniContent += "EasyRPGFolder=\(folder.path)\n"
        }
        if let rtpFolder = rtpFolderURL {
            iniContent += "RTPFolder=\(rtpFolder.path)\n"
        }
        iniContent += "\n"

        iniContent += "[Player]\n"
        iniContent += "Fullscreen=\(fullscreen ? 1 : 0)\n"
        iniContent += "ForceLandscape=\(forcedLandscape ? 1 : 0)\n"
        iniContent += "Stretch=\(stretch ? 1 : 0)\n"
        iniContent += "ScalingMode=\(scaleMode)\n"
        iniContent += "GameResolution=\(gameResolution)\n"
        iniContent += "MusicVolume=\(musicVolume)\n"
        iniContent += "SoundVolume=\(soundVolume)\n"
        iniContent += "SoundFont=\(selectedSoundFont?.path ?? "")\n"
        iniContent += "EnableVibration=\(enableVibration ? 1 : 0)\n"
        iniContent += "VibrateWhenSliding=\(vibrateWhenSliding ? 1 : 0)\n"
        iniContent += "ShowABasZX=\(showABasZX ? 1 : 0)\n"
        iniContent += "FastForwardMode=\(fastForwardMode)\n"
        iniContent += "FastForwardMultiplier=\(fastForwardMultiplier)\n"
        iniContent += "FastForwardMultiplierB=\(fastForwardMultiplierB)\n"
        iniContent += "SpeedModifierA=\(fastForwardMultiplier)\n"
        iniContent += "SpeedModifierB=\(fastForwardMultiplierB)\n"
        iniContent += "GamepadSwapAnalog=\(gamepadSwapAnalog ? 1 : 0)\n"
        iniContent += "GamepadSwapDpad=\(gamepadSwapDpad ? 1 : 0)\n"
        iniContent += "GamepadSwapAbxy=\(gamepadSwapAbxy ? 1 : 0)\n"
        iniContent += "LayoutTransparency=\(layoutTransparency)\n"
        iniContent += "LayoutSize=\(layoutSize)\n"
        iniContent += "IgnoreLayoutSize=\(ignoreLayoutSize ? 1 : 0)\n"
        iniContent += "TouchUI=\(touchUI ? 1 : 0)\n"
        iniContent += "SettingsAutosave=\(settingsAutosave ? 1 : 0)\n"
        iniContent += "SettingsInMenu=\(settingsInMenu ? 1 : 0)\n"
        iniContent += "LanguageSelectOnStart=\(languageSelectOnStart)\n"
        iniContent += "SettingsInTitle=\(settingsInTitle ? 1 : 0)\n"
        iniContent += "LanguageInTitle=\(languageInTitle ? 1 : 0)\n"
        iniContent += "Logging=\(loggingEnabled ? 1 : 0)\n"
        iniContent += "ScreenshotTimestamp=\(screenshotTimestamp ? 1 : 0)\n"
        iniContent += "AutomaticScreenshots=\(automaticScreenshots ? 1 : 0)\n"
        iniContent += "ScreenshotScale=\(screenshotScale)\n"
        iniContent += "AutomaticScreenshotsInterval=\(automaticScreenshotsInterval)\n"
        iniContent += "StartupLogos=\(startupLogos)\n"
        iniContent += "GameBrowserLabelMode=\(gameBrowserLabelMode)\n"
        iniContent += "PreferExternalFonts=\(preferExternalFonts ? 1 : 0)\n"
        iniContent += "Font1=\(font1Name ?? "")\n"
        iniContent += "Font2=\(font2Name ?? "")\n"
        iniContent += "Font1Size=\(font1Size)\n"
        iniContent += "Font2Size=\(font2Size)\n"
        iniContent += "EnableRtpScanning=\(enableRtpScanning ? 1 : 0)\n"
        iniContent += "HasCompletedOnboarding=\(hasCompletedOnboarding ? 1 : 0)\n"
        if let folder = easyRPGFolderURL {
            iniContent += "EasyRPGFolder=\(folder.path)\n"
        }
        if let rtpFolder = rtpFolderURL {
            iniContent += "RTPFolder=\(rtpFolder.path)\n"
        }
        iniContent += "\n"

        do {
            try iniContent.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            AppLogger.log("Failed to save config.ini: \(error)")
        }
    }


    private func persistSecurityScopedBookmark(for url: URL, key: String) {
        AppLogger.log("ENTER persistSecurityScopedBookmark")
        do {
            let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            AppLogger.log("[iOS] Failed to save security-scoped bookmark for \(url): \(error)")
        }
    }

    private func restoreSecurityScopedURL(from key: String) -> URL? {
        AppLogger.log("ENTER restoreSecurityScopedURL")
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if url.startAccessingSecurityScopedResource() {
                if isStale {
                    persistSecurityScopedBookmark(for: url, key: key)
                }
                return url
            }
            return nil
        } catch {
            AppLogger.log("[iOS] Failed to restore security-scoped bookmark for key \(key): \(error)")
            return nil
        }
    }

    private func beginSecurityScopedAccessIfNeeded(_ url: URL) {
        AppLogger.log("ENTER beginSecurityScopedAccessIfNeeded")
        _ = url.startAccessingSecurityScopedResource()
    }

    func setEasyRPGFolder(_ url: URL) {
        AppLogger.log("ENTER setEasyRPGFolder")
        AppLogger.log("setEasyRPGFolder url=\(url.path)")
        let normalized = url.standardizedFileURL
        easyRPGFolderURL = normalized
        if isInsideDocuments(normalized) {
            UserDefaults.standard.removeObject(forKey: easyRPGFolderBookmarkKey)
        } else {
            beginSecurityScopedAccessIfNeeded(normalized)
            persistSecurityScopedBookmark(for: normalized, key: easyRPGFolderBookmarkKey)
        }
        hasCompletedOnboarding = true
        saveSettings()
    }

    func useAutomaticEasyRPGFolderInDocuments() {
        AppLogger.log("ENTER useAutomaticEasyRPGFolderInDocuments")
        if let documentsFolder = defaultEasyRPGDocumentsFolder() {
            easyRPGFolderURL = documentsFolder.standardizedFileURL
            UserDefaults.standard.removeObject(forKey: easyRPGFolderBookmarkKey)
            hasCompletedOnboarding = true
            saveSettings()
        }
    }

    func completeOnboardingIfNeeded() {
        AppLogger.log("ENTER completeOnboardingIfNeeded")
        if !hasCompletedOnboarding {
            hasCompletedOnboarding = true
            saveSettings()
        }
    }

    func setRTPFolder(_ url: URL) {
        AppLogger.log("ENTER setRTPFolder")
        let normalized = url.standardizedFileURL
        rtpFolderURL = normalized
        if isInsideDocuments(normalized) {
            UserDefaults.standard.removeObject(forKey: rtpFolderBookmarkKey)
        } else {
            beginSecurityScopedAccessIfNeeded(normalized)
            persistSecurityScopedBookmark(for: normalized, key: rtpFolderBookmarkKey)
        }
        saveSettings()
    }
}


private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
