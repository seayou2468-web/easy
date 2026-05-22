import SwiftUI
import UIKit
import QuartzCore

@MainActor
final class VirtualControllerOverlayManager {
    static let shared = VirtualControllerOverlayManager()

    private final class PassThroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let hit = super.hitTest(point, with: event) else { return nil }
            // If super hit-tests only the window itself, pass through.
            // Do not drop rootViewController.view hits here because SwiftUI
            // can legitimately resolve interactive overlays through hosting root.
            return hit === self ? nil : hit
        }
    }

    private var overlayWindow: PassThroughWindow?
    private weak var scene: UIWindowScene?
    private var refreshScheduled = false
    private var lastStableFrame: CGRect = .zero

    func present(in scene: UIWindowScene, content: some View) {
        self.scene = scene
        let hosting = UIHostingController(rootView: AnyView(content))
        hosting.view.backgroundColor = .clear

        let window: PassThroughWindow
        if let existing = overlayWindow, existing.windowScene === scene {
            window = existing
            alignFrame(window: window, scene: scene)
            window.isUserInteractionEnabled = true
            window.isHidden = false
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
        lastStableFrame = .zero
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
        let keyBounds = scene.windows.first(where: { $0.isKeyWindow })?.bounds ?? .zero
        let sceneBounds = scene.coordinateSpace.bounds

        // iOS 18+ can transiently produce zero-sized keyWindow bounds during
        // scene detach/reattach. Prefer non-zero stable bounds and avoid
        // redundant frame transactions.
        var target = keyBounds
        if target.width <= 1 || target.height <= 1 {
            target = sceneBounds
        }
        if target.width <= 1 || target.height <= 1 {
            target = lastStableFrame
        }
        guard target.width > 1, target.height > 1 else { return }

        let dx = abs(window.frame.origin.x - target.origin.x)
        let dy = abs(window.frame.origin.y - target.origin.y)
        let dw = abs(window.frame.size.width - target.size.width)
        let dh = abs(window.frame.size.height - target.size.height)
        // iOS 18+ can oscillate sub-pixel values across transactions.
        // Use tolerance to prevent endless frame-update transactions.
        let epsilon: CGFloat = 0.5
        if dx > epsilon || dy > epsilon || dw > epsilon || dh > epsilon {
            window.frame = target
        }
        lastStableFrame = target
    }
}
