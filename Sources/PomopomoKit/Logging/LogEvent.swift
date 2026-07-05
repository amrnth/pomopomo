import Foundation

public enum LogEvent: Sendable, Equatable {
    case appLaunched
    case panelOpened
    case pomoPomoStarted(number: Int, durationMinutes: Int)
    case pomoPomoPaused
    case pomoPomoResumed
    case pomoPomoSkipped
    case pomoPomoCompleted(durationMinutes: Int)
    case breakStarted
    case breakSkipped
    case breakCompleted
    case pomoPomoDurationChanged(minutes: Int)
    case breakDurationChanged(minutes: Int)
    case autoStartToggled(enabled: Bool)
    case pomoPomoFastForwarded(seconds: Int)
    case timerReset
    case appQuit

    public func timelineLine(at date: Date, calendar: Calendar = .current) -> String {
        let time = TimeFormatters.timeOfDay(date, calendar: calendar)
        return "- \(time) — \(description)"
    }

    public var description: String {
        switch self {
        case .appLaunched:
            "App launched"
        case .panelOpened:
            "Panel opened"
        case let .pomoPomoStarted(number, durationMinutes):
            "Pomodoro #\(number) started (\(durationMinutes) min)"
        case .pomoPomoPaused:
            "Pomodoro paused"
        case .pomoPomoResumed:
            "Pomodoro resumed"
        case .pomoPomoSkipped:
            "Pomodoro skipped"
        case let .pomoPomoCompleted(durationMinutes):
            "Pomodoro completed (\(durationMinutes) min)"
        case .breakStarted:
            "Break started"
        case .breakSkipped:
            "Break skipped"
        case .breakCompleted:
            "Break completed"
        case let .pomoPomoDurationChanged(minutes):
            "Pomodoro duration changed to \(minutes) min"
        case let .breakDurationChanged(minutes):
            "Break duration changed to \(minutes) min"
        case let .autoStartToggled(enabled):
            "Auto-start \(enabled ? "enabled" : "disabled")"
        case let .pomoPomoFastForwarded(seconds):
            "Pomodoro fast-forwarded by \(seconds)s"
        case .timerReset:
            "Timer reset"
        case .appQuit:
            "App quit"
        }
    }

    public var countsAsCompletedPomodoro: Bool {
        if case .pomoPomoCompleted = self { return true }
        return false
    }

    public var focusMinutesAdded: Int? {
        switch self {
        case let .pomoPomoStarted(_, durationMinutes):
            return durationMinutes
        default:
            return nil
        }
    }
}
