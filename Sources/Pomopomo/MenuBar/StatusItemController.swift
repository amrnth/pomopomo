import AppKit
import SwiftUI
import PomopomoKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let engine: PomodoroEngine
    private weak var coordinator: AppCoordinator?
    private var panel: TimerPanel?
    private var hostingController: NSHostingController<TimerView>?

    init(engine: PomodoroEngine, coordinator: AppCoordinator) {
        self.engine = engine
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        updateTitle()
    }

    func showPanelAtLaunch() {
        togglePanel(forceShow: true)
    }

    func showPanelForBreakStart() {
        togglePanel(forceShow: true)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp])
        updateTitle()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        togglePanel(forceShow: false)
    }

    func updateTitle() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = StatusItemBadgeRenderer.image(for: engine.statusItemTitle)
        button.imagePosition = .imageOnly
    }

    private func togglePanel(forceShow: Bool) {
        if panel?.isVisible == true && !forceShow {
            panel?.close()
            panel = nil
            return
        }

        guard let button = statusItem.button else { return }

        if panel == nil {
            let view = TimerView(
                engine: engine,
                onClose: { [weak self] in
                    self?.panel?.close()
                    self?.panel = nil
                },
                onMore: { [weak self] anchor in
                    self?.coordinator?.showSettingsMenu(from: anchor)
                },
                onTogglePlayPause: { [weak self] in
                    self?.coordinator?.togglePlayPause()
                },
                onSkip: { [weak self] in
                    self?.coordinator?.skipPhase()
                }
            )
            let hosting = NSHostingController(rootView: view)
            hostingController = hosting
            panel = TimerPanel(contentViewController: hosting)
        }

        panel?.show(relativeTo: button)
        coordinator?.logPanelOpened()
    }

    func refreshPanelPosition() {
        panel?.repositionIfVisible()
    }
}
