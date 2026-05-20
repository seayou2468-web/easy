import Foundation

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

    // Input settings
    @Published var enableVibration = true
    @Published var vibrateWhenSliding = false
    @Published var showABasZX = false
    @Published var fastForwardMode = 0 // 0: hold, 1: tap
    @Published var fastForwardMultiplier = 3
    @Published var fastForwardMultiplierB = 10
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

    private let configFileName = "config.ini"
    private let userDefaultsPrefix = "ios.settings."
    private var configURL: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent(configFileName)
    }

    private init() {
        loadSettings()
    }

    // MARK: - Settings Management

    func saveSettings() {
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
        if let url = selectedSoundFont {
            defaults.set(url.absoluteString, forKey: userDefaultsPrefix + "selectedSoundFont")
        }

        defaults.set(enableVibration, forKey: userDefaultsPrefix + "enableVibration")
        defaults.set(vibrateWhenSliding, forKey: userDefaultsPrefix + "vibrateWhenSliding")
        defaults.set(showABasZX, forKey: userDefaultsPrefix + "showABasZX")
        defaults.set(fastForwardMode, forKey: userDefaultsPrefix + "fastForwardMode")
        defaults.set(fastForwardMultiplier, forKey: userDefaultsPrefix + "fastForwardMultiplier")
        defaults.set(fastForwardMultiplierB, forKey: userDefaultsPrefix + "fastForwardMultiplierB")
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

        defaults.set(preferExternalFonts, forKey: userDefaultsPrefix + "preferExternalFonts")
        defaults.set(font1Name ?? "", forKey: userDefaultsPrefix + "font1Name")
        defaults.set(font2Name ?? "", forKey: userDefaultsPrefix + "font2Name")
        defaults.set(font1Size, forKey: userDefaultsPrefix + "font1Size")
        defaults.set(font2Size, forKey: userDefaultsPrefix + "font2Size")

        if let url = easyRPGFolderURL {
            defaults.set(url.absoluteString, forKey: userDefaultsPrefix + "easyRPGFolder")
        }
        defaults.set(enableRtpScanning, forKey: userDefaultsPrefix + "enableRtpScanning")
        if let url = rtpFolderURL {
            defaults.set(url.absoluteString, forKey: userDefaultsPrefix + "rtpFolder")
        }

        saveConfigToIni()
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        fullscreen = defaults.bool(forKey: userDefaultsPrefix + "fullscreen") || fullscreen
        forcedLandscape = defaults.bool(forKey: userDefaultsPrefix + "forcedLandscape")
        scaleMode = defaults.integer(forKey: userDefaultsPrefix + "scaleMode")
        stretch = defaults.bool(forKey: userDefaultsPrefix + "stretch")
        gameResolution = defaults.integer(forKey: userDefaultsPrefix + "gameResolution")
        gameBrowserLabelMode = defaults.integer(forKey: userDefaultsPrefix + "gameBrowserLabelMode")

        musicVolume = defaults.integer(forKey: userDefaultsPrefix + "musicVolume") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "musicVolume") : 100
        soundVolume = defaults.integer(forKey: userDefaultsPrefix + "soundVolume") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "soundVolume") : 100
        if let soundFontStr = defaults.string(forKey: userDefaultsPrefix + "selectedSoundFont") {
            selectedSoundFont = URL(string: soundFontStr)
        }

        enableVibration = defaults.bool(forKey: userDefaultsPrefix + "enableVibration") || enableVibration
        vibrateWhenSliding = defaults.bool(forKey: userDefaultsPrefix + "vibrateWhenSliding")
        showABasZX = defaults.bool(forKey: userDefaultsPrefix + "showABasZX")
        fastForwardMode = defaults.integer(forKey: userDefaultsPrefix + "fastForwardMode")
        fastForwardMultiplier = max(2, defaults.integer(forKey: userDefaultsPrefix + "fastForwardMultiplier"))
        fastForwardMultiplierB = max(2, defaults.integer(forKey: userDefaultsPrefix + "fastForwardMultiplierB") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "fastForwardMultiplierB") : 10)
        settingsInMenu = defaults.bool(forKey: userDefaultsPrefix + "settingsInMenu")
        languageSelectOnStart = defaults.integer(forKey: userDefaultsPrefix + "languageSelectOnStart")
        settingsInTitle = defaults.bool(forKey: userDefaultsPrefix + "settingsInTitle")
        languageInTitle = defaults.object(forKey: userDefaultsPrefix + "languageInTitle") as? Bool ?? true
        loggingEnabled = defaults.object(forKey: userDefaultsPrefix + "loggingEnabled") as? Bool ?? true
        screenshotTimestamp = defaults.object(forKey: userDefaultsPrefix + "screenshotTimestamp") as? Bool ?? true
        automaticScreenshots = defaults.bool(forKey: userDefaultsPrefix + "automaticScreenshots")
        screenshotScale = max(1, defaults.integer(forKey: userDefaultsPrefix + "screenshotScale"))
        automaticScreenshotsInterval = max(1, defaults.integer(forKey: userDefaultsPrefix + "automaticScreenshotsInterval") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "automaticScreenshotsInterval") : 30)
        startupLogos = min(2, max(0, defaults.integer(forKey: userDefaultsPrefix + "startupLogos")))

        layoutTransparency = defaults.integer(forKey: userDefaultsPrefix + "layoutTransparency") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "layoutTransparency") : 100
        layoutSize = defaults.integer(forKey: userDefaultsPrefix + "layoutSize") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "layoutSize") : 100
        ignoreLayoutSize = defaults.bool(forKey: userDefaultsPrefix + "ignoreLayoutSize")

        preferExternalFonts = defaults.bool(forKey: userDefaultsPrefix + "preferExternalFonts")
        font1Name = defaults.string(forKey: userDefaultsPrefix + "font1Name")
        font2Name = defaults.string(forKey: userDefaultsPrefix + "font2Name")
        font1Size = max(1, defaults.integer(forKey: userDefaultsPrefix + "font1Size") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "font1Size") : 12)
        font2Size = max(1, defaults.integer(forKey: userDefaultsPrefix + "font2Size") != 0 ? defaults.integer(forKey: userDefaultsPrefix + "font2Size") : 12)

        if let folderStr = defaults.string(forKey: userDefaultsPrefix + "easyRPGFolder") {
            easyRPGFolderURL = URL(string: folderStr)
        } else {
            easyRPGFolderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
                .appendingPathComponent("EasyRPG")
        }
        enableRtpScanning = defaults.bool(forKey: userDefaultsPrefix + "enableRtpScanning") || enableRtpScanning
        if let rtpStr = defaults.string(forKey: userDefaultsPrefix + "rtpFolder") {
            rtpFolderURL = URL(string: rtpStr)
        }
    }

    // MARK: - Custom Game Titles

    private let customTitlesKey = "ios.customGameTitles"

    func getCustomGameTitle(for gamePath: String) -> String? {
        let titles = UserDefaults.standard.dictionary(forKey: customTitlesKey) as? [String: String] ?? [:]
        return titles[gamePath]
    }

    func setCustomGameTitle(_ title: String, for gamePath: String) {
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
        guard let configURL = configURL else { return }

        var iniContent = ""
        iniContent += "[Video]\n"
        iniContent += "Fullscreen=\(fullscreen ? 1 : 0)\n"
        iniContent += "ForceLandscape=\(forcedLandscape ? 1 : 0)\n"
        iniContent += "ImageSize=\(["nearest", "integer", "bilinear"][scaleMode])\n"
        iniContent += "Stretch=\(stretch ? 1 : 0)\n"
        iniContent += "Resolution=\(["original", "widescreen", "ultrawide"][gameResolution])\n"
        iniContent += "\n"

        iniContent += "[Audio]\n"
        iniContent += "MusicVolume=\(musicVolume)\n"
        iniContent += "SoundVolume=\(soundVolume)\n"
        if let url = selectedSoundFont {
            iniContent += "SoundFont=\(url.path)\n"
        }
        iniContent += "\n"

        iniContent += "[Input]\n"
        iniContent += "EnableVibration=\(enableVibration ? 1 : 0)\n"
        iniContent += "VibrateWhenSliding=\(vibrateWhenSliding ? 1 : 0)\n"
        iniContent += "ShowABasZX=\(showABasZX ? 1 : 0)\n"
        iniContent += "FastForwardMode=\(fastForwardMode)\n"
        iniContent += "FastForwardMultiplier=\(fastForwardMultiplier)\n"
        iniContent += "FastForwardMultiplierB=\(fastForwardMultiplierB)\n"
        iniContent += "LayoutTransparency=\(layoutTransparency)\n"
        iniContent += "LayoutSize=\(layoutSize)\n"
        iniContent += "IgnoreLayoutSize=\(ignoreLayoutSize ? 1 : 0)\n"
        iniContent += "\n"

        iniContent += "[Engine]\n"
        iniContent += "SettingsInMenu=\(settingsInMenu ? 1 : 0)\n"
        iniContent += "LanguageSelectOnStart=\(languageSelectOnStart)\n"
        iniContent += "Font1Size=\(font1Size)\n"
        iniContent += "Font2Size=\(font2Size)\n"
        iniContent += "\n"

        do {
            try iniContent.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save config.ini: \(error)")
        }
    }

    func setEasyRPGFolder(_ url: URL) {
        easyRPGFolderURL = url
        saveSettings()
    }

    func setRTPFolder(_ url: URL) {
        rtpFolderURL = url
        saveSettings()
    }
}
