import Foundation

struct ButtonMappingItem: Identifiable, Codable, Hashable {
    let id: String
    var label: String
    var key: String

    static let defaults: [ButtonMappingItem] = [
        .init(id: "up", label: "上", key: "up"),
        .init(id: "down", label: "下", key: "down"),
        .init(id: "left", label: "左", key: "left"),
        .init(id: "right", label: "右", key: "right"),
        .init(id: "decision", label: "入力 (Z)", key: "z"),
        .init(id: "cancel", label: "キャンセル (X)", key: "x"),
        .init(id: "shift", label: "Shift", key: "lshift"),
        .init(id: "fast_forward_a", label: "早送りA", key: "tab"),
        .init(id: "fast_forward_b", label: "早送りB", key: "space"),
        .init(id: "page_up", label: "ページUP", key: "q"),
        .init(id: "page_down", label: "ページDOWN", key: "w"),
        .init(id: "settings_menu", label: "設定メニュー", key: "f1"),
        .init(id: "toggle_fps", label: "FPS切替", key: "f2"),
        .init(id: "reset", label: "リセット", key: "f12")
    ]
}

@MainActor
final class ButtonMappingStore: ObservableObject {
    @Published var mappings: [ButtonMappingItem] = []
    private let key = "ios.buttonMappings"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ButtonMappingItem].self, from: data),
              !decoded.isEmpty else {
            mappings = ButtonMappingItem.defaults
            return
        }
        let keyed = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        mappings = ButtonMappingItem.defaults.map { keyed[$0.id] ?? $0 }
    }

    func save() {
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        mappings = ButtonMappingItem.defaults
        save()
    }

    func applyToPlayer() {
        for item in mappings {
            PlayerBridge.setButtonMapping(buttonId: item.id, keyId: item.key)
        }
    }

    static let supportedButtonIds: [String] = [
        "up", "down", "left", "right",
        "decision", "cancel", "shift",
        "fast_forward_a", "fast_forward_b",
        "page_up", "page_down",
        "settings_menu", "toggle_fps", "reset"
    ]

    static let supportedKeys: [String] = [
        "up", "down", "left", "right",
        "z", "x", "lshift", "tab", "space",
        "q", "w", "f1", "f2", "f12",
        "return", "escape", "a", "s", "d"
    ]
}
