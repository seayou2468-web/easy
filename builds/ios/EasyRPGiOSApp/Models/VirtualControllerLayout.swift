import SwiftUI

struct VirtualButtonLayout: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var x: CGFloat
    var y: CGFloat

    static let `default`: [VirtualButtonLayout] = [
        .init(id: "up", title: "↑", x: 70, y: 320),
        .init(id: "down", title: "↓", x: 70, y: 410),
        .init(id: "left", title: "←", x: 25, y: 365),
        .init(id: "right", title: "→", x: 115, y: 365),
        .init(id: "z", title: "Z", x: 320, y: 350),
        .init(id: "x", title: "X", x: 380, y: 300),
        .init(id: "shift", title: "S", x: 300, y: 420),
        .init(id: "fast_forward_a", title: ">>", x: 360, y: 420),
        .init(id: "fast_forward_b", title: "⏩", x: 420, y: 360),
        .init(id: "page_up", title: "L", x: 240, y: 420),
        .init(id: "page_down", title: "R", x: 180, y: 420),
        .init(id: "settings_menu", title: "⚙", x: 420, y: 420),
        .init(id: "toggle_fps", title: "FPS", x: 360, y: 470),
        .init(id: "reset", title: "RST", x: 420, y: 470)
    ]

    static let requiredIds: [String] = Self.default.map(\.id)
}

@MainActor
final class VirtualControllerLayoutStore: ObservableObject {
    @Published var buttons: [VirtualButtonLayout] = []
    private let key = "ios.virtualControllerLayout"

    init() { load() }

    func load() {
        AppLogger.log("ENTER load")
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VirtualButtonLayout].self, from: data),
              !decoded.isEmpty else {
            buttons = VirtualButtonLayout.default
            return
        }
        let keyed = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        buttons = VirtualButtonLayout.default.map { keyed[$0.id] ?? $0 }
    }

    func save() {
        AppLogger.log("ENTER save")
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        AppLogger.log("ENTER reset")
        buttons = VirtualButtonLayout.default
        save()
    }
}
