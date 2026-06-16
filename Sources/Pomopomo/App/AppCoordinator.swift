import AppKit
import PomopomoKit

@MainActor
final class AppCoordinator: NSObject, PomodoroEngineDelegate {
    let engine: PomodoroEngine
    let logger: ActivityLogger
    private let soundPlayer: SoundPlayer
    private var statusItemController: StatusItemController?

    init(
        engine: PomodoroEngine = PomodoroEngine(),
        logger: ActivityLogger = ActivityLogger(),
        soundPlayer: SoundPlayer = .shared
    ) {
        self.engine = engine
        self.logger = logger
        self.soundPlayer = soundPlayer
        super.init()
        engine.delegate = self
    }

    func start() {
        LaunchAtLogin.register()
        logger.log(.appLaunched)

        statusItemController = StatusItemController(engine: engine, coordinator: self)
        statusItemController?.showPanelAtLaunch()
    }

    func terminate() {
        logger.log(.appQuit)
    }

    func logPanelOpened() {
        logger.log(.panelOpened)
    }

    func togglePlayPause() {
        let phase = engine.phase
        let state = engine.state

        switch state {
        case .idle, .completed:
            engine.togglePlayPause()
            if phase == .pomoPomo {
                logger.log(.pomoPomoStarted(number: engine.currentPomodoroNumber, durationMinutes: engine.pomoPomoDurationMinutes))
            } else {
                logger.log(.breakStarted)
            }
        case .running:
            engine.togglePlayPause()
            if phase == .pomoPomo {
                logger.log(.pomoPomoPaused)
            }
        case .paused:
            engine.togglePlayPause()
            if phase == .pomoPomo {
                logger.log(.pomoPomoResumed)
            }
        }
    }

    func skipPhase() {
        let phase = engine.phase
        engine.skip()
        switch phase {
        case .pomoPomo:
            logger.log(.pomoPomoSkipped)
        case .break:
            logger.log(.breakSkipped)
        }
    }

    func showSettingsMenu(from view: NSView) {
        let menu = SettingsMenuBuilder.makeMenu(
            engine: engine,
            onPomoPomoDurationChange: { [weak self] minutes in
                self?.engine.setPomoPomoDuration(minutes: minutes)
                self?.logger.log(.pomoPomoDurationChanged(minutes: minutes))
            },
            onBreakDurationChange: { [weak self] minutes in
                self?.engine.setBreakDuration(minutes: minutes)
                self?.logger.log(.breakDurationChanged(minutes: minutes))
            },
            onAutoStartToggle: { [weak self] enabled in
                self?.engine.setAutoStart(enabled)
                self?.logger.log(.autoStartToggled(enabled: enabled))
            },
            onReset: { [weak self] in
                self?.engine.reset()
                self?.logger.log(.timerReset)
            },
            onQuit: { [weak self] in
                self?.terminate()
                NSApp.terminate(nil)
            }
        )
        let location = NSPoint(x: 0, y: view.bounds.height)
        menu.popUp(positioning: nil, at: location, in: view)
    }

    // MARK: - PomodoroEngineDelegate

    func engineDidUpdate(_ engine: PomodoroEngine) {
        statusItemController?.updateTitle()
    }

    func engine(_ engine: PomodoroEngine, phaseDidBeginRunning phase: PomodoroPhase) {
        switch phase {
        case .pomoPomo:
            soundPlayer.playPomoPomoStarted()
        case .break:
            soundPlayer.playBreakStarted()
        }
    }

    func engine(_ engine: PomodoroEngine, didTransitionFrom oldPhase: PomodoroPhase?, to newPhase: PomodoroPhase, skipped: Bool) {
        guard !skipped else { return }

        switch (oldPhase, newPhase) {
        case (.pomoPomo, .break):
            soundPlayer.playPomoPomoEnded()
            if engine.state == .running || engine.autoStart {
                logger.log(.breakStarted)
            }
        case (.break, .pomoPomo):
            soundPlayer.playBreakEnded()
            if engine.state == .running {
                logger.log(.pomoPomoStarted(number: engine.currentPomodoroNumber, durationMinutes: engine.pomoPomoDurationMinutes))
            } else {
                logger.log(.breakCompleted)
                if engine.autoStart {
                    logger.log(.pomoPomoStarted(number: engine.currentPomodoroNumber, durationMinutes: engine.pomoPomoDurationMinutes))
                }
            }
        default:
            break
        }
    }

    func engine(_ engine: PomodoroEngine, didCompletePomodoro number: Int) {
        logger.log(.pomoPomoCompleted(durationMinutes: engine.pomoPomoDurationMinutes))
    }
}
