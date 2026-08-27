import Cocoa
import SwiftUI

class AlertWindowController: NSWindowController {

    static var shared: AlertWindowController?

    var currentScreenshotURL: URL? = nil
    var isUserTyping: Bool = false
    private var disregardTimer: Timer?

    static func showWindow() {
        let s = AppSettings.shared
        
        let screenshot = StorageManager.shared.captureScreenshot()

        if shared == nil {
            let panel = AlertPanel(
                contentRect: NSRect(x: 0, y: 0, width: s.alertWidth, height: s.alertHeight),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            shared = AlertWindowController(window: panel)
        }

        guard let window = shared?.window else { return }
        shared?.currentScreenshotURL = screenshot

        // Resize to current settings on every show
        var frame = window.frame
        frame.size = CGSize(width: s.alertWidth, height: s.alertHeight)
        window.setFrame(frame, display: false)

        let alertView = AlertView(
            onClose: { shared?.closeWindow() },
            onSkip:  { shared?.closeWindow(reason: .skipped) }
        )
        window.contentView = NSHostingView(rootView: alertView)

        // Position
        if let screen = NSScreen.main {
            let r   = screen.visibleFrame
            let w   = s.alertWidth
            let h   = s.alertHeight
            let pad = s.alertEdgePadding

            let origin: NSPoint
            switch s.alertPosition {
            case .bottomRight: origin = NSPoint(x: r.maxX - w - pad, y: r.minY + pad)
            case .bottomLeft:  origin = NSPoint(x: r.minX + pad,     y: r.minY + pad)
            case .topRight:    origin = NSPoint(x: r.maxX - w - pad, y: r.maxY - h - pad)
            case .topLeft:     origin = NSPoint(x: r.minX + pad,     y: r.maxY - h - pad)
            case .center:      origin = NSPoint(x: r.midX - w / 2,   y: r.midY - h / 2)
            }
            window.setFrameOrigin(origin)
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        shared?.startDisregardTimer()
    }

    private func startDisregardTimer() {
        disregardTimer?.invalidate()
        let s = AppSettings.shared
        guard s.autoDismissEnabled else { return }

        disregardTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(s.autoDismissSeconds),
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            if !self.isUserTyping {
                self.closeWindow(reason: .ignored)
            } else {
                self.startDisregardTimer()
            }
        }
    }

    enum CloseReason { case submitted, skipped, ignored }

    func closeWindow(reason: CloseReason = .submitted) {
        disregardTimer?.invalidate()
        disregardTimer = nil
        window?.orderOut(nil)

        switch reason {
        case .submitted:         TimerManager.shared.resetTimer(disregarded: false)
        case .skipped, .ignored: TimerManager.shared.resetTimer(disregarded: true)
        }

        AlertWindowController.shared = nil
    }
}

class AlertPanel: NSPanel {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}
