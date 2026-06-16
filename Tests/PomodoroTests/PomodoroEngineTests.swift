import Foundation
import Testing
@testable import PomodoroKit

@MainActor
private final class RecordingEngineDelegate: PomodoroEngineDelegate {
    private(set) var phaseDidBeginRunning: [PomodoroPhase] = []
    private(set) var transitions: [(PomodoroPhase?, PomodoroPhase, Bool)] = []

    func clearPhaseDidBeginRunning() {
        phaseDidBeginRunning.removeAll()
    }

    func engineDidUpdate(_ engine: PomodoroEngine) {}

    func engine(_ engine: PomodoroEngine, phaseDidBeginRunning phase: PomodoroPhase) {
        phaseDidBeginRunning.append(phase)
    }

    func engine(_ engine: PomodoroEngine, didTransitionFrom oldPhase: PomodoroPhase?, to newPhase: PomodoroPhase, skipped: Bool) {
        transitions.append((oldPhase, newPhase, skipped))
    }

    func engine(_ engine: PomodoroEngine, didCompletePomodoro number: Int) {}
}

@MainActor
struct PomodoroEngineTests {
    private func makeEngine(
        pomoPomoMinutes: Int = 25,
        breakMinutes: Int = 5,
        autoStart: Bool = false,
        completed: Int = 0
    ) -> (PomodoroEngine, UserDefaults, TestClock) {
        let suiteName = "PomodoroEngineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(pomoPomoMinutes, forKey: "pomoPomoDurationMinutes")
        defaults.set(breakMinutes, forKey: "breakDurationMinutes")
        defaults.set(autoStart, forKey: "autoStart")
        defaults.set(completed, forKey: "completedPomodorosInCycle")

        let store = SettingsStore(defaults: defaults)
        let clock = TestClock()
        let engine = PomodoroEngine(settingsStore: store, clock: clock)
        return (engine, defaults, clock)
    }

    @Test func idleStartsWithFullPomoPomoDuration() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25)
        #expect(engine.state == .idle)
        #expect(engine.phase == .pomoPomo)
        #expect(engine.remainingSeconds == 25 * 60)
        #expect(engine.statusItemTitle == "25:00")
    }

    @Test func startPauseResumeCycle() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 1)
        engine.start()
        #expect(engine.state == .running)

        engine.pause()
        #expect(engine.state == .paused)

        engine.resume()
        #expect(engine.state == .running)
    }

    @Test func skipPomoPomoWhileRunningMovesToBreakRunning() async {
        let (engine, defaults, _) = makeEngine(pomoPomoMinutes: 25, breakMinutes: 5, autoStart: false)
        engine.start()
        engine.skip()

        #expect(engine.phase == .break)
        #expect(engine.state == .running)
        #expect(engine.remainingSeconds == 5 * 60)
        #expect(engine.totalSeconds == 5 * 60)
        #expect(engine.statusItemTitle == "05:00")
        #expect(engine.completedPomodorosInCycle == 1)
        #expect(engine.displayCompletedPomodorosInCycle == 1)
        #expect(defaults.integer(forKey: "completedPomodorosInCycle") == 1)
    }

    @Test func skipBreakWhileRunningMovesToPomoPomoRunning() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25, breakMinutes: 5, autoStart: false, completed: 1)
        engine.reloadSettings()
        engine.test_setPhase(.break)
        engine.test_setState(.running)
        engine.test_setRemainingSeconds(120)
        engine.skip()

        #expect(engine.phase == .pomoPomo)
        #expect(engine.state == .running)
        #expect(engine.remainingSeconds == 25 * 60)
        #expect(engine.totalSeconds == 25 * 60)
        #expect(engine.statusItemTitle == "25:00")
        #expect(engine.activePomodoroIndexInCycle == 1)
        #expect(engine.currentPomodoroNumber == 2)
    }

    @Test func skipWhilePausedAdvancesCycleAndPhase() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25, autoStart: false)
        engine.start()
        engine.pause()
        engine.skip()

        #expect(engine.phase == .break)
        #expect(engine.state == .idle)
        #expect(engine.completedPomodorosInCycle == 1)
        #expect(engine.activePomodoroIndexInCycle == nil)
    }

    @Test func skipWhileIdleAdvancesToBreak() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25, autoStart: false)
        engine.skip()

        #expect(engine.phase == .break)
        #expect(engine.state == .idle)
        #expect(engine.completedPomodorosInCycle == 1)
    }

    @Test func cycleActiveIndexAdvancesAcrossPomoBreakTransitions() async {
        let (engine, _, clock) = makeEngine(pomoPomoMinutes: 1, breakMinutes: 1, autoStart: false)

        #expect(engine.activePomodoroIndexInCycle == 0)
        #expect(engine.displayCompletedPomodorosInCycle == 0)

        engine.start()
        clock.advance(by: 60)
        engine.tick()

        #expect(engine.phase == .break)
        #expect(engine.completedPomodorosInCycle == 1)
        #expect(engine.displayCompletedPomodorosInCycle == 1)
        #expect(engine.activePomodoroIndexInCycle == nil)

        engine.start()
        clock.advance(by: 60)
        engine.tick()

        #expect(engine.phase == .pomoPomo)
        #expect(engine.completedPomodorosInCycle == 1)
        #expect(engine.activePomodoroIndexInCycle == 1)
        #expect(engine.displayCompletedPomodorosInCycle == 1)
        #expect(engine.currentPomodoroNumber == 2)
    }

    @Test func cycleActiveIndexAdvancesWhenSkippingPhases() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25, autoStart: false)

        engine.skip()
        #expect(engine.phase == .break)
        #expect(engine.completedPomodorosInCycle == 1)

        engine.skip()
        #expect(engine.phase == .pomoPomo)
        #expect(engine.activePomodoroIndexInCycle == 1)
        #expect(engine.currentPomodoroNumber == 2)

        engine.skip()
        #expect(engine.phase == .break)
        #expect(engine.completedPomodorosInCycle == 2)

        engine.skip()
        #expect(engine.phase == .pomoPomo)
        #expect(engine.activePomodoroIndexInCycle == 2)
        #expect(engine.currentPomodoroNumber == 3)
    }

    @Test func freshSettingsDefaultToFiftyMinutePomoPomo() async {
        let suiteName = "PomodoroEngineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = SettingsStore(defaults: defaults)
        let engine = PomodoroEngine(settingsStore: store, clock: TestClock())

        #expect(store.settings.pomoPomoDurationMinutes == 50)
        #expect(engine.remainingSeconds == 50 * 60)
        #expect(engine.statusItemTitle == "50:00")
    }

    @Test func completedPomoPomoIncrementsCycleAndMovesToBreak() async {
        let (engine, _, clock) = makeEngine(pomoPomoMinutes: 25, autoStart: false)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.tick()

        #expect(engine.phase == .break)
        #expect(engine.completedPomodorosInCycle == 1)
    }

    @Test func autoStartBreakAfterPomoPomoCompletion() async {
        let (engine, _, clock) = makeEngine(pomoPomoMinutes: 25, breakMinutes: 5, autoStart: true)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.tick()

        #expect(engine.phase == .break)
        #expect(engine.state == .running)
    }

    @Test func skipBreakReturnsToPomoPomoWhilePaused() async {
        let (engine, _, _) = makeEngine()
        engine.test_setPhase(.break)
        engine.test_setState(.paused)
        engine.test_setRemainingSeconds(120)
        engine.skip()

        #expect(engine.phase == .pomoPomo)
        #expect(engine.state == .idle)
    }

    @Test func cycleWrapsAfterFourPomodoros() async {
        let (engine, defaults, clock) = makeEngine(autoStart: false, completed: 3)
        engine.reloadSettings()
        engine.start()
        clock.advance(by: 25 * 60)
        engine.tick()

        #expect(engine.completedPomodorosInCycle == 0)
        #expect(defaults.integer(forKey: "completedPomodorosInCycle") == 0)
    }

    @Test func settingsUpdateWhileIdle() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25)
        engine.setPomoPomoDuration(minutes: 30)
        #expect(engine.remainingSeconds == 30 * 60)
    }

    @Test func pomoPomoProgressFractionReflectsElapsedTime() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25)
        engine.start()
        engine.test_setRemainingSeconds(25 * 60 / 2)

        #expect(engine.activePomodoroIndexInCycle == 0)
        #expect(engine.currentPomoPomoProgressFraction == 0.5)
    }

    @Test func breakShowsNoActivePomodoroAndCompletedCount() async {
        let (engine, _, clock) = makeEngine(pomoPomoMinutes: 25, autoStart: false)
        engine.start()
        clock.advance(by: 25 * 60)
        engine.tick()

        #expect(engine.phase == .break)
        #expect(engine.activePomodoroIndexInCycle == nil)
        #expect(engine.displayCompletedPomodorosInCycle == 1)
        #expect(engine.currentPomoPomoProgressFraction == 0)
    }

    @Test func fullCycleBreakShowsAllCompletedAfterWrap() async {
        let (engine, _, clock) = makeEngine(autoStart: false, completed: 3)
        engine.reloadSettings()
        engine.start()
        clock.advance(by: 25 * 60)
        engine.tick()

        #expect(engine.completedPomodorosInCycle == 0)
        #expect(engine.displayCompletedPomodorosInCycle == Settings.cycleLength)
    }

    @Test func idleBreakStatusTitleShowsBreakDuration() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 50, breakMinutes: 10, autoStart: false)
        engine.skip()

        #expect(engine.phase == .break)
        #expect(engine.state == .idle)
        #expect(engine.remainingSeconds == 10 * 60)
        #expect(engine.statusItemTitle == "10:00")
    }

    @Test func resetReturnsToFreshPomoPomoCycle() async {
        let (engine, defaults, _) = makeEngine(pomoPomoMinutes: 50, breakMinutes: 10, autoStart: false)
        engine.skip()
        engine.skip()
        engine.start()
        engine.test_setRemainingSeconds(30 * 60)

        #expect(engine.phase == .pomoPomo)
        #expect(engine.state == .running)
        #expect(engine.completedPomodorosInCycle == 1)
        #expect(engine.activePomodoroIndexInCycle == 1)
        #expect(engine.remainingSeconds == 30 * 60)

        engine.reset()

        #expect(engine.state == .idle)
        #expect(engine.phase == .pomoPomo)
        #expect(engine.remainingSeconds == 50 * 60)
        #expect(engine.totalSeconds == 50 * 60)
        #expect(engine.statusItemTitle == "50:00")
        #expect(engine.completedPomodorosInCycle == 0)
        #expect(engine.activePomodoroIndexInCycle == 0)
        #expect(engine.currentPomodoroNumber == 1)
        #expect(defaults.integer(forKey: "completedPomodorosInCycle") == 0)
        #expect(engine.pomoPomoDurationMinutes == 50)
        #expect(engine.breakDurationMinutes == 10)
        #expect(engine.autoStart == false)
    }

    @Test func resetStopsRunningTimer() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 25, autoStart: false, completed: 2)
        engine.reloadSettings()
        engine.start()
        engine.test_setRemainingSeconds(600)

        engine.reset()

        #expect(engine.state == .idle)
        #expect(engine.phase == .pomoPomo)
        #expect(engine.remainingSeconds == 25 * 60)
        #expect(engine.completedPomodorosInCycle == 0)
        #expect(engine.activePomodoroIndexInCycle == 0)
    }

    @Test func pauseResumePreservesRemainingSeconds() async {
        let (engine, _, clock) = makeEngine(pomoPomoMinutes: 1)
        engine.start()

        clock.advance(by: 15)
        engine.tick()
        engine.pause()

        let remainingAtPause = engine.remainingSeconds
        #expect(remainingAtPause == 45)

        clock.advance(by: 120)
        #expect(engine.remainingSeconds == remainingAtPause)

        engine.resume()
        clock.advance(by: 10)
        engine.tick()
        #expect(engine.remainingSeconds == 35)
    }

    @Test func startFromIdleNotifiesPhaseDidBeginRunning() async {
        let (engine, _, _) = makeEngine()
        let delegate = RecordingEngineDelegate()
        engine.delegate = delegate

        engine.start()

        #expect(delegate.phaseDidBeginRunning == [.pomoPomo])
    }

    @Test func resumeDoesNotNotifyPhaseDidBeginRunning() async {
        let (engine, _, _) = makeEngine(pomoPomoMinutes: 1)
        let delegate = RecordingEngineDelegate()
        engine.delegate = delegate

        engine.start()
        delegate.clearPhaseDidBeginRunning()
        engine.pause()
        engine.resume()

        #expect(delegate.phaseDidBeginRunning.isEmpty)
    }

    @Test func skipWhileRunningNotifiesPhaseDidBeginRunningForNewPhase() async {
        let (engine, _, _) = makeEngine(autoStart: false)
        let delegate = RecordingEngineDelegate()
        engine.delegate = delegate

        engine.start()
        delegate.clearPhaseDidBeginRunning()
        engine.skip()

        #expect(delegate.phaseDidBeginRunning == [.break])
    }

    @Test func skipWhilePausedDoesNotNotifyPhaseDidBeginRunning() async {
        let (engine, _, _) = makeEngine(autoStart: false)
        let delegate = RecordingEngineDelegate()
        engine.delegate = delegate

        engine.start()
        engine.pause()
        delegate.clearPhaseDidBeginRunning()
        engine.skip()

        #expect(delegate.phaseDidBeginRunning.isEmpty)
    }

    @Test func autoStartAfterCompletionNotifiesPhaseDidBeginRunning() async {
        let (engine, _, clock) = makeEngine(pomoPomoMinutes: 1, breakMinutes: 1, autoStart: true)
        let delegate = RecordingEngineDelegate()
        engine.delegate = delegate

        engine.start()
        delegate.clearPhaseDidBeginRunning()
        clock.advance(by: 60)
        engine.tick()

        #expect(delegate.phaseDidBeginRunning == [.break])
    }
}
