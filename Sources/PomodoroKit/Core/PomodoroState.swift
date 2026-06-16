import Foundation

public enum PomodoroState: String, Codable, Sendable, Equatable {
    case idle
    case running
    case paused
    case completed
}
