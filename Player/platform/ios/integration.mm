#include "system.h"

#if defined(__APPLE__) && TARGET_OS_IOS

#include <functional>
#include <mutex>
#include <atomic>
#include <algorithm>
#include <array>
#include <cstring>
#include <cctype>
#include <vector>
#include <string>
#include <dispatch/dispatch.h>
#define SDL_MAIN_HANDLED
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include "platform/ios/integration.h"
#include "output.h"
#include "player.h"
#include "input.h"
#include "input_buttons.h"
#include "utils.h"
#include "baseui.h"
#include "audio.h"
#include "font.h"
#include "filefinder.h"
#include "main_data.h"
#include "platform/ios/ios_utils.h"


namespace {
void LogBridgeCall(const char* fn) {
	Output::Debug("[iOSBridge] {}", fn ? fn : "<null>");
}
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
bool has_pending_relaunch_args = false;
std::vector<Input::Keys::InputKey> held_keys;
std::atomic<bool> runtime_started{false};
std::atomic<bool> restart_requested{false};

bool ConsumeLaunchArgs(std::vector<std::string>& out_args);


std::string ResolveLaunchPathForIOS(std::string_view raw_path) {
	auto canonical = FileFinder::MakeCanonical(raw_path, 0);
	const bool has_namespace = canonical.find("://") != std::string::npos;
	const bool is_absolute = !canonical.empty() && canonical.front() == '/';
	if (has_namespace || is_absolute) {
		return canonical;
	}

	std::vector<std::pair<std::string, std::string>> candidates;
	candidates.emplace_back("as-is", canonical);

	auto append_under = [&](const std::string& base, std::string_view rel, const char* label) {
		if (base.empty()) {
			return;
		}
		auto path = FileFinder::MakeCanonical(FileFinder::MakePath(base, rel), 0);
		candidates.emplace_back(label, std::move(path));
	};

	auto docs_root = IOSUtils::GetDocumentsDir();
	if (!docs_root.empty()) {
		append_under(docs_root, canonical, "documents");

		// Handle paths prefixed with "Documents/" where "Documents" means
		// the app's document root itself (not "<home>/Documents").
		const auto slash = canonical.find('/');
		auto top = canonical.substr(0, slash);
		auto rel = slash == std::string::npos ? std::string_view() : std::string_view(canonical).substr(slash + 1);
		if (!top.empty() && Utils::LowerCase(top) == "documents") {
			if (!rel.empty()) {
				append_under(docs_root, rel, "documents-trimmed");
			}
		}
	}

	auto default_root = Main_Data::GetDefaultProjectPath();
	if (!default_root.empty()) {
		auto default_path = FileFinder::MakeCanonical(FileFinder::MakePath(default_root, canonical), 0);
		candidates.emplace_back("default-root", default_path);
	}

	for (const auto& candidate : candidates) {
		auto fs = FileFinder::Root().Create(candidate.second);
		if (!fs) {
			continue;
		}
		const bool is_project = FileFinder::IsValidProject(fs);
		auto entries = fs.ListDirectory();
		if (is_project || entries) {
			Output::Debug("[iOSBridge] Relative path '{}' resolved via {} -> '{}' (project={} listdir={})",
				canonical, candidate.first, candidate.second, is_project, entries ? 1 : 0);
			return candidate.second;
		}
	}

	return canonical;
}

std::string ResolveAuxPathForIOS(std::string_view raw_path) {
	auto canonical = FileFinder::MakeCanonical(raw_path, 0);
	const bool has_namespace = canonical.find("://") != std::string::npos;
	const bool is_absolute = !canonical.empty() && canonical.front() == '/';
	if (has_namespace || is_absolute) {
		return canonical;
	}

	auto docs_root = IOSUtils::GetDocumentsDir();
	auto home_root = docs_root;
	const auto last_slash = home_root.find_last_of('/');
	if (last_slash != std::string::npos) {
		home_root.erase(last_slash);
	}

	const auto slash = canonical.find('/');
	auto top = canonical.substr(0, slash);
	auto rel = slash == std::string::npos ? std::string_view() : std::string_view(canonical).substr(slash + 1);
	auto top_lower = Utils::LowerCase(top);

	if (top_lower == "documents") {
		return rel.empty() ? docs_root : FileFinder::MakeCanonical(FileFinder::MakePath(docs_root, rel), 0);
	}
	if (top_lower == "library") {
		return FileFinder::MakeCanonical(FileFinder::MakePath(home_root, canonical), 0);
	}
	if (top_lower == "tmp" || top_lower == "temporary") {
		return FileFinder::MakeCanonical(FileFinder::MakePath(home_root, "tmp"), 0);
	}
	if (top_lower == "caches") {
		return FileFinder::MakeCanonical(FileFinder::MakePath(home_root, "Library/Caches"), 0);
	}
	if (top_lower == "preferences") {
		return FileFinder::MakeCanonical(FileFinder::MakePath(home_root, "Library/Preferences"), 0);
	}
	if (top_lower == "application support" || top_lower == "appsupport") {
		return FileFinder::MakeCanonical(FileFinder::MakePath(home_root, "Library/Application Support"), 0);
	}

	// Fallback for unknown relative aux paths: anchor in Library to avoid
	// process working-directory dependent behavior in containerized runtimes.
	auto fallback = FileFinder::MakeCanonical(FileFinder::MakePath(home_root, FileFinder::MakePath("Library", canonical)), 0);
	Output::Warning("[iOSBridge] Unrecognized aux relative path '{}', fallback to '{}'", canonical, fallback);
	return fallback;
}



void LogProjectProbe(const FilesystemView& fs, const char* label) {
	if (!fs) {
		Output::Warning("[iOSBridge] {} filesystem is invalid", label);
		return;
	}
	auto ldb = fs.FindFile("RPG_RT.ldb");
	auto lmt = fs.FindFile("RPG_RT.lmt");
	Output::Debug("[iOSBridge] {} probe fullpath='{}' RPG_RT.ldb='{}' RPG_RT.lmt='{}' valid_project={}",
		label,
		fs.GetFullPath(),
		ldb,
		lmt,
		FileFinder::IsValidProject(fs));
	auto files = fs.ListDirectory();
	if (!files) {
		Output::Warning("[iOSBridge] {} probe listdir failed for '{}'", label, fs.GetFullPath());
	} else {
		Output::Debug("[iOSBridge] {} probe listdir entries={}", label, files->size());
	}
}
Input::Keys::InputKey ResolveVirtualButtonKey(const char* id) {
	if (!id) return Input::Keys::NONE;
	if (strcmp(id, "up") == 0) return Input::Keys::UP;
	if (strcmp(id, "down") == 0) return Input::Keys::DOWN;
	if (strcmp(id, "left") == 0) return Input::Keys::LEFT;
	if (strcmp(id, "right") == 0) return Input::Keys::RIGHT;
	if (strcmp(id, "z") == 0 || strcmp(id, "decision") == 0) return Input::Keys::Z;
	if (strcmp(id, "x") == 0 || strcmp(id, "cancel") == 0) return Input::Keys::X;
	if (strcmp(id, "shift") == 0) return Input::Keys::SHIFT;
	if (strcmp(id, "fast_forward_a") == 0) return Input::Keys::TAB;
	if (strcmp(id, "settings_menu") == 0 || strcmp(id, "menu") == 0) return Input::Keys::F1;
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

void StartRuntimeIfNeeded() {
	bool expected = false;
	if (!runtime_started.compare_exchange_strong(expected, true)) {
		Output::Debug("[iOSBridge] StartRuntimeIfNeeded ignored: runtime already started");
		return;
	}

	{
		std::lock_guard<std::mutex> lock(ios_mutex);
		if (!has_launch_args) {
			// iOS app flow expects launch args (especially --project-path) to be
			// registered before runtime starts. Starting without them boots to the
			// generic EasyRPG menu and later LaunchGame() cannot re-run argv parsing.
			Output::Warning("[iOSBridge] StartRuntimeIfNeeded called without launch args; runtime start skipped");
			runtime_started = false;
			return;
		}
	}

	dispatch_async(dispatch_get_main_queue(), ^{
		// iOS SwiftUI entrypoint does not go through SDL's usual C main wrapper.
		// Mark SDL as main-ready before first SDL_Init() to avoid
		// "did you include SDL_main.h" initialization failure.
		SDL_SetMainReady();

		std::vector<std::string> args;
		if (!ConsumeLaunchArgs(args) || args.empty()) {
			args.emplace_back("EasyRPGPlayer");
		}
		Output::Debug("[iOSBridge] StartRuntimeIfNeeded booting Player::Init with {} args", args.size());
		for (size_t i = 0; i < args.size(); ++i) {
			Output::Debug("[iOSBridge] Player::Init argv[{}]='{}'", i, args[i]);
		}
		Player::Init(std::move(args));
		Player::Run();
		runtime_started = false;
		Output::Debug("[iOSBridge] Player::Run returned; runtime_started=false");
		if (restart_requested.exchange(false)) {
			Output::Debug("[iOSBridge] restart_requested=true -> reboot runtime with pending args");
			StartRuntimeIfNeeded();
		}
	});
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
	const std::string args_str = std::string(args ? args : "");
	Output::Debug("[iOSBridge] LaunchGame raw args string='{}'", args_str);
	std::vector<std::string> parsed_args;
	parsed_args.emplace_back("EasyRPGPlayer");
	auto split = Utils::Tokenize(args_str, [](char32_t c) {
		return c == 0x1F || c == U'\n';
	});
	parsed_args.insert(parsed_args.end(), split.begin(), split.end());
	for (size_t i = 0; i < parsed_args.size(); ++i) {
		Output::Debug("[iOSBridge] LaunchGame argv[{}]='{}'", i, parsed_args[i]);
	}

	// Runtime path wiring for custom iOS UI -> Player connection.
	// This allows launching/switching games after the app is already running.
	for (size_t i = 0; i + 1 < parsed_args.size(); ++i) {
		if (parsed_args[i] == "--project-path") {
			auto canonical_project = ResolveLaunchPathForIOS(parsed_args[i + 1]);
			Output::Debug("[iOSBridge] --project-path raw='{}' canonical='{}'", parsed_args[i + 1], canonical_project);
			parsed_args[i + 1] = canonical_project;
			auto gamefs = FileFinder::Root().Create(canonical_project);
			if (gamefs) {
				FileFinder::SetGameFilesystem(gamefs);
				Output::Debug("[iOSBridge] Game filesystem set to '{}'", gamefs.GetFullPath());
				LogProjectProbe(gamefs, "game");
			} else {
				Output::Warning("[iOSBridge] Failed to create game filesystem from '{}'", canonical_project);
			}
			++i;
			continue;
		}
		if (parsed_args[i] == "--save-path") {
			auto canonical_save = ResolveLaunchPathForIOS(parsed_args[i + 1]);
			Output::Debug("[iOSBridge] --save-path raw='{}' canonical='{}'", parsed_args[i + 1], canonical_save);
			parsed_args[i + 1] = canonical_save;
			auto savefs = FileFinder::Root().Create(canonical_save);
			if (savefs) {
				FileFinder::SetSaveFilesystem(savefs);
				Output::Debug("[iOSBridge] Save filesystem set to '{}'", savefs.GetFullPath());
				LogProjectProbe(savefs, "save");
			} else {
				Output::Warning("[iOSBridge] Failed to create save filesystem from '{}'", canonical_save);
			}
			++i;
			continue;
		}
		if (parsed_args[i] == "--config-path" || parsed_args[i] == "--log-file" || parsed_args[i] == "--soundfont") {
			auto canonical_path = ResolveAuxPathForIOS(parsed_args[i + 1]);
			Output::Debug("[iOSBridge] {} raw='{}' canonical='{}'", parsed_args[i], parsed_args[i + 1], canonical_path);
			parsed_args[i + 1] = canonical_path;
			++i;
			continue;
		}
	}


	// Android parity: command line is available before SDL/Player bootstrap.
	{
		std::lock_guard<std::mutex> lock(ios_mutex);
		launch_args = parsed_args;
		has_launch_args = true;
		has_pending_relaunch_args = true;
		Output::Debug("[iOSBridge] launch_args registered count={} has_pending_relaunch_args=1", launch_args.size());
	}

	// If runtime is not running yet, start it now that launch args are registered.
	// This enforces the required ordering: LaunchGame(args) -> Player::Init(args).
	if (!runtime_started.load()) {
		StartRuntimeIfNeeded();
		return;
	}

	// When runtime is already running, request reload like Android relaunch behavior.
	if (runtime_started.load()) {
		Output::Debug("[iOSBridge] runtime already running; requesting full restart to re-parse argv");
		restart_requested = true;
		Schedule([]() {
			// Root fix: reset does not re-parse argv.
			// Request full shutdown; runtime thread will auto-restart with latest launch_args.
			Player::exit_flag = true;
		});
	}
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
		Output::Debug("[iOSBridge] ConsumeLaunchArgs: no args available");
		return false;
	}
	out_args = launch_args;
	has_launch_args = false;
	has_pending_relaunch_args = false;
	Output::Debug("[iOSBridge] ConsumeLaunchArgs: consumed {} args", out_args.size());
	return !out_args.empty();
}
}

extern "C" {
void EasyRPG_iOS_EndGame() {
	LogBridgeCall("EasyRPG_iOS_EndGame");
	IOSIntegration::EndGame();
}
void EasyRPG_iOS_StartRuntime() {
	LogBridgeCall("EasyRPG_iOS_StartRuntime");
	IOSIntegration::StartRuntimeIfNeeded();
}
void EasyRPG_iOS_ResetGame() {
	LogBridgeCall("EasyRPG_iOS_ResetGame");
	IOSIntegration::ResetGame();
}

void EasyRPG_iOS_ToggleFps() {
	LogBridgeCall("EasyRPG_iOS_ToggleFps");
	IOSIntegration::ToggleFps();
}

void EasyRPG_iOS_OpenSettings() {
	LogBridgeCall("EasyRPG_iOS_OpenSettings");
	IOSIntegration::OpenSettings();
}

void EasyRPG_iOS_SetButtonMapping(const char* button_id, const char* key_id) {
	LogBridgeCall("EasyRPG_iOS_SetButtonMapping");
	IOSIntegration::SetButtonMapping(button_id, key_id);
}

void EasyRPG_iOS_ResetButtonMappings() {
	LogBridgeCall("EasyRPG_iOS_ResetButtonMappings");
	IOSIntegration::ResetButtonMappings();
}

void EasyRPG_iOS_VirtualTouchDown(float x, float y) {
	LogBridgeCall("EasyRPG_iOS_VirtualTouchDown");
	IOSIntegration::VirtualTouchDown(x, y);
}

void EasyRPG_iOS_VirtualTouchMove(float x, float y) {
	LogBridgeCall("EasyRPG_iOS_VirtualTouchMove");
	IOSIntegration::VirtualTouchMove(x, y);
}

void EasyRPG_iOS_VirtualTouchUp() {
	LogBridgeCall("EasyRPG_iOS_VirtualTouchUp");
	IOSIntegration::VirtualTouchUp();
}

void EasyRPG_iOS_SetVirtualButtonPoint(const char* button_id, float x, float y) {
	LogBridgeCall("EasyRPG_iOS_SetVirtualButtonPoint");
	IOSIntegration::SetVirtualButtonPoint(button_id, x, y);
}

void EasyRPG_iOS_LaunchGame(const char* args) { LogBridgeCall("EasyRPG_iOS_LaunchGame"); IOSIntegration::LaunchGame(args); }
void EasyRPG_iOS_SendKeyDown(const char* button_id) { LogBridgeCall("EasyRPG_iOS_SendKeyDown"); IOSIntegration::SendKeyDown(button_id); }
void EasyRPG_iOS_SendKeyUp(const char* button_id) { LogBridgeCall("EasyRPG_iOS_SendKeyUp"); IOSIntegration::SendKeyUp(button_id); }
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

void EasyRPG_iOS_SetFastForwardSpeedA(int32_t speed) {
	Schedule([speed]() {
		const auto clamped = std::max<int32_t>(2, std::min<int32_t>(100, speed));
		if (auto* source = Input::GetInputSource()) {
			source->GetConfig().speed_modifier_a.Set(static_cast<int>(clamped));
		}
	});
}

void EasyRPG_iOS_SetFastForwardSpeedB(int32_t speed) {
	Schedule([speed]() {
		const auto clamped = std::max<int32_t>(2, std::min<int32_t>(100, speed));
		if (auto* source = Input::GetInputSource()) {
			source->GetConfig().speed_modifier_b.Set(static_cast<int>(clamped));
		}
	});
}

void EasyRPG_iOS_SetSettingsInMenu(bool enabled) {
	Schedule([enabled]() {
		Player::player_config.settings_in_menu.Set(enabled);
	});
}

void EasyRPG_iOS_SetLanguageSelectOnStart(int32_t mode) {
	Schedule([mode]() {
		ConfigEnum::StartupLangSelect value = ConfigEnum::StartupLangSelect::Never;
		if (mode == 1) value = ConfigEnum::StartupLangSelect::FirstStartup;
		else if (mode == 2) value = ConfigEnum::StartupLangSelect::Always;
		Player::player_config.lang_select_on_start.Set(value);
	});
}

void EasyRPG_iOS_SetConfigBool(const char* section, const char* key, bool value) {
	Schedule([section_s = std::string(section ? section : ""),
	          key_s = std::string(key ? key : ""), value]() {
		if (section_s == "Video") {
			if (key_s == "Fullscreen") {
				if (DisplayUi && DisplayUi->GetConfig().fullscreen.Get() != value) {
					DisplayUi->ToggleFullscreen();
				}
			}
			else if (key_s == "Stretch") {
				if (DisplayUi && DisplayUi->GetConfig().stretch.Get() != value) {
					DisplayUi->ToggleStretch();
				}
			}
		}
		else if (section_s == "Audio") {
			if (key_s == "Fluidsynth") {
				Player::game_config.audio.fluidsynth_midi.Set(value);
			}
			else if (key_s == "WildMidi") {
				Player::game_config.audio.wildmidi_midi.Set(value);
			}
			else if (key_s == "NativeMidi") {
				Player::game_config.audio.native_midi.Set(value);
			}
		}
		else if (section_s == "Input") {
			if (!Input::GetInputSource()) return;
			auto& cfg = Input::GetInputSource()->GetConfig();
			if (key_s == "GamepadSwapAnalog") {
				cfg.gamepad_swap_analog.Set(value);
			}
			else if (key_s == "GamepadSwapDpad") {
				cfg.gamepad_swap_dpad_with_buttons.Set(value);
			}
			else if (key_s == "GamepadSwapAbxy") {
				cfg.gamepad_swap_ab_and_xy.Set(value);
			}
		}
		if (section_s == "Player") {
			if (key_s == "SettingsAutosave") Player::player_config.settings_autosave.Set(value);
			else if (key_s == "SettingsInTitle") Player::player_config.settings_in_title.Set(value);
			else if (key_s == "SettingsInMenu") Player::player_config.settings_in_menu.Set(value);
			else if (key_s == "LanguageInTitle") Player::player_config.lang_select_in_title.Set(value);
			else if (key_s == "Logging") Player::player_config.log_enabled.Set(value);
			else if (key_s == "ScreenshotTimestamp") Player::player_config.screenshot_timestamp.Set(value);
			else if (key_s == "AutomaticScreenshots") Player::player_config.automatic_screenshots.Set(value);
		}
	});
}

void EasyRPG_iOS_SetConfigInt(const char* section, const char* key, int32_t value) {
	Schedule([section_s = std::string(section ? section : ""),
	          key_s = std::string(key ? key : ""), value]() {
		if (section_s == "Video") {
			if (!DisplayUi) return;
			if (key_s == "ScalingMode") {
				ConfigEnum::ScalingMode sm = ConfigEnum::ScalingMode::Nearest;
				if (value == 1) sm = ConfigEnum::ScalingMode::Integer;
				else if (value >= 2) sm = ConfigEnum::ScalingMode::Bilinear;
				DisplayUi->SetScalingMode(sm);
			}
			else if (key_s == "GameResolution") {
				ConfigEnum::GameResolution gr = ConfigEnum::GameResolution::Original;
				if (value == 1) gr = ConfigEnum::GameResolution::Widescreen;
				else if (value >= 2) gr = ConfigEnum::GameResolution::Ultrawide;
				DisplayUi->SetGameResolution(gr);
			}
		}
		else if (section_s == "Audio") {
			if (key_s == "MusicVolume") {
				const auto clamped = std::max<int32_t>(0, std::min<int32_t>(100, value));
				Audio().BGM_SetGlobalVolume(static_cast<int>(clamped));
			}
			else if (key_s == "SoundVolume") {
				const auto clamped = std::max<int32_t>(0, std::min<int32_t>(100, value));
				Audio().SE_SetGlobalVolume(static_cast<int>(clamped));
			}
		}
		else if (section_s == "Input") {
			if (key_s == "SpeedModifierA") {
				const auto clamped = std::max<int32_t>(2, std::min<int32_t>(100, value));
				if (auto* source = Input::GetInputSource()) {
					source->GetConfig().speed_modifier_a.Set(static_cast<int>(clamped));
				}
			}
			else if (key_s == "SpeedModifierB") {
				const auto clamped = std::max<int32_t>(2, std::min<int32_t>(100, value));
				if (auto* source = Input::GetInputSource()) {
					source->GetConfig().speed_modifier_b.Set(static_cast<int>(clamped));
				}
			}
		}
		else if (section_s == "Player") {
			if (key_s == "Font1Size") Player::player_config.font1_size.Set(static_cast<int>(std::max<int32_t>(6, value)));
			else if (key_s == "Font2Size") Player::player_config.font2_size.Set(static_cast<int>(std::max<int32_t>(6, value)));
			else if (key_s == "LanguageSelectOnStart") {
				ConfigEnum::StartupLangSelect startup_lang = ConfigEnum::StartupLangSelect::Never;
				if (value == 1) startup_lang = ConfigEnum::StartupLangSelect::FirstStartup;
				else if (value >= 2) startup_lang = ConfigEnum::StartupLangSelect::Always;
				Player::player_config.lang_select_on_start.Set(startup_lang);
			}
			if (key_s == "ScreenshotScale") Player::player_config.screenshot_scale.Set(static_cast<int>(std::max<int32_t>(1, value)));
			else if (key_s == "AutomaticScreenshotsInterval") Player::player_config.automatic_screenshots_interval.Set(static_cast<int>(std::max<int32_t>(1, value)));
			else if (key_s == "StartupLogos") {
				ConfigEnum::StartupLogos logos = ConfigEnum::StartupLogos::Custom;
				if (value <= 0) logos = ConfigEnum::StartupLogos::None;
				else if (value >= 2) logos = ConfigEnum::StartupLogos::All;
				Player::player_config.show_startup_logos.Set(logos);
			}
		}
	});
}

void EasyRPG_iOS_SetConfigString(const char* section, const char* key, const char* value) {
	Schedule([section_s = std::string(section ? section : ""),
	          key_s = std::string(key ? key : ""),
	          value_s = std::string(value ? value : "")]() {
		if (section_s == "Player") {
			if (key_s == "Font1") Player::player_config.font1.Set(value_s);
			else if (key_s == "Font2") Player::player_config.font2.Set(value_s);
		}
		else if (section_s == "Audio") {
			if (key_s == "Soundfont") {
				Player::game_config.audio.soundfont.Set(value_s);
				Audio().SetFluidsynthSoundfont(value_s);
			}
		}
	});
}
}

#endif
