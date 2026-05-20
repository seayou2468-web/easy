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
        .init(id: "settings_menu", title: "⚙", x: 420, y: 420)
    ]
}

@MainActor
final class VirtualControllerLayoutStore: ObservableObject {
    @Published var buttons: [VirtualButtonLayout] = []
    private let key = "ios.virtualControllerLayout"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VirtualButtonLayout].self, from: data),
              !decoded.isEmpty else {
            buttons = VirtualButtonLayout.default
            return
        }
        buttons = decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        buttons = VirtualButtonLayout.default
        save()
    }
}
