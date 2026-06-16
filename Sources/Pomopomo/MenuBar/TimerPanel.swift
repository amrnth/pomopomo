import AppKit
import SwiftUI
import PomopomoKit

@MainActor
final class TimerPanel: NSPanel, NSWindowDelegate {
    private weak var anchorView: NSView?
    private var outsideMonitor: Any?
    private let settingsStore: SettingsStore

    init(contentViewController: NSViewController, settingsStore: SettingsStore = .shared) {
        self.settingsStore = settingsStore
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = contentViewController
        configureTransparentContentHierarchy()
        delegate = self
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
    }

    private func configureTransparentContentHierarchy() {
        clearLayerBackground(contentView)
        clearLayerBackground(contentViewController?.view)
    }

    private func clearLayerBackground(_ view: NSView?) {
        guard let view else { return }
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.layer?.borderWidth = 0
        view.layer?.borderColor = NSColor.clear.cgColor
    }

    func show(relativeTo statusButton: NSView) {
        anchorView = statusButton
        if let saved = settingsStore.panelPosition {
            applySavedPosition(saved)
        } else {
            positionNearStatusItem()
        }
        orderFrontRegardless()
        installOutsideClickMonitor()
    }

    func repositionIfVisible() {
        guard isVisible else { return }
        if let saved = settingsStore.panelPosition {
            applySavedPosition(saved)
        }
    }

    override func close() {
        persistFrameOrigin()
        removeOutsideClickMonitor()
        super.close()
    }

    override func noResponder(for eventSelector: Selector) {
        // Non-activating panels can receive button actions without a valid key-window
        // responder chain; swallowing here avoids the macOS alert ("Funk") beep.
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown || event.type == .keyUp {
            if contentView?.performKeyEquivalent(with: event) == true {
                return
            }
            return
        }
        super.sendEvent(event)
    }

    func windowDidMove(_ notification: Notification) {
        persistFrameOrigin()
    }

    private func persistFrameOrigin() {
        let origin = frame.origin
        settingsStore.panelPosition = PanelPosition(originX: origin.x, originY: origin.y)
    }

    private func applySavedPosition(_ saved: PanelPosition) {
        let origin = NSPoint(x: saved.originX, y: saved.originY)
        let screen = screenContaining(origin: origin) ?? NSScreen.main
        setFrameOrigin(clampedOrigin(origin, panelSize: frame.size, on: screen))
    }

    private func positionNearStatusItem() {
        guard let anchorView, let anchorWindow = anchorView.window else { return }
        let buttonFrame = anchorView.convert(anchorView.bounds, to: nil)
        let screenFrame = anchorWindow.convertToScreen(buttonFrame)
        let panelSize = frame.size
        let origin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.minY - panelSize.height - 6
        )
        let screen = anchorWindow.screen ?? NSScreen.main
        setFrameOrigin(clampedOrigin(origin, panelSize: panelSize, on: screen))
    }

    private func clampedOrigin(_ origin: NSPoint, panelSize: NSSize, on screen: NSScreen?) -> NSPoint {
        guard let screen else { return origin }
        let visible = screen.visibleFrame
        var clamped = origin
        clamped.x = max(visible.minX + 8, min(clamped.x, visible.maxX - panelSize.width - 8))
        clamped.y = max(visible.minY + 8, min(clamped.y, visible.maxY - panelSize.height - 8))
        return clamped
    }

    private func screenContaining(origin: NSPoint) -> NSScreen? {
        let probe = NSPoint(x: origin.x + frame.width / 2, y: origin.y + frame.height / 2)
        return NSScreen.screens.first { $0.frame.contains(probe) }
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.handleOutsideClick()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideMonitor {
            NSEvent.removeMonitor(outsideMonitor)
            self.outsideMonitor = nil
        }
    }

    private func handleOutsideClick() {
        guard isVisible else { return }
        let mouseLocation = NSEvent.mouseLocation
        if !frame.contains(mouseLocation) {
            close()
            NotificationCenter.default.post(name: .timerPanelDidClose, object: nil)
        }
    }
}

extension Notification.Name {
    static let timerPanelDidClose = Notification.Name("TimerPanelDidClose")
}
