import SwiftUI
import UIKit

@MainActor
final class VirtualControllerOverlayManager {
    static let shared = VirtualControllerOverlayManager()

    private final class PassThroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let hit = super.hitTest(point, with: event) else { return nil }
            return hit === rootViewController?.view ? nil : hit
        }
    }

    private var overlayWindow: PassThroughWindow?
    private weak var scene: UIWindowScene?

    func present(in scene: UIWindowScene, content: some View) {
        self.scene = scene
        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear

        let window: PassThroughWindow
        if let existing = overlayWindow, existing.windowScene === scene {
            window = existing
            if let host = window.rootViewController as? UIHostingController<AnyView> {
                host.rootView = AnyView(content)
            } else {
                window.rootViewController = hosting
            }
        } else {
            window = PassThroughWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.rootViewController = hosting
            window.windowLevel = UIWindow.Level.statusBar + 1
            window.isHidden = false
            overlayWindow = window
        }
    }

    func update(content: some View) {
        guard let window = overlayWindow,
              let host = window.rootViewController as? UIHostingController<AnyView> else { return }
        host.rootView = AnyView(content)
    }

    func dismiss() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
        scene = nil
    }
}

