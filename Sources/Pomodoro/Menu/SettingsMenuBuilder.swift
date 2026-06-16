import AppKit
import PomodoroKit

@MainActor
enum SettingsMenuBuilder {
    static func makeMenu(
        engine: PomodoroEngine,
        onPomoPomoDurationChange: @escaping (Int) -> Void,
        onBreakDurationChange: @escaping (Int) -> Void,
        onAutoStartToggle: @escaping (Bool) -> Void,
        onReset: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()

        let pomoPomoMenu = NSMenu()
        for minutes in Settings.pomoPomoDurationOptions {
            let item = NSMenuItem(
                title: "\(minutes) min",
                action: #selector(SettingsMenuActions.pomoPomoDurationSelected(_:)),
                keyEquivalent: ""
            )
            item.target = SettingsMenuActions.shared
            item.representedObject = minutes
            item.state = engine.pomoPomoDurationMinutes == minutes ? .on : .off
            pomoPomoMenu.addItem(item)
        }
        let pomoPomoItem = NSMenuItem(title: "PomoPomo Duration", action: nil, keyEquivalent: "")
        pomoPomoItem.submenu = pomoPomoMenu
        menu.addItem(pomoPomoItem)

        let breakMenu = NSMenu()
        for minutes in Settings.breakDurationOptions {
            let item = NSMenuItem(
                title: "\(minutes) min",
                action: #selector(SettingsMenuActions.breakDurationSelected(_:)),
                keyEquivalent: ""
            )
            item.target = SettingsMenuActions.shared
            item.representedObject = minutes
            item.state = engine.breakDurationMinutes == minutes ? .on : .off
            breakMenu.addItem(item)
        }
        let breakItem = NSMenuItem(title: "Break Duration", action: nil, keyEquivalent: "")
        breakItem.submenu = breakMenu
        menu.addItem(breakItem)

        let autoStartItem = NSMenuItem(
            title: "Auto-start",
            action: #selector(SettingsMenuActions.autoStartToggled(_:)),
            keyEquivalent: ""
        )
        autoStartItem.target = SettingsMenuActions.shared
        autoStartItem.state = engine.autoStart ? .on : .off
        menu.addItem(autoStartItem)

        menu.addItem(.separator())

        let resetItem = NSMenuItem(
            title: "Reset",
            action: #selector(SettingsMenuActions.resetSelected(_:)),
            keyEquivalent: ""
        )
        resetItem.target = SettingsMenuActions.shared
        if let image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reset") {
            resetItem.image = image
        }
        menu.addItem(resetItem)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(SettingsMenuActions.quitSelected(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = SettingsMenuActions.shared
        menu.addItem(quitItem)

        SettingsMenuActions.shared.configure(
            onPomoPomoDurationChange: onPomoPomoDurationChange,
            onBreakDurationChange: onBreakDurationChange,
            onAutoStartToggle: onAutoStartToggle,
            onReset: onReset,
            onQuit: onQuit
        )

        return menu
    }
}

@MainActor
final class SettingsMenuActions: NSObject {
    static let shared = SettingsMenuActions()

    private var onPomoPomoDurationChange: ((Int) -> Void)?
    private var onBreakDurationChange: ((Int) -> Void)?
    private var onAutoStartToggle: ((Bool) -> Void)?
    private var onReset: (() -> Void)?
    private var onQuit: (() -> Void)?

    func configure(
        onPomoPomoDurationChange: @escaping (Int) -> Void,
        onBreakDurationChange: @escaping (Int) -> Void,
        onAutoStartToggle: @escaping (Bool) -> Void,
        onReset: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onPomoPomoDurationChange = onPomoPomoDurationChange
        self.onBreakDurationChange = onBreakDurationChange
        self.onAutoStartToggle = onAutoStartToggle
        self.onReset = onReset
        self.onQuit = onQuit
    }

    @objc func pomoPomoDurationSelected(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        onPomoPomoDurationChange?(minutes)
    }

    @objc func breakDurationSelected(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        onBreakDurationChange?(minutes)
    }

    @objc func autoStartToggled(_ sender: NSMenuItem) {
        let newValue = sender.state != .on
        sender.state = newValue ? .on : .off
        onAutoStartToggle?(newValue)
    }

    @objc func resetSelected(_ sender: NSMenuItem) {
        onReset?()
    }

    @objc func quitSelected(_ sender: NSMenuItem) {
        onQuit?()
    }
}
