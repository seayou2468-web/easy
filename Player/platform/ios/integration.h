#ifndef EP_PLATFORM_IOS_INTEGRATION_H
#include <vector>
#include <string>
#include <stdint.h>
#define EP_PLATFORM_IOS_INTEGRATION_H

namespace IOSIntegration {
	void InitPlatformFeatures();
	void StartRuntimeIfNeeded();
	void Invoke();
	void EndGame();
	void ResetGame();
	void ToggleFps();
	void OpenSettings();
	void SetButtonMapping(const char* button_id, const char* key_id);
	void ResetButtonMappings();
	void VirtualTouchDown(float x, float y);
	void VirtualTouchMove(float x, float y);
	void VirtualTouchUp();
	void SetVirtualButtonPoint(const char* button_id, float x, float y);
	void LaunchGame(const char* args);
	void SendKeyDown(const char* button_id);
	void SendKeyUp(const char* button_id);
	bool ConsumeLaunchArgs(std::vector<std::string>& out_args);
}


#ifdef __cplusplus
extern "C" {
#endif

void EasyRPG_iOS_EndGame(void);
void EasyRPG_iOS_StartRuntime(void);
void EasyRPG_iOS_ResetGame(void);
void EasyRPG_iOS_ToggleFps(void);
void EasyRPG_iOS_OpenSettings(void);
void EasyRPG_iOS_SetButtonMapping(const char* button_id, const char* key_id);
void EasyRPG_iOS_ResetButtonMappings(void);
void EasyRPG_iOS_VirtualTouchDown(float x, float y);
void EasyRPG_iOS_VirtualTouchMove(float x, float y);
void EasyRPG_iOS_VirtualTouchUp(void);
void EasyRPG_iOS_SetVirtualButtonPoint(const char* button_id, float x, float y);
void EasyRPG_iOS_LaunchGame(const char* args);
void EasyRPG_iOS_SendKeyDown(const char* button_id);
void EasyRPG_iOS_SendKeyUp(const char* button_id);
void EasyRPG_iOS_SetLayoutTransparency(float alpha);
void EasyRPG_iOS_SetLayoutSize(float size);
void EasyRPG_iOS_SetVibrationEnabled(bool enabled);
void EasyRPG_iOS_SetVibrateWhenSlidingEnabled(bool enabled);
void EasyRPG_iOS_SetMusicVolume(int32_t volume);
void EasyRPG_iOS_SetSoundVolume(int32_t volume);
void EasyRPG_iOS_SetSoundFont(const char* path);
void EasyRPG_iOS_SetFullscreen(bool enabled);
void EasyRPG_iOS_SetForcedLandscape(bool enabled);
void EasyRPG_iOS_SetImageScaleMode(int32_t mode);
void EasyRPG_iOS_SetStretch(bool enabled);
void EasyRPG_iOS_SetGameResolution(int32_t resolution);
void EasyRPG_iOS_SetFont1(const char* font_name);
void EasyRPG_iOS_SetFont2(const char* font_name);
void EasyRPG_iOS_SetFont1Size(int32_t size);
void EasyRPG_iOS_SetFont2Size(int32_t size);
void EasyRPG_iOS_SetFastForwardSpeedA(int32_t speed);
void EasyRPG_iOS_SetFastForwardSpeedB(int32_t speed);
void EasyRPG_iOS_SetSettingsInMenu(bool enabled);
void EasyRPG_iOS_SetLanguageSelectOnStart(int32_t mode);
void EasyRPG_iOS_SetConfigBool(const char* section, const char* key, bool value);
void EasyRPG_iOS_SetConfigInt(const char* section, const char* key, int32_t value);
void EasyRPG_iOS_SetConfigString(const char* section, const char* key, const char* value);

#ifdef __cplusplus
}
#endif

#endif
