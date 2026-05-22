import SwiftUI
import UIKit
import QuartzCore

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
    private var refreshScheduled = false

    func present(in scene: UIWindowScene, content: some View) {
        self.scene = scene
        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear

        let window: PassThroughWindow
        if let existing = overlayWindow, existing.windowScene === scene {
            window = existing
            alignFrame(window: window, scene: scene)
            if let host = window.rootViewController as? UIHostingController<AnyView> {
                host.rootView = AnyView(content)
            } else {
                window.rootViewController = hosting
            }
        } else {
            window = PassThroughWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.rootViewController = hosting
            // Keep overlay near top but below system-critical windows.
            // Avoid relying on deprecated/weakly-guaranteed statusBar offsets.
            window.windowLevel = UIWindow.Level.alert - 1
            alignFrame(window: window, scene: scene)
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

    func schedulePostLayoutRefresh(content: some View) {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        RunLoop.main.perform {
            CATransaction.flush()
            self.refreshScheduled = false
            guard let scene = self.scene ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else { return }
            self.present(in: scene, content: content)
        }
    }

    private func alignFrame(window: UIWindow, scene: UIWindowScene) {
        if let key = scene.windows.first(where: { $0.isKeyWindow }) {
            window.frame = key.bounds
        } else {
            window.frame = scene.coordinateSpace.bounds
        }
    }
}
