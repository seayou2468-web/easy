import Foundation
import UIKit

enum PlayerBridge {
    private static let launchArgSeparator = "\u{1F}" // Unit Separator (ASCII 31)
    // MARK: - Game Control
    static func startRuntime() { AppLogger.log("startRuntime"); EasyRPG_iOS_StartRuntime() }
        AppLogger.log("ENTER startRuntime")
    static func endGame() { AppLogger.log("endGame"); EasyRPG_iOS_EndGame() }
        AppLogger.log("ENTER endGame")
    static func resetGame() { AppLogger.log("resetGame"); EasyRPG_iOS_ResetGame() }
        AppLogger.log("ENTER resetGame")
    static func toggleFps() { EasyRPG_iOS_ToggleFps() }
        AppLogger.log("ENTER toggleFps")
    static func openSettings() { EasyRPG_iOS_OpenSettings() }
        AppLogger.log("ENTER openSettings")

    // MARK: - Game Launch
    static func launchGame(withArgs args: [String]) {
        AppLogger.log("ENTER launchGame")
        AppLogger.log("launchGame args=\(args)")
        let argsStr = args.joined(separator: launchArgSeparator)
        argsStr.withCString { argsCStr in
            EasyRPG_iOS_LaunchGame(argsCStr)
        }
    }

    // MARK: - Button Mapping
    static func setButtonMapping(buttonId: String, keyId: String) {
        AppLogger.log("ENTER setButtonMapping")
        buttonId.withCString { b in
            keyId.withCString { k in
                EasyRPG_iOS_SetButtonMapping(b, k)
            }
        }
    }
    static func resetButtonMappings() { EasyRPG_iOS_ResetButtonMappings() }
        AppLogger.log("ENTER resetButtonMappings")

    // MARK: - Input
    static func sendKeyDown(_ buttonId: String) {
        AppLogger.log("ENTER sendKeyDown")
        buttonId.withCString { b in
            EasyRPG_iOS_SendKeyDown(b)
        }
    }

    static func sendKeyUp(_ buttonId: String) {
        AppLogger.log("ENTER sendKeyUp")
        buttonId.withCString { b in
            EasyRPG_iOS_SendKeyUp(b)
        }
    }

    // MARK: - Virtual Controller Touch Events
    static func virtualTouchDown(x: CGFloat, y: CGFloat) { EasyRPG_iOS_VirtualTouchDown(Float(x), Float(y)) }
        AppLogger.log("ENTER virtualTouchDown")
    static func virtualTouchMove(x: CGFloat, y: CGFloat) { EasyRPG_iOS_VirtualTouchMove(Float(x), Float(y)) }
        AppLogger.log("ENTER virtualTouchMove")
    static func virtualTouchUp() { EasyRPG_iOS_VirtualTouchUp() }
        AppLogger.log("ENTER virtualTouchUp")

    // MARK: - Virtual Controller Configuration
    static func setVirtualButtonPoint(buttonId: String, x: CGFloat, y: CGFloat) {
        AppLogger.log("ENTER setVirtualButtonPoint")
        buttonId.withCString { b in
            EasyRPG_iOS_SetVirtualButtonPoint(b, Float(x), Float(y))
        }
    }

    static func setLayoutTransparency(_ alpha: Double) {
        AppLogger.log("ENTER setLayoutTransparency")
        EasyRPG_iOS_SetLayoutTransparency(Float(alpha / 255.0))
    }

    static func setLayoutSize(_ size: Double) {
        AppLogger.log("ENTER setLayoutSize")
        EasyRPG_iOS_SetLayoutSize(Float(size / 100.0))
    }

    static func setVibrationEnabled(_ enabled: Bool) {
        AppLogger.log("ENTER setVibrationEnabled")
        EasyRPG_iOS_SetVibrationEnabled(enabled)
    }

    static func setVibrateWhenSlidingEnabled(_ enabled: Bool) {
        AppLogger.log("ENTER setVibrateWhenSlidingEnabled")
        EasyRPG_iOS_SetVibrateWhenSlidingEnabled(enabled)
    }

    // MARK: - Audio
    static func setMusicVolume(_ volume: Int) {
        AppLogger.log("ENTER setMusicVolume")
        EasyRPG_iOS_SetMusicVolume(Int32(volume))
    }

    static func setSoundVolume(_ volume: Int) {
        AppLogger.log("ENTER setSoundVolume")
        EasyRPG_iOS_SetSoundVolume(Int32(volume))
    }

    static func setSoundFont(_ path: String) {
        AppLogger.log("ENTER setSoundFont")
        path.withCString { p in
            EasyRPG_iOS_SetSoundFont(p)
        }
    }

    // MARK: - Video Settings
    static func setFullscreen(_ enabled: Bool) {
        AppLogger.log("ENTER setFullscreen")
        EasyRPG_iOS_SetFullscreen(enabled)
    }

    static func setForcedLandscape(_ enabled: Bool) {
        AppLogger.log("ENTER setForcedLandscape")
        EasyRPG_iOS_SetForcedLandscape(enabled)
    }

    static func setImageScaleMode(_ mode: Int) {
        AppLogger.log("ENTER setImageScaleMode")
        EasyRPG_iOS_SetImageScaleMode(Int32(mode))
    }

    static func setStretch(_ enabled: Bool) {
        AppLogger.log("ENTER setStretch")
        EasyRPG_iOS_SetStretch(enabled)
    }

    static func setGameResolution(_ resolution: Int) {
        AppLogger.log("ENTER setGameResolution")
        EasyRPG_iOS_SetGameResolution(Int32(resolution))
    }

    // MARK: - Font Settings
    static func setFont1(_ fontName: String) {
        AppLogger.log("ENTER setFont1")
        fontName.withCString { f in
            EasyRPG_iOS_SetFont1(f)
        }
    }

    static func setFont2(_ fontName: String) {
        AppLogger.log("ENTER setFont2")
        fontName.withCString { f in
            EasyRPG_iOS_SetFont2(f)
        }
    }

    static func setFont1Size(_ size: Int) {
        AppLogger.log("ENTER setFont1Size")
        EasyRPG_iOS_SetFont1Size(Int32(size))
    }

    static func setFont2Size(_ size: Int) {
        AppLogger.log("ENTER setFont2Size")
        EasyRPG_iOS_SetFont2Size(Int32(size))
    }

    static func setFastForwardSpeedA(_ speed: Int) {
        AppLogger.log("ENTER setFastForwardSpeedA")
        EasyRPG_iOS_SetFastForwardSpeedA(Int32(speed))
    }

    static func setFastForwardSpeedB(_ speed: Int) {
        AppLogger.log("ENTER setFastForwardSpeedB")
        EasyRPG_iOS_SetFastForwardSpeedB(Int32(speed))
    }

    static func setSettingsInMenu(_ enabled: Bool) {
        AppLogger.log("ENTER setSettingsInMenu")
        EasyRPG_iOS_SetSettingsInMenu(enabled)
    }

    static func setLanguageSelectOnStart(_ mode: Int) {
        AppLogger.log("ENTER setLanguageSelectOnStart")
        EasyRPG_iOS_SetLanguageSelectOnStart(Int32(mode))
    }

    static func setConfigBool(section: String, key: String, value: Bool) {
        AppLogger.log("ENTER setConfigBool")
        section.withCString { s in
            key.withCString { k in
                EasyRPG_iOS_SetConfigBool(s, k, value)
            }
        }
    }

    static func setConfigInt(section: String, key: String, value: Int) {
        AppLogger.log("ENTER setConfigInt")
        section.withCString { s in
            key.withCString { k in
                EasyRPG_iOS_SetConfigInt(s, k, Int32(value))
            }
        }
    }
}
