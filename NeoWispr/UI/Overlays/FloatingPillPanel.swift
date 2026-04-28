import AppKit
import SwiftUI

/// Floating pill overlay at the bottom of the screen.
/// Shows recording status, waveform animation, and controls.
/// Non-activating — doesn't steal focus from the active app.
///
/// Uses NSVisualEffectView with cornerRadius to avoid black corners.
/// The glass/blur effect comes from AppKit's NSVisualEffectView (behindWindow),
/// not from SwiftUI .material modifiers — this gives true desktop-through blur.
@MainActor
final class FloatingPillPanel {

    private var panel: NSPanel?
    private weak var recordingController: RecordingController?

    private let pillWidth: CGFloat = 280
    private let pillHeight: CGFloat = 56
    private let cornerRadius: CGFloat = 28  // pillHeight / 2 = capsule

    init(recordingController: RecordingController) {
        self.recordingController = recordingController
    }

    func show() {
        guard panel == nil, let controller = recordingController else { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .statusBar
        p.hasShadow = false  // We draw our own shadow via SwiftUI
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false

        // Container view — fully transparent
        let container = NSView(frame: NSRect(x: 0, y: 0, width: pillWidth, height: pillHeight))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear

        // NSVisualEffectView — the REAL glass/blur, with cornerRadius to avoid black corners
        let visualEffect = NSVisualEffectView(frame: container.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow  // Strong blur, like Control Center
        visualEffect.blendingMode = .behindWindow  // Desktop shines through
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = cornerRadius
        visualEffect.layer?.masksToBounds = true
        // Subtle top-edge highlight like Apple's glass tiles
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        container.addSubview(visualEffect)

        // SwiftUI content on top of the glass
        let content = FloatingPillView(controller: controller) { [weak self] in
            self?.hide()
        }
        let hostingView = NSHostingView(rootView: content
            .frame(width: pillWidth, height: pillHeight)
        )
        hostingView.frame = container.bounds
        hostingView.autoresizingMask = [.width, .height]
        // CRITICAL: Make the hosting view's background layer transparent
        // so the NSVisualEffectView glass shows through
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        container.addSubview(hostingView)

        // Shadow layer on the container (not the window)
        container.shadow = NSShadow()
        container.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        container.layer?.shadowOffset = CGSize(width: 0, height: -6)
        container.layer?.shadowRadius = 20
        container.layer?.shadowOpacity = 1.0

        p.contentView = container

        // Position: unten mittig, 80px vom unteren Rand
        if let screen = NSScreen.main {
            let x = (screen.frame.width - pillWidth) / 2
            let y: CGFloat = 80
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }

        p.orderFrontRegardless()
        panel = p
    }

    func hide() {
        // orderOut statt close() — vermeidet die NSWindowTransformAnimation
        // die bei schnellem hide→show→hide racy released wurde (Crash in
        // CA::Context::commit_transaction → _NSWindowTransformAnimation dealloc).
        panel?.orderOut(nil)
        panel = nil
    }

    var isVisible: Bool {
        panel != nil
    }
}
