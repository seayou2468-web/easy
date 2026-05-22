import SwiftUI

struct VirtualControllerView: View {
    @ObservedObject var layoutStore: VirtualControllerLayoutStore
    @ObservedObject var config: ConfigManager
    let onDirectionInput: (String, Bool) -> Void
    let onButtonInput: (String, Bool) -> Void
    let viewport: RuntimeViewport
    let gameplayFrame: CGRect

    @State private var pressedButtons: Set<String> = []
    @State private var activeDirection: String?
    @State private var rootGlobalFrame: CGRect = .zero

    private var effectiveOpacity: Double {
        // Keep controller visible even when a broken/legacy value is loaded.
        max(0.0, min(1.0, Double(255 - config.layoutTransparency) / 255.0))
    }

    var body: some View {
        GeometryReader { geo in
            // Android parity: controls are placed in the full parent layout,
            // while SDL surface itself is resized separately.
            let geometryWidth = geo.size.width
            let geometryHeight = geo.size.height
            // Match Android orientation-switch behavior by using the shared
            // runtime viewport orientation discriminator.
            let isLandscape = IOSDisplayCoordinator.isLandscape(viewport: viewport)
            let buttons = layoutStore.buttons(isLandscape: isLandscape)
            let directional = buttons.filter { ["up", "down", "left", "right"].contains($0.id) }
            let others = buttons.filter { !["up", "down", "left", "right"].contains($0.id) }

            ZStack {
                if !directional.isEmpty {
                    runtimeDPadView(directional, geometryWidth: geometryWidth, geometryHeight: geometryHeight)
                }
                ForEach(others, id: \.instanceId) { button in
                    runtimeButtonView(button, geometryWidth: geometryWidth, geometryHeight: geometryHeight)
                }
            }
            .allowsHitTesting(true)
            .contentShape(Rectangle())
             .frame(width: geometryWidth, height: geometryHeight, alignment: .topLeading)
            .position(x: geometryWidth / 2.0, y: geometryHeight / 2.0)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { rootGlobalFrame = proxy.frame(in: .global) }
                        .onChange(of: proxy.frame(in: .global)) { _, newFrame in
                            rootGlobalFrame = newFrame
                        }
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
        .contentShape(Rectangle())
                .onDisappear {
            releaseAllVirtualInputs()
        }
        // Do not add runtime-only horizontal offset: editor and runtime must share
        // the same coordinate space for position parity.
    }

    @ViewBuilder
    private func runtimeDPadView(_ buttons: [VirtualButtonLayout], geometryWidth: CGFloat, geometryHeight: CGFloat) -> some View {
        let centerX = buttons.map(\.x).reduce(0, +) / CGFloat(buttons.count)
        let centerY = buttons.map(\.y).reduce(0, +) / CGFloat(buttons.count)
        let refSize = buttons.map { sizeFor($0) }.max() ?? 64
        let dpadSize = refSize * 2.2

        DPadCrossView(opacity: effectiveOpacity, size: dpadSize)
            .allowsHitTesting(true)
            .contentShape(Rectangle())
            .position(x: centerX * geometryWidth, y: centerY * geometryHeight)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let dpadFrame = CGRect(
                            x: rootGlobalFrame.minX + centerX * geometryWidth - dpadSize / 2,
                            y: rootGlobalFrame.minY + centerY * geometryHeight - dpadSize / 2,
                            width: dpadSize,
                            height: dpadSize
                        )
                        let localPoint = CGPoint(x: value.location.x - dpadFrame.minX, y: value.location.y - dpadFrame.minY)
                        let direction = resolveDPadDirection(from: localPoint, size: dpadSize)
                        if direction != activeDirection {
                            if let old = activeDirection { onDirectionInput(old, false) }
                            activeDirection = direction
                            if let direction {
                                onDirectionInput(direction, true)
                                if config.enableVibration {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                    .onEnded { _ in
                        if let old = activeDirection { onDirectionInput(old, false) }
                        activeDirection = nil
                    }
                , including: .all
            )
            .contentShape(Rectangle())
    }

    private func resolveDPadDirection(from point: CGPoint, size: CGFloat) -> String? {
        // Android parity (VirtualCross#setBounds):
        // iconSize_33 = int(realSize * 0.33), padding = int(realSize * 0.20)
        let iconSize33 = Int(size * 0.33)
        let padding = Int(size * 0.20)
        let realSize = Int(size)
        let px = Int(point.x)
        let py = Int(point.y)

        let leftRect = CGRect(
            x: CGFloat(-padding),
            y: CGFloat(iconSize33),
            width: CGFloat(realSize - 2 * iconSize33 + padding),
            height: CGFloat(realSize - 2 * iconSize33 + padding)
        )
        let rightRect = CGRect(
            x: CGFloat(2 * iconSize33),
            y: CGFloat(iconSize33),
            width: CGFloat(realSize - 2 * iconSize33 + padding),
            height: CGFloat(realSize - 2 * iconSize33 + padding)
        )
        let upRect = CGRect(
            x: CGFloat(iconSize33),
            y: CGFloat(-padding),
            width: CGFloat(realSize - 2 * iconSize33),
            height: CGFloat(realSize - 2 * iconSize33)
        )
        let downRect = CGRect(
            x: CGFloat(iconSize33),
            y: CGFloat(2 * iconSize33),
            width: CGFloat(realSize - 2 * iconSize33),
            height: CGFloat(realSize - 2 * iconSize33 + padding)
        )

        let p = CGPoint(x: px, y: py)
        if leftRect.contains(p) { return "left" }
        if rightRect.contains(p) { return "right" }
        if upRect.contains(p) { return "up" }
        if downRect.contains(p) { return "down" }
        return nil
    }

    private func sizeFor(_ button: VirtualButtonLayout) -> CGFloat {
        Self.visualSize(for: button, config: config, viewport: viewport)
    }

    static func visualSize(for button: VirtualButtonLayout, config: ConfigManager, viewport: RuntimeViewport) -> CGFloat {
        let baseSize: CGSize
        if viewport.size == .zero {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) {
                baseSize = scene.coordinateSpace.bounds.size
            } else {
                baseSize = UIScreen.main.bounds.size
            }
        } else {
            baseSize = viewport.size
        }
        let screenMin = min(baseSize.width, baseSize.height)
        let androidParityBase = max(44, min(104, screenMin * 0.135))
        let manualBase = max(32, min(CGFloat(config.layoutSize) * 0.35, 96))
        let base: CGFloat = config.ignoreLayoutSize ? manualBase : androidParityBase
        return max(28, min(160, base * (CGFloat(button.size) / 100.0)))
    }

    private func sendPress(for buttonId: String, isPressed: Bool) {
        if ["up", "down", "left", "right"].contains(buttonId) {
            onDirectionInput(buttonId, isPressed)
        } else {
            onButtonInput(buttonId, isPressed)
        }
    }

    @ViewBuilder
    private func runtimeButtonView(_ button: VirtualButtonLayout, geometryWidth: CGFloat, geometryHeight: CGFloat) -> some View {
        let buttonSize = sizeFor(button)
        VirtualButtonView(
            button: button,
            isPressed: pressedButtons.contains(button.instanceId),
            opacity: effectiveOpacity,
            size: buttonSize,
            config: config
        )
        .allowsHitTesting(true)
        .contentShape(Rectangle())
        .position(
            x: button.x * geometryWidth,
            y: button.y * geometryHeight
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let frame = CGRect(
                        x: rootGlobalFrame.minX + button.x * geometryWidth - buttonSize / 2,
                        y: rootGlobalFrame.minY + button.y * geometryHeight - buttonSize / 2,
                        width: buttonSize,
                        height: buttonSize
                    )
                    handleDragChanged(value: value, button: button, buttonFrame: frame)
                }
                .onEnded { _ in
                    handleDragEnded(button: button)
                }
            , including: .all
        )
    }

    private func handleDragChanged(value: DragGesture.Value, button: VirtualButtonLayout, buttonFrame: CGRect) {
        // Use global coordinate space for deterministic hit-testing across .position transforms.
        let isInside = buttonFrame.contains(value.location)

        if isInside && !pressedButtons.contains(button.instanceId) {
            pressedButtons.insert(button.instanceId)
            sendPress(for: button.id, isPressed: true)
            if config.enableVibration {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } else if !isInside && pressedButtons.contains(button.instanceId) {
            pressedButtons.remove(button.instanceId)
            sendPress(for: button.id, isPressed: false)
        }
    }

    private func handleDragEnded(button: VirtualButtonLayout) {
        pressedButtons.remove(button.instanceId)
        sendPress(for: button.id, isPressed: false)
    }

    private func releaseAllVirtualInputs() {
        if let dir = activeDirection {
            onDirectionInput(dir, false)
            activeDirection = nil
        }

        if !pressedButtons.isEmpty {
            let buttons = layoutStore.buttons(isLandscape: IOSDisplayCoordinator.isLandscape(viewport: viewport))
            let pressedIds = Set(pressedButtons)
            for button in buttons where pressedIds.contains(button.instanceId) {
                sendPress(for: button.id, isPressed: false)
            }
            pressedButtons.removeAll()
        }
    }
}

private struct DPadCrossView: View {
    let opacity: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            AndroidDPadShape()
                .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
        }
        .frame(width: size, height: size)
    }

}

private struct AndroidDPadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let oneThird = floor(s * 0.33)
        let twoThird = oneThird * 2
        let border: CGFloat = 5
        let minX = rect.minX + border
        let minY = rect.minY + border
        let maxX = rect.maxX - border
        let maxY = rect.maxY - border

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + oneThird, y: minY))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: minY))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: rect.minY + oneThird))
        p.addLine(to: CGPoint(x: maxX, y: rect.minY + oneThird))
        p.addLine(to: CGPoint(x: maxX, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: rect.minX + twoThird, y: maxY))
        p.addLine(to: CGPoint(x: rect.minX + oneThird, y: maxY))
        p.addLine(to: CGPoint(x: rect.minX + oneThird, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: minX, y: rect.minY + twoThird))
        p.addLine(to: CGPoint(x: minX, y: rect.minY + oneThird))
        p.addLine(to: CGPoint(x: rect.minX + oneThird, y: rect.minY + oneThird))
        p.closeSubpath()
        return p
    }
}

struct VirtualButtonView: View {
    let button: VirtualButtonLayout
    let isPressed: Bool
    let opacity: Double
    let size: CGFloat
    @ObservedObject var config: ConfigManager

    var body: some View {
        ZStack {
            AndroidStrokeText(text: displayTitle(), size: size * (25.0 / 60.0), opacity: opacity)
        }
        .frame(width: size, height: size)
        .background(
            Group {
                if button.id == "menu" {
                    MenuGlyphButtonShape()
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
                } else if button.id == "fast_forward_a" {
                    AndroidInsetRectShape()
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
                } else {
                    AndroidInsetCircleShape()
                        .stroke(Color.white.opacity(opacity), style: StrokeStyle(lineWidth: 3, lineCap: .butt, lineJoin: .miter, miterLimit: 10))
                }
            }
        )
    }

    private func displayTitle() -> String {
        if config.showABasZX {
            if button.id == "z" || button.id == "decision" { return "Z" }
            if button.id == "x" || button.id == "cancel" { return "X" }
        }
        if button.id == "fast_forward_a" && config.fastForwardMode == 1 {
            return "»"
        }
        if button.id == "debug_menu" { return "M" }
        if button.id == "debug_through" { return "T" }
        return button.title
    }
}


private struct AndroidStrokeText: UIViewRepresentable {
    let text: String
    let size: CGFloat
    let opacity: Double

    func makeUIView(context: Context) -> AndroidStrokeTextView {
        AndroidStrokeTextView()
    }

    func updateUIView(_ view: AndroidStrokeTextView, context: Context) {
        view.text = text
        view.fontSize = size
        view.alphaColor = max(0.0, min(1.0, opacity))
        view.setNeedsDisplay()
    }
}

private final class AndroidStrokeTextView: UIView {
    var text: String = ""
    var fontSize: CGFloat = 16
    var alphaColor: Double = 1.0

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), !text.isEmpty else { return }

        let color = UIColor.white.withAlphaComponent(alphaColor)
        let font = UIFont.boldSystemFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let ns = text as NSString
        var bounds = ns.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading],
                                     attributes: attrs,
                                     context: nil)

        // Android centers text manually and uses stroke paint only.
        let x = rect.midX - bounds.width / 2.0
        let y = rect.midY - bounds.height / 2.0

        ctx.setLineWidth(3.0)
        ctx.setLineJoin(.round)
        ctx.setTextDrawingMode(.stroke)
        color.setStroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        bounds.origin = CGPoint(x: x, y: y)
        ns.draw(in: bounds, withAttributes: [
            .font: font,
            .foregroundColor: UIColor.clear,
            .strokeColor: color,
            .strokeWidth: 3.0,
            .paragraphStyle: paragraph
        ])
    }
}

private struct AndroidInsetCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 5
        let r = rect.insetBy(dx: inset, dy: inset)
        return Path(ellipseIn: r)
    }
}

private struct AndroidInsetRectShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 5
        let r = rect.insetBy(dx: inset, dy: inset)
        var p = Path()
        p.addRect(r)
        return p
    }
}

private struct MenuGlyphButtonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let h = rect.height / 7
        for i in 0..<7 where i % 2 == 1 {
            let y = CGFloat(i) * h
            p.addRect(CGRect(x: rect.width / 6, y: y, width: rect.width * 4 / 6, height: h))
        }
        return p
    }
}
