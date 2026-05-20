#include "system.h"

#if defined(__APPLE__) && TARGET_OS_IOS

#include <functional>
#include <mutex>
#include <algorithm>
#include <array>
#include <cstring>
#include <cctype>
#include <vector>
#include <string>
#include <SDL3/SDL.h>
#include "platform/ios/integration.h"
#include "output.h"
#include "player.h"
#include "input.h"
#include "input_buttons.h"
#include "utils.h"
#include "baseui.h"
#include "audio.h"
#include "font.h"

namespace {
std::vector<std::function<void()>> ios_fn_queue;
std::mutex ios_mutex;
struct VirtualPoint { float x; float y; Input::Keys::InputKey key; };
std::vector<VirtualPoint> virtual_points = {
	{70.f, 320.f, Input::Keys::UP},
	{70.f, 410.f, Input::Keys::DOWN},
	{25.f, 365.f, Input::Keys::LEFT},
	{115.f, 365.f, Input::Keys::RIGHT},
	{320.f, 350.f, Input::Keys::Z},
	{380.f, 300.f, Input::Keys::X},
	{300.f, 420.f, Input::Keys::SHIFT},
	{360.f, 420.f, Input::Keys::TAB},
	{420.f, 420.f, Input::Keys::F1},
};
std::vector<std::string> launch_args;
bool has_launch_args = false;
std::vector<Input::Keys::InputKey> held_keys;

Input::Keys::InputKey ResolveVirtualButtonKey(const char* id) {
	if (!id) return Input::Keys::NONE;
	if (strcmp(id, "up") == 0) return Input::Keys::UP;
	if (strcmp(id, "down") == 0) return Input::Keys::DOWN;
	if (strcmp(id, "left") == 0) return Input::Keys::LEFT;
	if (strcmp(id, "right") == 0) return Input::Keys::RIGHT;
	if (strcmp(id, "z") == 0) return Input::Keys::Z;
	if (strcmp(id, "x") == 0) return Input::Keys::X;
	if (strcmp(id, "shift") == 0) return Input::Keys::SHIFT;
	if (strcmp(id, "fast_forward_a") == 0) return Input::Keys::TAB;
	if (strcmp(id, "settings_menu") == 0) return Input::Keys::F1;
	return Input::Keys::NONE;
}

template<typename F>
void Schedule(F&& fn) {
	std::lock_guard<std::mutex> lock(ios_mutex);
	ios_fn_queue.emplace_back(std::move(fn));
}

void SimulateVirtualPress(float x, float y) {
	if (!Input::source) {
		return;
	}
	float best = 999999.f;
	Input::Keys::InputKey best_key = Input::Keys::NONE;
	for (const auto& p : virtual_points) {
		float dx = p.x - x;
		float dy = p.y - y;
		float d = dx * dx + dy * dy;
		if (d < best) {
			best = d;
			best_key = p.key;
		}
	}
	if (best_key != Input::Keys::NONE) {
		Input::source->SimulateKeyPress(best_key);
	}
}
}

namespace IOSIntegration {
void InitPlatformFeatures() {
	SDL_SetHint("SDL_IOS_HIDE_HOME_INDICATOR", "1");
	SDL_SetHint("SDL_IOS_IDLE_TIMER_DISABLED", "1");
}

void Invoke() {
	std::function<void()> fn;
	{
		std::lock_guard<std::mutex> lock(ios_mutex);
		if (ios_fn_queue.empty()) {
			return;
		}

		fn = std::move(ios_fn_queue.front());
		ios_fn_queue.erase(ios_fn_queue.begin());
	}

	fn();

	if (Input::source) {
		for (auto key : held_keys) {
			if (key != Input::Keys::NONE) {
				Input::source->SimulateKeyPress(key);
			}
		}
	}
}

void EndGame() {
	Schedule([]() {
		Player::exit_flag = true;
	});
}

void ResetGame() {
	Schedule([]() {
		Player::reset_flag = true;
	});
}

void ToggleFps() {
	Schedule([]() {
		if (!Input::source) {
			return;
		}

		auto& mappings = Input::source->GetButtonMappings();
		for (auto it = mappings.LowerBound(Input::TOGGLE_FPS);
			 it != mappings.end() && it->first == Input::TOGGLE_FPS; ++it) {
			Input::source->SimulateKeyPress(it->second);
		}
	});
}

void OpenSettings() {
	Schedule([]() {
		if (!Input::source) {
			return;
		}

		auto& mappings = Input::source->GetButtonMappings();
		for (auto it = mappings.LowerBound(Input::SETTINGS_MENU);
			 it != mappings.end() && it->first == Input::SETTINGS_MENU; ++it) {
			Input::source->SimulateKeyPress(it->second);
		}
	});
}

Input::InputButton ResolveButtonId(const char* id) {
	if (!id) {
		return Input::BUTTON_COUNT;
	}
	if (strcmp(id, "decision") == 0) return Input::DECISION;
	if (strcmp(id, "cancel") == 0) return Input::CANCEL;
	if (strcmp(id, "up") == 0) return Input::UP;
	if (strcmp(id, "down") == 0) return Input::DOWN;
	if (strcmp(id, "left") == 0) return Input::LEFT;
	if (strcmp(id, "right") == 0) return Input::RIGHT;
	if (strcmp(id, "shift") == 0) return Input::SHIFT;
	if (strcmp(id, "fast_forward_a") == 0) return Input::FAST_FORWARD_A;
	if (strcmp(id, "fast_forward_b") == 0) return Input::FAST_FORWARD_B;
	if (strcmp(id, "page_up") == 0) return Input::PAGE_UP;
	if (strcmp(id, "page_down") == 0) return Input::PAGE_DOWN;
	if (strcmp(id, "settings_menu") == 0) return Input::SETTINGS_MENU;
	if (strcmp(id, "toggle_fps") == 0) return Input::TOGGLE_FPS;
	if (strcmp(id, "reset") == 0) return Input::RESET;
	return Input::BUTTON_COUNT;
}

void SetButtonMapping(const char* button_id, const char* key_id) {
	Schedule([button = std::string(button_id ? button_id : ""),
			  key = std::string(key_id ? key_id : "")]() {
		auto btn = ResolveButtonId(button.c_str());
		if (btn == Input::BUTTON_COUNT || !Input::source) {
			return;
		}

		Input::Keys::InputKey input_key = Input::Keys::NONE;
		std::string key_upper = key;
		std::transform(key_upper.begin(), key_upper.end(), key_upper.begin(),
			[](unsigned char c) { return static_cast<char>(std::toupper(c)); });
		if (!Input::Keys::kInputKeyNames.etag(key_upper.c_str(), input_key)) {
			return;
		}

		auto& mappings = Input::source->GetButtonMappings();
		std::array<Input::Keys::InputKey, 1> keys = { input_key };
		mappings.ReplaceAll(btn, keys.begin(), keys.end());
	});
}

void ResetButtonMappings() {
	Schedule([]() {
		Input::ResetAllMappings();
	});
}

void VirtualTouchDown(float x, float y) {
	Schedule([x, y]() { SimulateVirtualPress(x, y); });
}

void VirtualTouchMove(float x, float y) {
	Schedule([x, y]() { SimulateVirtualPress(x, y); });
}

void VirtualTouchUp() {
	Schedule([]() {});
}

void SetVirtualButtonPoint(const char* button_id, float x, float y) {
	Schedule([button = std::string(button_id ? button_id : ""), x, y]() {
		auto key = ResolveVirtualButtonKey(button.c_str());
		if (key == Input::Keys::NONE) return;
		for (auto& p : virtual_points) {
			if (p.key == key) {
				p.x = x;
				p.y = y;
				return;
			}
		}
		virtual_points.push_back({x, y, key});
	});
}

void LaunchGame(const char* args) {
	Schedule([args_str = std::string(args ? args : "")]() {
		launch_args.clear();
		launch_args.emplace_back("EasyRPGPlayer");
		auto split = Utils::Tokenize(args_str, [](char32_t c) { return c == U' '; });
		launch_args.insert(launch_args.end(), split.begin(), split.end());
		has_launch_args = true;
	});
}

void SendKeyDown(const char* button_id) {
	Schedule([button = std::string(button_id ? button_id : "")]() {
		if (!Input::source) return;
		auto add_held_key = [](Input::Keys::InputKey key) {
			if (key == Input::Keys::NONE) return;
			if (std::find(held_keys.begin(), held_keys.end(), key) == held_keys.end()) {
				held_keys.push_back(key);
			}
		};
		auto btn = ResolveButtonId(button.c_str());
		if (btn != Input::BUTTON_COUNT) {
			auto& mappings = Input::source->GetButtonMappings();
			for (auto it = mappings.LowerBound(btn);
				 it != mappings.end() && it->first == btn; ++it) {
				add_held_key(it->second);
			}
			return;
		}

		auto key = ResolveVirtualButtonKey(button.c_str());
		if (key == Input::Keys::NONE) {
			std::string key_upper = button;
			std::transform(key_upper.begin(), key_upper.end(), key_upper.begin(),
				[](unsigned char c) { return static_cast<char>(std::toupper(c)); });
			Input::Keys::kInputKeyNames.etag(key_upper.c_str(), key);
		}
		if (key != Input::Keys::NONE) {
			add_held_key(key);
		}
	});
}

void SendKeyUp(const char* button_id) {
	Schedule([button = std::string(button_id ? button_id : "")]() {
		auto remove_held_key = [](Input::Keys::InputKey key) {
			if (key == Input::Keys::NONE) return;
			held_keys.erase(std::remove(held_keys.begin(), held_keys.end(), key), held_keys.end());
		};

		auto btn = ResolveButtonId(button.c_str());
		if (btn != Input::BUTTON_COUNT && Input::source) {
			auto& mappings = Input::source->GetButtonMappings();
			for (auto it = mappings.LowerBound(btn);
				 it != mappings.end() && it->first == btn; ++it) {
				remove_held_key(it->second);
			}
			return;
		}

		auto key = ResolveVirtualButtonKey(button.c_str());
		if (key == Input::Keys::NONE) {
			std::string key_upper = button;
			std::transform(key_upper.begin(), key_upper.end(), key_upper.begin(),
				[](unsigned char c) { return static_cast<char>(std::toupper(c)); });
			Input::Keys::kInputKeyNames.etag(key_upper.c_str(), key);
		}
		remove_held_key(key);
	});
}

bool ConsumeLaunchArgs(std::vector<std::string>& out_args) {
	if (!has_launch_args) {
		return false;
	}
	out_args = launch_args;
	has_launch_args = false;
	return !out_args.empty();
}
}

extern "C" {
void EasyRPG_iOS_EndGame() {
	IOSIntegration::EndGame();
}

void EasyRPG_iOS_ResetGame() {
	IOSIntegration::ResetGame();
}

void EasyRPG_iOS_ToggleFps() {
	IOSIntegration::ToggleFps();
}

void EasyRPG_iOS_OpenSettings() {
	IOSIntegration::OpenSettings();
}

void EasyRPG_iOS_SetButtonMapping(const char* button_id, const char* key_id) {
	IOSIntegration::SetButtonMapping(button_id, key_id);
}

void EasyRPG_iOS_ResetButtonMappings() {
	IOSIntegration::ResetButtonMappings();
}

void EasyRPG_iOS_VirtualTouchDown(float x, float y) {
	IOSIntegration::VirtualTouchDown(x, y);
}

void EasyRPG_iOS_VirtualTouchMove(float x, float y) {
	IOSIntegration::VirtualTouchMove(x, y);
}

void EasyRPG_iOS_VirtualTouchUp() {
	IOSIntegration::VirtualTouchUp();
}

void EasyRPG_iOS_SetVirtualButtonPoint(const char* button_id, float x, float y) {
	IOSIntegration::SetVirtualButtonPoint(button_id, x, y);
}

void EasyRPG_iOS_LaunchGame(const char* args) { IOSIntegration::LaunchGame(args); }
void EasyRPG_iOS_SendKeyDown(const char* button_id) { IOSIntegration::SendKeyDown(button_id); }
void EasyRPG_iOS_SendKeyUp(const char* button_id) { IOSIntegration::SendKeyUp(button_id); }
void EasyRPG_iOS_SetLayoutTransparency(float) {}
void EasyRPG_iOS_SetLayoutSize(float) {}
void EasyRPG_iOS_SetVibrationEnabled(bool) {}
void EasyRPG_iOS_SetVibrateWhenSlidingEnabled(bool) {}

void EasyRPG_iOS_SetMusicVolume(int32_t volume) {
	Schedule([volume]() {
		const auto clamped = std::max<int32_t>(0, std::min<int32_t>(100, volume));
		Audio().BGM_SetGlobalVolume(static_cast<int>(clamped));
	});
}

void EasyRPG_iOS_SetSoundVolume(int32_t volume) {
	Schedule([volume]() {
		const auto clamped = std::max<int32_t>(0, std::min<int32_t>(100, volume));
		Audio().SE_SetGlobalVolume(static_cast<int>(clamped));
	});
}

void EasyRPG_iOS_SetSoundFont(const char* path) {
	Schedule([soundfont = std::string(path ? path : "")]() {
		Audio().SetFluidsynthSoundfont(soundfont);
	});
}

void EasyRPG_iOS_SetFullscreen(bool enabled) {
	Schedule([enabled]() {
		if (!DisplayUi) return;
		if (DisplayUi->GetConfig().fullscreen.Get() != enabled) {
			DisplayUi->ToggleFullscreen();
		}
	});
}

void EasyRPG_iOS_SetForcedLandscape(bool) {}

void EasyRPG_iOS_SetImageScaleMode(int32_t mode) {
	Schedule([mode]() {
		if (!DisplayUi) return;
		ConfigEnum::ScalingMode sm = ConfigEnum::ScalingMode::Nearest;
		if (mode == 1) sm = ConfigEnum::ScalingMode::Integer;
		else if (mode == 2) sm = ConfigEnum::ScalingMode::Bilinear;
		DisplayUi->SetScalingMode(sm);
	});
}

void EasyRPG_iOS_SetStretch(bool enabled) {
	Schedule([enabled]() {
		if (!DisplayUi) return;
		if (DisplayUi->GetConfig().stretch.Get() != enabled) {
			DisplayUi->ToggleStretch();
		}
	});
}

void EasyRPG_iOS_SetGameResolution(int32_t resolution) {
	Schedule([resolution]() {
		if (!DisplayUi) return;
		ConfigEnum::GameResolution gr = ConfigEnum::GameResolution::Original;
		if (resolution == 1) gr = ConfigEnum::GameResolution::Widescreen;
		else if (resolution == 2) gr = ConfigEnum::GameResolution::Ultrawide;
		DisplayUi->SetGameResolution(gr);
	});
}

void EasyRPG_iOS_SetFont1(const char* font_name) {
	Schedule([font = std::string(font_name ? font_name : "")]() {
		Player::player_config.font1.Set(font);
		Font::ResetDefault();
	});
}

void EasyRPG_iOS_SetFont2(const char* font_name) {
	Schedule([font = std::string(font_name ? font_name : "")]() {
		Player::player_config.font2.Set(font);
		Font::ResetDefault();
	});
}

void EasyRPG_iOS_SetFont1Size(int32_t size) {
	Schedule([size]() {
		Player::player_config.font1_size.Set(static_cast<int>(size));
		Font::ResetDefault();
	});
}

void EasyRPG_iOS_SetFont2Size(int32_t size) {
	Schedule([size]() {
		Player::player_config.font2_size.Set(static_cast<int>(size));
		Font::ResetDefault();
	});
}
}

#endif
