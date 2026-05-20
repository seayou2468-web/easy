import SwiftUI

struct VirtualButtonLayout: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var x: CGFloat
    var y: CGFloat

    /// Android parity: button size factor (100 = default)
    var size: Int = 100

    static let `default`: [VirtualButtonLayout] = [
        // Horizontal defaults from Android InputLayout.getDefaultHorizontalButtonList
        .init(id: "menu", title: "M", x: 0.01, y: 0.01, size: 90),
        .init(id: "up", title: "↑", x: 0.01, y: 0.32),
        .init(id: "down", title: "↓", x: 0.01, y: 0.48),
        .init(id: "left", title: "←", x: -0.06, y: 0.40),
        .init(id: "right", title: "→", x: 0.09, y: 0.40),
        .init(id: "decision", title: "A", x: 0.80, y: 0.55),
        .init(id: "cancel", title: "B", x: 0.90, y: 0.45)
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
            buttons = Self.clamped(VirtualButtonLayout.default)
            return
        }
        let keyed = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        buttons = Self.clamped(VirtualButtonLayout.default.map { keyed[$0.id] ?? $0 })
    }

    func save() {
        AppLogger.log("ENTER save")
        if let data = try? JSONEncoder().encode(buttons) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func reset() {
        AppLogger.log("ENTER reset")
        buttons = Self.clamped(VirtualButtonLayout.default)
        save()
    }

    static let addableButtons: [VirtualButtonLayout] = [
        .init(id: "decision", title: "A", x: 0.5, y: 0.5),
        .init(id: "cancel", title: "B", x: 0.5, y: 0.5),
        .init(id: "shift", title: "S", x: 0.5, y: 0.5),
        .init(id: "0", title: "0", x: 0.5, y: 0.5), .init(id: "1", title: "1", x: 0.5, y: 0.5),
        .init(id: "2", title: "2", x: 0.5, y: 0.5), .init(id: "3", title: "3", x: 0.5, y: 0.5),
        .init(id: "4", title: "4", x: 0.5, y: 0.5), .init(id: "5", title: "5", x: 0.5, y: 0.5),
        .init(id: "6", title: "6", x: 0.5, y: 0.5), .init(id: "7", title: "7", x: 0.5, y: 0.5),
        .init(id: "8", title: "8", x: 0.5, y: 0.5), .init(id: "9", title: "9", x: 0.5, y: 0.5),
        .init(id: "+", title: "+", x: 0.5, y: 0.5), .init(id: "-", title: "-", x: 0.5, y: 0.5),
        .init(id: "*", title: "*", x: 0.5, y: 0.5), .init(id: "/", title: "/", x: 0.5, y: 0.5),
        .init(id: "menu", title: "M", x: 0.5, y: 0.5, size: 90),
        .init(id: "fast_forward_a", title: "»", x: 0.5, y: 0.5),
        .init(id: "debug_menu", title: "M", x: 0.5, y: 0.5),
        .init(id: "debug_through", title: "T", x: 0.5, y: 0.5)
    ]

    private static func clamped(_ buttons: [VirtualButtonLayout]) -> [VirtualButtonLayout] {
        buttons.map { b in
            var m = b
            m.x = min(max(0.0, m.x), 1.0)
            m.y = min(max(0.0, m.y), 1.0)
            return m
        }
    }
}
