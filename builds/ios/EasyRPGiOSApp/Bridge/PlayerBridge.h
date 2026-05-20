#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Game Control
void EasyRPG_iOS_EndGame(void);
void EasyRPG_iOS_ResetGame(void);
void EasyRPG_iOS_ToggleFps(void);
void EasyRPG_iOS_OpenSettings(void);

// Game Launch
void EasyRPG_iOS_LaunchGame(const char* args);

// Button Mapping
void EasyRPG_iOS_SetButtonMapping(const char* button_id, const char* key_id);
void EasyRPG_iOS_ResetButtonMappings(void);

// Input
void EasyRPG_iOS_SendKeyDown(const char* button_id);
void EasyRPG_iOS_SendKeyUp(const char* button_id);

// Virtual Controller Touch Events
void EasyRPG_iOS_VirtualTouchDown(float x, float y);
void EasyRPG_iOS_VirtualTouchMove(float x, float y);
void EasyRPG_iOS_VirtualTouchUp(void);

// Virtual Controller Configuration
void EasyRPG_iOS_SetVirtualButtonPoint(const char* button_id, float x, float y);
void EasyRPG_iOS_SetLayoutTransparency(float alpha);
void EasyRPG_iOS_SetLayoutSize(float size);
void EasyRPG_iOS_SetVibrationEnabled(bool enabled);
void EasyRPG_iOS_SetVibrateWhenSlidingEnabled(bool enabled);

// Audio
void EasyRPG_iOS_SetMusicVolume(int32_t volume);
void EasyRPG_iOS_SetSoundVolume(int32_t volume);
void EasyRPG_iOS_SetSoundFont(const char* path);

// Video Settings
void EasyRPG_iOS_SetFullscreen(bool enabled);
void EasyRPG_iOS_SetForcedLandscape(bool enabled);
void EasyRPG_iOS_SetImageScaleMode(int32_t mode);
void EasyRPG_iOS_SetStretch(bool enabled);
void EasyRPG_iOS_SetGameResolution(int32_t resolution);

// Font Settings
void EasyRPG_iOS_SetFont1(const char* font_name);
void EasyRPG_iOS_SetFont2(const char* font_name);
void EasyRPG_iOS_SetFont1Size(int32_t size);
void EasyRPG_iOS_SetFont2Size(int32_t size);

#ifdef __cplusplus
}
#endif
