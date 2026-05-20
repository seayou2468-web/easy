import Foundation
import UIKit

enum PlayerBridge {
    // MARK: - Game Control
    static func endGame() { EasyRPG_iOS_EndGame() }
    static func resetGame() { EasyRPG_iOS_ResetGame() }
    static func toggleFps() { EasyRPG_iOS_ToggleFps() }
    static func openSettings() { EasyRPG_iOS_OpenSettings() }

    // MARK: - Game Launch
    static func launchGame(withArgs args: [String]) {
        let argsStr = args.joined(separator: " ")
        argsStr.withCString { argsCStr in
            EasyRPG_iOS_LaunchGame(argsCStr)
        }
    }

    // MARK: - Button Mapping
    static func setButtonMapping(buttonId: String, keyId: String) {
        buttonId.withCString { b in
            keyId.withCString { k in
                EasyRPG_iOS_SetButtonMapping(b, k)
            }
        }
    }
    static func resetButtonMappings() { EasyRPG_iOS_ResetButtonMappings() }

    // MARK: - Input
    static func sendKeyDown(_ buttonId: String) {
        buttonId.withCString { b in
            EasyRPG_iOS_SendKeyDown(b)
        }
    }

    static func sendKeyUp(_ buttonId: String) {
        buttonId.withCString { b in
            EasyRPG_iOS_SendKeyUp(b)
        }
    }

    // MARK: - Virtual Controller Touch Events
    static func virtualTouchDown(x: CGFloat, y: CGFloat) { EasyRPG_iOS_VirtualTouchDown(Float(x), Float(y)) }
    static func virtualTouchMove(x: CGFloat, y: CGFloat) { EasyRPG_iOS_VirtualTouchMove(Float(x), Float(y)) }
    static func virtualTouchUp() { EasyRPG_iOS_VirtualTouchUp() }

    // MARK: - Virtual Controller Configuration
    static func setVirtualButtonPoint(buttonId: String, x: CGFloat, y: CGFloat) {
        buttonId.withCString { b in
            EasyRPG_iOS_SetVirtualButtonPoint(b, Float(x), Float(y))
        }
    }

    static func setLayoutTransparency(_ alpha: Double) {
        EasyRPG_iOS_SetLayoutTransparency(Float(alpha / 255.0))
    }

    static func setLayoutSize(_ size: Double) {
        EasyRPG_iOS_SetLayoutSize(Float(size / 100.0))
    }

    static func setVibrationEnabled(_ enabled: Bool) {
        EasyRPG_iOS_SetVibrationEnabled(enabled)
    }

    static func setVibrateWhenSlidingEnabled(_ enabled: Bool) {
        EasyRPG_iOS_SetVibrateWhenSlidingEnabled(enabled)
    }

    // MARK: - Audio
    static func setMusicVolume(_ volume: Int) {
        EasyRPG_iOS_SetMusicVolume(Int32(volume))
    }

    static func setSoundVolume(_ volume: Int) {
        EasyRPG_iOS_SetSoundVolume(Int32(volume))
    }

    static func setSoundFont(_ path: String) {
        path.withCString { p in
            EasyRPG_iOS_SetSoundFont(p)
        }
    }

    // MARK: - Video Settings
    static func setFullscreen(_ enabled: Bool) {
        EasyRPG_iOS_SetFullscreen(enabled)
    }

    static func setForcedLandscape(_ enabled: Bool) {
        EasyRPG_iOS_SetForcedLandscape(enabled)
    }

    static func setImageScaleMode(_ mode: Int) {
        EasyRPG_iOS_SetImageScaleMode(Int32(mode))
    }

    static func setStretch(_ enabled: Bool) {
        EasyRPG_iOS_SetStretch(enabled)
    }

    static func setGameResolution(_ resolution: Int) {
        EasyRPG_iOS_SetGameResolution(Int32(resolution))
    }

    // MARK: - Font Settings
    static func setFont1(_ fontName: String) {
        fontName.withCString { f in
            EasyRPG_iOS_SetFont1(f)
        }
    }

    static func setFont2(_ fontName: String) {
        fontName.withCString { f in
            EasyRPG_iOS_SetFont2(f)
        }
    }

    static func setFont1Size(_ size: Int) {
        EasyRPG_iOS_SetFont1Size(Int32(size))
    }

    static func setFont2Size(_ size: Int) {
        EasyRPG_iOS_SetFont2Size(Int32(size))
    }
}

