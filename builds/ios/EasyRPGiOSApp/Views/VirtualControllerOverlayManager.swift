import SwiftUI
import UIKit
import QuartzCore

@MainActor
final class VirtualControllerOverlayManager {
    static let shared = VirtualControllerOverlayManager()

    private final class PassThroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let hit = super.hitTest(point, with: event) else { return nil }
            // iOS 18+/26 can intermittently return UIWindow(self) for the
            // first touch frame even when SwiftUI gestures are attached in
            // the hosting hierarchy. If we pass-through immediately, the
            // gesture begin can be dropped and SDL window takes ownership.
            if hit === self {
                guard let rootView = rootViewController?.view,
                      rootView.isUserInteractionEnabled,
                      !rootView.isHidden,
                      rootView.alpha > 0.01 else {
                    return nil
                }

                let local = rootView.convert(point, from: self)
                if let resolved = rootView.hitTest(local, with: event), resolved !== rootView {
                    return resolved
                }

                // Keep gesture start inside hosting tree instead of dropping it.
                return rootView
            }

            // Keep root-view hits interactive. SwiftUI frequently resolves
            // gesture/touch handling through the hosting root, and forcing
            // pass-through here can make the virtual controller visible but
            // unresponsive.
            return hit
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
        hosting.view.isUserInteractionEnabled = true
        hosting.view.isOpaque = false

        let window: PassThroughWindow
        if let existing = overlayWindow, existing.windowScene === scene {
            window = existing
            window.windowLevel = targetOverlayWindowLevel(in: scene)
            alignFrame(window: window, scene: scene)
            window.isUserInteractionEnabled = true
            window.isHidden = false
            if let host = window.rootViewController as? UIHostingController<AnyView> {
                host.rootView = AnyView(content)
                host.view.isUserInteractionEnabled = true
                host.view.isOpaque = false
            } else {
                window.rootViewController = hosting
            }
        } else {
            window = PassThroughWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.rootViewController = hosting
            window.windowLevel = targetOverlayWindowLevel(in: scene)
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
        let referenceBounds = bestReferenceBounds(in: scene)
        let sceneBounds = scene.coordinateSpace.bounds

        // iOS 18+ can transiently produce zero-sized keyWindow bounds during
        // scene detach/reattach. Prefer non-zero stable bounds and avoid
        // redundant frame transactions.
        var target = referenceBounds
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
            window.bounds = CGRect(origin: .zero, size: target.size)
            window.center = CGPoint(x: target.midX, y: target.midY)
        }
        if window.screen !== scene.screen {
            window.screen = scene.screen
        }
        lastStableFrame = target
    }

    private func bestReferenceBounds(in scene: UIWindowScene) -> CGRect {
        // Prefer the largest visible non-overlay window to avoid keyWindow
        // instability when SDL/internal windows temporarily steal key focus.
        let candidates = scene.windows.filter { window in
            window !== overlayWindow && !window.isHidden && window.alpha > 0.01
        }
        let best = candidates.max { lhs, rhs in
            lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
        }
        return best?.bounds ?? scene.windows.first(where: { $0.isKeyWindow })?.bounds ?? .zero
    }

    private func targetOverlayWindowLevel(in scene: UIWindowScene) -> UIWindow.Level {
        // Keep overlay above app windows (including SDL dedicated windows)
        // while staying below system-critical windows.
        let highestAppLevel = scene.windows
            .filter { $0 !== overlayWindow }
            .map(\.windowLevel.rawValue)
            .max() ?? UIWindow.Level.normal.rawValue
        let upperBound = UIWindow.Level.alert.rawValue - 1
        let level = min(highestAppLevel + 1, upperBound)
        return UIWindow.Level(rawValue: level)
    }
}
