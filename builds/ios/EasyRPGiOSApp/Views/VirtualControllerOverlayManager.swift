import SwiftUI
import UIKit
import QuartzCore

@MainActor
final class VirtualControllerOverlayManager {
    static let shared = VirtualControllerOverlayManager()

    final class OverlayState: ObservableObject {
        @Published var layoutStore: VirtualControllerLayoutStore?
        @Published var config: ConfigManager?
        @Published var viewport: RuntimeViewport = .zero
        @Published var gameplayFrame: CGRect = .zero
        var onDirectionInput: (String, Bool) -> Void = { _, _ in }
        var onButtonInput: (String, Bool) -> Void = { _, _ in }
        var onDismiss: (() -> Void)?
    }

    struct OverlayRootView: View {
        @ObservedObject var state: OverlayState

        var body: some View {
            Group {
                if let layoutStore = state.layoutStore, let config = state.config {
                    VirtualControllerView(
                        layoutStore: layoutStore,
                        config: config,
                        onDirectionInput: state.onDirectionInput,
                        onButtonInput: state.onButtonInput,
                        viewport: state.viewport,
                        gameplayFrame: state.gameplayFrame
                    )
                } else {
                    EmptyView()
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(true)
        }
    }

    private final class PassThroughWindow: UIWindow {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard let hit = super.hitTest(point, with: event) else { return nil }
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
                return nil
            }
            return hit
        }
    }

    private var overlayWindow: PassThroughWindow?
    private var hostingController: UIHostingController<OverlayRootView>?
    private weak var scene: UIWindowScene?
    private var refreshScheduled = false
    private var lastStableFrame: CGRect = .zero
    private let overlayState = OverlayState()

    func present(
        in scene: UIWindowScene,
        layoutStore: VirtualControllerLayoutStore,
        config: ConfigManager,
        viewport: RuntimeViewport,
        gameplayFrame: CGRect,
        onDirectionInput: @escaping (String, Bool) -> Void,
        onButtonInput: @escaping (String, Bool) -> Void
    ) {
        self.scene = scene
        overlayState.layoutStore = layoutStore
        overlayState.config = config
        overlayState.viewport = viewport
        overlayState.gameplayFrame = gameplayFrame
        overlayState.onDirectionInput = onDirectionInput
        overlayState.onButtonInput = onButtonInput

        let hosting: UIHostingController<OverlayRootView>
        if let existingHost = hostingController {
            hosting = existingHost
        } else {
            let created = UIHostingController(rootView: OverlayRootView(state: overlayState))
            created.view.backgroundColor = .clear
            created.view.isUserInteractionEnabled = true
            created.view.isOpaque = false
            hostingController = created
            hosting = created
        }

        let window: PassThroughWindow
        if let existing = overlayWindow, existing.windowScene === scene {
            window = existing
            window.windowLevel = targetOverlayWindowLevel(in: scene)
            alignFrame(window: window, scene: scene)
            window.isUserInteractionEnabled = true
            window.isHidden = false
            if let host = window.rootViewController as? UIHostingController<OverlayRootView> {
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

    func registerOnDismiss(_ action: @escaping () -> Void) { overlayState.onDismiss = action }

    func dismiss() {
        overlayState.onDismiss?()
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        hostingController = nil
        scene = nil
        lastStableFrame = .zero
        overlayState.onDirectionInput = { _, _ in }
        overlayState.onButtonInput = { _, _ in }
    }

    func schedulePostLayoutRefresh(
        layoutStore: VirtualControllerLayoutStore,
        config: ConfigManager,
        viewport: RuntimeViewport,
        gameplayFrame: CGRect,
        onDirectionInput: @escaping (String, Bool) -> Void,
        onButtonInput: @escaping (String, Bool) -> Void
    ) {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        RunLoop.main.perform { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                CATransaction.flush()
                self.refreshScheduled = false
                guard let scene = self.scene ?? UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) else { return }
                self.present(in: scene, layoutStore: layoutStore, config: config, viewport: viewport, gameplayFrame: gameplayFrame, onDirectionInput: onDirectionInput, onButtonInput: onButtonInput)
            }
        }
    }

    private func alignFrame(window: UIWindow, scene: UIWindowScene) {
        let referenceBounds = bestReferenceBounds(in: scene)
        let sceneBounds = scene.coordinateSpace.bounds
        var target = referenceBounds
        if target.width <= 1 || target.height <= 1 { target = sceneBounds }
        if target.width <= 1 || target.height <= 1 { target = lastStableFrame }
        if target.width <= 1 || target.height <= 1 { target = UIScreen.main.bounds }
        guard target.width > 1, target.height > 1 else { return }
        let dx = abs(window.frame.origin.x - target.origin.x)
        let dy = abs(window.frame.origin.y - target.origin.y)
        let dw = abs(window.frame.size.width - target.size.width)
        let dh = abs(window.frame.size.height - target.size.height)
        let epsilon: CGFloat = 0.5
        if dx > epsilon || dy > epsilon || dw > epsilon || dh > epsilon {
            window.frame = target
            window.bounds = CGRect(origin: .zero, size: target.size)
            window.center = CGPoint(x: target.midX, y: target.midY)
        }
        lastStableFrame = target
    }

    private func bestReferenceBounds(in scene: UIWindowScene) -> CGRect {
        let candidates = scene.windows.filter { window in
            window !== overlayWindow && !window.isHidden && window.alpha > 0.01
        }
        let best = candidates.max { lhs, rhs in
            lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
        }
        return best?.bounds ?? scene.windows.first(where: { $0.isKeyWindow })?.bounds ?? .zero
    }

    private func targetOverlayWindowLevel(in scene: UIWindowScene) -> UIWindow.Level {
        let highestAppLevel = scene.windows
            .filter { $0 !== overlayWindow }
            .map(\.windowLevel.rawValue)
            .max() ?? UIWindow.Level.normal.rawValue
        let upperBound = UIWindow.Level.alert.rawValue - 1
        let level = min(highestAppLevel + 1, upperBound)
        return UIWindow.Level(rawValue: level)
    }
}
