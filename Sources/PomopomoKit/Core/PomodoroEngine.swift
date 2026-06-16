import Foundation

@MainActor
public protocol PomodoroEngineDelegate: AnyObject {
    func engineDidUpdate(_ engine: PomodoroEngine)
    func engine(_ engine: PomodoroEngine, phaseDidBeginRunning phase: PomodoroPhase)
    func engine(_ engine: PomodoroEngine, didTransitionFrom oldPhase: PomodoroPhase?, to newPhase: PomodoroPhase, skipped: Bool)
    func engine(_ engine: PomodoroEngine, didCompletePomodoro number: Int)
}

@MainActor
@Observable
public final class PomodoroEngine {
    public private(set) var phase: PomodoroPhase = .pomoPomo
    public private(set) var state: PomodoroState = .idle
    public private(set) var remainingSeconds: Int = 0
    public private(set) var totalSeconds: Int = 0
    public private(set) var currentPomodoroNumber: Int = 1
    public private(set) var completedPomodorosInCycle: Int = 0

    public weak var delegate: PomodoroEngineDelegate?

    private var settings: Settings
    private let settingsStore: SettingsStore
    private let clock: Clock
    private var endDate: Date?
    private var tickTimer: Timer?

    public init(
        settingsStore: SettingsStore = .shared,
        clock: Clock = SystemClock()
    ) {
        self.settingsStore = settingsStore
        self.clock = clock
        self.settings = settingsStore.settings
        self.completedPomodorosInCycle = settings.completedPomodorosInCycle
        resetToIdle(for: .pomoPomo)
    }

    public var session: TimerSession {
        TimerSession(
            phase: phase,
            totalSeconds: totalSeconds,
            remainingSeconds: remainingSeconds,
            pomodoroNumber: currentPomodoroNumber
        )
    }

    public var displayTitle: String {
        phase.displayTitle
    }

    /// Zero-based index of the pomodoro currently in progress during PomoPomo, if any.
    public var activePomodoroIndexInCycle: Int? {
        guard phase == .pomoPomo else { return nil }
        return completedPomodorosInCycle % Settings.cycleLength
    }

    /// Elapsed fraction (0...1) of the current PomoPomo phase, for progress UI.
    public var currentPomoPomoProgressFraction: Double {
        guard phase == .pomoPomo, totalSeconds > 0 else { return 0 }
        let elapsed = totalSeconds - remainingSeconds
        return min(1, max(0, Double(elapsed) / Double(totalSeconds)))
    }

    /// Completed pomodoros to show in cycle progress UI (handles post-cycle break wrap).
    public var displayCompletedPomodorosInCycle: Int {
        if phase == .break,
           completedPomodorosInCycle == 0,
           currentPomodoroNumber == Settings.cycleLength {
            return Settings.cycleLength
        }
        return completedPomodorosInCycle
    }

    public var statusItemTitle: String {
        TimeFormatters.mmss(from: remainingSeconds)
    }

    public func reloadSettings() {
        settings = settingsStore.settings
        completedPomodorosInCycle = settings.completedPomodorosInCycle
        if state == .idle {
            resetToIdle(for: phase)
        }
    }

    public func setPomoPomoDuration(minutes: Int) {
        settings.pomoPomoDurationMinutes = minutes
        settingsStore.settings = settings
        settingsStore.save()
        if state == .idle && phase == .pomoPomo {
            resetToIdle(for: .pomoPomo)
            notifyUpdate()
        }
    }

    public func setBreakDuration(minutes: Int) {
        settings.breakDurationMinutes = minutes
        settingsStore.settings = settings
        settingsStore.save()
        if state == .idle && phase == .break {
            resetToIdle(for: .break)
            notifyUpdate()
        }
    }

    public func setAutoStart(_ enabled: Bool) {
        settings.autoStart = enabled
        settingsStore.settings = settings
        settingsStore.save()
    }

    public var autoStart: Bool {
        settings.autoStart
    }

    public var pomoPomoDurationMinutes: Int {
        settings.pomoPomoDurationMinutes
    }

    public var breakDurationMinutes: Int {
        settings.breakDurationMinutes
    }

    // MARK: - Controls

    public func togglePlayPause() {
        switch state {
        case .idle, .completed:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }

    public func start() {
        let duration = durationSeconds(for: phase)
        totalSeconds = duration
        if remainingSeconds <= 0 || state == .completed || state == .idle {
            remainingSeconds = duration
        }
        endDate = clock.now().addingTimeInterval(TimeInterval(remainingSeconds))
        state = .running
        startTickTimer()
        notifyPhaseDidBeginRunning()
        notifyUpdate()
    }

    public func pause() {
        guard state == .running else { return }
        syncRemainingFromEndDate()
        state = .paused
        stopTickTimer()
        notifyUpdate()
    }

    public func resume() {
        guard state == .paused else { return }
        endDate = clock.now().addingTimeInterval(TimeInterval(remainingSeconds))
        state = .running
        startTickTimer()
        notifyUpdate()
    }

    public func skip() {
        let wasRunning = state == .running
        stopTickTimer()
        let oldPhase = phase
        handlePhaseCompletion(wasSkipped: true, preserveRunning: wasRunning)
        if oldPhase != phase {
            delegate?.engine(self, didTransitionFrom: oldPhase, to: phase, skipped: true)
        }
        notifyUpdate()
    }

    public func reset() {
        stopTickTimer()
        completedPomodorosInCycle = 0
        persistCompletedCount()
        resetToIdle(for: .pomoPomo)
        notifyUpdate()
    }

    public func tick() {
        guard state == .running else { return }
        syncRemainingFromEndDate()
        if remainingSeconds <= 0 {
            remainingSeconds = 0
            stopTickTimer()
            state = .completed
            let oldPhase = phase
            handlePhaseCompletion(wasSkipped: false)
            if oldPhase != phase {
                delegate?.engine(self, didTransitionFrom: oldPhase, to: phase, skipped: false)
            }
        }
        notifyUpdate()
    }

    public func prepareForNextPhase(autoStart: Bool) {
        if autoStart && (state == .completed || state == .idle) {
            start()
        } else {
            resetToIdle(for: phase)
            notifyUpdate()
        }
    }

    // MARK: - Private

    private func durationSeconds(for phase: PomodoroPhase) -> Int {
        switch phase {
        case .pomoPomo: settings.pomoPomoDurationSeconds()
        case .break: settings.breakDurationSeconds()
        }
    }

    private func resetToIdle(for phase: PomodoroPhase) {
        self.phase = phase
        state = .idle
        totalSeconds = durationSeconds(for: phase)
        remainingSeconds = totalSeconds
        endDate = nil
        if phase == .pomoPomo {
            currentPomodoroNumber = (completedPomodorosInCycle % Settings.cycleLength) + 1
        }
    }

    private func handlePhaseCompletion(wasSkipped: Bool, preserveRunning: Bool = false) {
        let autoStart = wasSkipped ? preserveRunning : settings.autoStart
        switch phase {
        case .pomoPomo:
            // Skip advances the cycle the same way a natural completion does.
            recordCompletedPomodoroInCycle()
            if !wasSkipped {
                delegate?.engine(self, didCompletePomodoro: currentPomodoroNumber)
            }
            transitionToBreak(autoStart: autoStart)

        case .break:
            transitionToPomoPomo(autoStart: autoStart)
        }
    }

    private func recordCompletedPomodoroInCycle() {
        completedPomodorosInCycle += 1
        if completedPomodorosInCycle >= Settings.cycleLength {
            completedPomodorosInCycle = 0
        }
        persistCompletedCount()
    }

    private func transitionToBreak(autoStart: Bool) {
        phase = .break
        totalSeconds = settings.breakDurationSeconds()
        remainingSeconds = totalSeconds
        applyRunningState(autoStart: autoStart)
    }

    private func transitionToPomoPomo(autoStart: Bool) {
        phase = .pomoPomo
        currentPomodoroNumber = (completedPomodorosInCycle % Settings.cycleLength) + 1
        totalSeconds = settings.pomoPomoDurationSeconds()
        remainingSeconds = totalSeconds
        applyRunningState(autoStart: autoStart)
    }

    private func applyRunningState(autoStart: Bool) {
        state = autoStart ? .running : .idle
        if autoStart {
            endDate = clock.now().addingTimeInterval(TimeInterval(remainingSeconds))
            startTickTimer()
            notifyPhaseDidBeginRunning()
        } else {
            endDate = nil
            stopTickTimer()
        }
    }

    private func persistCompletedCount() {
        settings.completedPomodorosInCycle = completedPomodorosInCycle
        settingsStore.settings = settings
        settingsStore.save()
    }

    private func syncRemainingFromEndDate() {
        guard let endDate else { return }
        let seconds = Int(ceil(endDate.timeIntervalSince(clock.now())))
        remainingSeconds = max(0, seconds)
    }

    private func startTickTimer() {
        stopTickTimer()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        if let tickTimer {
            RunLoop.main.add(tickTimer, forMode: .common)
        }
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func notifyUpdate() {
        delegate?.engineDidUpdate(self)
    }

    private func notifyPhaseDidBeginRunning() {
        delegate?.engine(self, phaseDidBeginRunning: phase)
    }
}

// MARK: - Test helpers

extension PomodoroEngine {
    public func test_setPhase(_ phase: PomodoroPhase) {
        self.phase = phase
    }

    public func test_setState(_ state: PomodoroState) {
        self.state = state
    }

    public func test_setRemainingSeconds(_ seconds: Int) {
        remainingSeconds = seconds
    }

    public func test_setCompletedInCycle(_ count: Int) {
        completedPomodorosInCycle = count
        currentPomodoroNumber = (count % Settings.cycleLength) + 1
    }
}
