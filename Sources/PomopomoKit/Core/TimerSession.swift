import Foundation

public struct TimerSession: Sendable, Equatable {
    public let phase: PomodoroPhase
    public let totalSeconds: Int
    public let remainingSeconds: Int
    public let pomodoroNumber: Int

    public init(
        phase: PomodoroPhase,
        totalSeconds: Int,
        remainingSeconds: Int,
        pomodoroNumber: Int
    ) {
        self.phase = phase
        self.totalSeconds = totalSeconds
        self.remainingSeconds = remainingSeconds
        self.pomodoroNumber = pomodoroNumber
    }

    public var isExpired: Bool {
        remainingSeconds <= 0
    }
}
