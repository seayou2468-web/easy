#ifndef EP_PLATFORM_IOS_INTEGRATION_H
#define EP_PLATFORM_IOS_INTEGRATION_H

namespace IOSIntegration {
	void InitPlatformFeatures();
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
}

#ifdef __cplusplus
extern "C" {
#endif

void EasyRPG_iOS_EndGame(void);
void EasyRPG_iOS_ResetGame(void);
void EasyRPG_iOS_ToggleFps(void);
void EasyRPG_iOS_OpenSettings(void);
void EasyRPG_iOS_SetButtonMapping(const char* button_id, const char* key_id);
void EasyRPG_iOS_ResetButtonMappings(void);
void EasyRPG_iOS_VirtualTouchDown(float x, float y);
void EasyRPG_iOS_VirtualTouchMove(float x, float y);
void EasyRPG_iOS_VirtualTouchUp(void);
void EasyRPG_iOS_SetVirtualButtonPoint(const char* button_id, float x, float y);

#ifdef __cplusplus
}
#endif

#endif
