import Foundation

public enum PomodoroPhase: String, Codable, Sendable, Equatable {
    case pomoPomo
    case `break`

    public var displayTitle: String {
        switch self {
        case .pomoPomo: "Pomodoro"
        case .break: "Break"
        }
    }
}
