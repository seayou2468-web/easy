import SwiftUI

struct VirtualButtonLayout: Codable, Hashable {
    var id: String
    var title: String
    var x: CGFloat
    var y: CGFloat
    var instanceId: String = UUID().uuidString

    /// Android parity: button size factor (100 = default)
    var size: Int = 100

    static let `default`: [VirtualButtonLayout] = [
        .init(id: "menu", title: "M", x: 0.05, y: 0.08, size: 90),
        // Android-parity cross d-pad arrangement
        .init(id: "up", title: "↑", x: 0.16, y: 0.66),
        .init(id: "down", title: "↓", x: 0.16, y: 0.84),
        .init(id: "left", title: "←", x: 0.07, y: 0.75),
        .init(id: "right", title: "→", x: 0.25, y: 0.75),
        .init(id: "decision", title: "A", x: 0.80, y: 0.55),
        .init(id: "cancel", title: "B", x: 0.90, y: 0.45)
    ]

    static let requiredIds: [String] = Self.default.map(\.id)
}

struct VirtualControllerLayoutProfile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var portraitButtons: [VirtualButtonLayout]
    var landscapeButtons: [VirtualButtonLayout]

    static let `default` = VirtualControllerLayoutProfile(
        id: "default",
        name: "Default",
        portraitButtons: VirtualButtonLayout.default,
        landscapeButtons: VirtualButtonLayout.default
    )
}

@MainActor
final class VirtualControllerLayoutStore: ObservableObject {
    @Published var profiles: [VirtualControllerLayoutProfile] = []
    @Published var activeProfileId: String = VirtualControllerLayoutProfile.default.id

    private let key = "ios.virtualControllerLayoutProfiles"
    private let activeKey = "ios.virtualControllerLayoutActiveProfile"

    init() { load() }

    var activeProfile: VirtualControllerLayoutProfile {
        get { profiles.first(where: { $0.id == activeProfileId }) ?? profiles.first ?? VirtualControllerLayoutProfile.default }
        set {
            guard let idx = profiles.firstIndex(where: { $0.id == activeProfileId }) else { return }
            profiles[idx] = normalized(profile: newValue)
            save()
        }
    }

    func buttons(isLandscape: Bool) -> [VirtualButtonLayout] {
        let profile = activeProfile
        return isLandscape ? profile.landscapeButtons : profile.portraitButtons
    }

    func updateButtons(_ newButtons: [VirtualButtonLayout], isLandscape: Bool) {
        var profile = activeProfile
        if isLandscape {
            profile.landscapeButtons = clamped(newButtons)
        } else {
            profile.portraitButtons = clamped(newButtons)
        }
        upsert(profile: profile)
    }

    func setActiveProfile(_ id: String) {
        if profiles.contains(where: { $0.id == id }) {
            activeProfileId = id
            UserDefaults.standard.set(id, forKey: activeKey)
            objectWillChange.send()
        }
    }

    func addProfile(name: String) {
        let profile = VirtualControllerLayoutProfile(id: UUID().uuidString, name: name.isEmpty ? "Layout" : name, portraitButtons: VirtualButtonLayout.default, landscapeButtons: VirtualButtonLayout.default)
        profiles.append(normalized(profile: profile))
        setActiveProfile(profile.id)
        save()
    }

    func upsert(profile: VirtualControllerLayoutProfile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = normalized(profile: profile)
        } else {
            profiles.append(normalized(profile: profile))
        }
        save()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([VirtualControllerLayoutProfile].self, from: data),
              !decoded.isEmpty else {
            profiles = [normalized(profile: .default)]
            activeProfileId = UserDefaults.standard.string(forKey: activeKey) ?? VirtualControllerLayoutProfile.default.id
            return
        }
        profiles = decoded.map { normalized(profile: $0) }
        activeProfileId = UserDefaults.standard.string(forKey: activeKey) ?? profiles[0].id
        if !profiles.contains(where: { $0.id == activeProfileId }) { activeProfileId = profiles[0].id }
    }

    func save() {
        let normalizedProfiles = profiles.map { normalized(profile: $0) }
        profiles = normalizedProfiles
        if let data = try? JSONEncoder().encode(normalizedProfiles) { UserDefaults.standard.set(data, forKey: key) }
        UserDefaults.standard.set(activeProfileId, forKey: activeKey)
    }

    func reset() {
        profiles = [normalized(profile: .default)]
        activeProfileId = VirtualControllerLayoutProfile.default.id
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
        .init(id: "fast_forward_b", title: "»B", x: 0.5, y: 0.5),
        .init(id: "page_up", title: "Pg+", x: 0.5, y: 0.5),
        .init(id: "page_down", title: "Pg-", x: 0.5, y: 0.5),
        .init(id: "reset", title: "R", x: 0.5, y: 0.5),
        .init(id: "toggle_fps", title: "FPS", x: 0.5, y: 0.5),
        .init(id: "debug_menu", title: "M", x: 0.5, y: 0.5),
        .init(id: "debug_through", title: "T", x: 0.5, y: 0.5)
    ]

    func exportActiveProfile() -> URL? {
        let profile = activeProfile
        guard let data = try? JSONEncoder().encode(profile) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("layout-\(profile.name).json")
        try? data.write(to: url)
        return url
    }

    func importProfile(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              var profile = try? JSONDecoder().decode(VirtualControllerLayoutProfile.self, from: data) else { return false }
        profile.id = UUID().uuidString
        upsert(profile: profile)
        setActiveProfile(profile.id)
        return true
    }

    private func normalized(profile: VirtualControllerLayoutProfile) -> VirtualControllerLayoutProfile {
        var p = profile
        p.portraitButtons = normalizedButtons(p.portraitButtons, defaults: VirtualButtonLayout.default)
        p.landscapeButtons = normalizedButtons(p.landscapeButtons, defaults: VirtualButtonLayout.default)
        return p
    }

    private func normalizedButtons(_ buttons: [VirtualButtonLayout], defaults: [VirtualButtonLayout]) -> [VirtualButtonLayout] {
        var result = clamped(buttons)
        for req in defaults where !result.contains(where: { $0.id == req.id }) { result.append(req) }
        return result
    }

    private func clamped(_ buttons: [VirtualButtonLayout]) -> [VirtualButtonLayout] {
        buttons.map { b in
            var m = b
            if m.instanceId.isEmpty { m.instanceId = UUID().uuidString }
            m.x = min(max(0.0, m.x), 1.0)
            m.y = min(max(0.0, m.y), 1.0)
            return m
        }
    }
}
