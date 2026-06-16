import Foundation
import MCP
import PomopomoKit

struct CoordinatorRef: @unchecked Sendable {
    let coordinator: AppCoordinator
}

private struct StatusSnapshot: Codable {
    let phase: String
    let state: String
    let remainingSeconds: Int
    let totalSeconds: Int
    let formattedTime: String
    let currentPomodoroNumber: Int
    let completedPomodorosInCycle: Int
    let progressFraction: Double
}

private struct SettingsSnapshot: Codable {
    let pomoPomoDurationMinutes: Int
    let breakDurationMinutes: Int
    let autoStart: Bool
}

private let emptyObjectSchema: Value = .object([
    "type": .string("object"),
    "properties": .object([:]),
])

func configurePomodoroTools(on server: Server, coordinatorRef: CoordinatorRef) async {
    await server.withMethodHandler(ListTools.self) { _ in
        let tools: [Tool] = [
            Tool(
                name: "get_status",
                description: "Get the current timer status including phase, state, remaining time, and pomodoro progress",
                inputSchema: emptyObjectSchema
            ),
            Tool(
                name: "play_pause",
                description: "Toggle the timer between play and pause. Starts the timer if idle, pauses if running, resumes if paused",
                inputSchema: emptyObjectSchema
            ),
            Tool(
                name: "skip",
                description: "Skip the current phase and move to the next one (PomoPomo → Break or Break → PomoPomo)",
                inputSchema: emptyObjectSchema
            ),
            Tool(
                name: "fast_forward",
                description: "Fast-forward the timer by subtracting seconds from remaining time. Completes the phase if time reaches zero. Timer must be running",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "seconds": .object([
                            "type": .string("integer"),
                            "description": .string("Number of seconds to subtract from remaining time"),
                        ]),
                    ]),
                    "required": .array([.string("seconds")]),
                ])
            ),
            Tool(
                name: "reset",
                description: "Reset the timer completely — clears the pomodoro cycle and returns to idle PomoPomo phase",
                inputSchema: emptyObjectSchema
            ),
            Tool(
                name: "get_settings",
                description: "Get the current timer settings: pomodoro duration, break duration, and auto-start preference",
                inputSchema: emptyObjectSchema
            ),
            Tool(
                name: "update_settings",
                description: "Update timer settings. Provide any combination of the optional fields to change",
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "pomodoro_duration_minutes": .object([
                            "type": .string("integer"),
                            "description": .string("Pomodoro duration in minutes (valid: 15, 20, 25, 30, 45, 50, 60, 90)"),
                        ]),
                        "break_duration_minutes": .object([
                            "type": .string("integer"),
                            "description": .string("Break duration in minutes (valid: 5, 10, 15)"),
                        ]),
                        "auto_start": .object([
                            "type": .string("boolean"),
                            "description": .string("Whether to auto-start the next phase after completion"),
                        ]),
                    ]),
                ])
            ),
        ]
        return .init(tools: tools)
    }

    await server.withMethodHandler(CallTool.self) { params in
        switch params.name {
        case "get_status":
            let snapshot = await MainActor.run {
                makeStatusSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        case "play_pause":
            await MainActor.run {
                coordinatorRef.coordinator.togglePlayPause()
            }
            let snapshot = await MainActor.run {
                makeStatusSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        case "skip":
            await MainActor.run {
                coordinatorRef.coordinator.skipPhase()
            }
            let snapshot = await MainActor.run {
                makeStatusSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        case "fast_forward":
            guard let seconds = params.arguments?["seconds"]?.intValue, seconds > 0 else {
                return .init(content: [.text(text: "Error: 'seconds' must be a positive integer", annotations: nil, _meta: nil)], isError: true)
            }
            await MainActor.run {
                coordinatorRef.coordinator.fastForward(seconds: seconds)
            }
            let snapshot = await MainActor.run {
                makeStatusSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        case "reset":
            await MainActor.run {
                coordinatorRef.coordinator.resetTimer()
            }
            let snapshot = await MainActor.run {
                makeStatusSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        case "get_settings":
            let snapshot = await MainActor.run {
                makeSettingsSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        case "update_settings":
            let args = params.arguments ?? [:]
            let validationError = await MainActor.run { () -> String? in
                let coord = coordinatorRef.coordinator

                if let mins = args["pomodoro_duration_minutes"]?.intValue {
                    guard Settings.pomoPomoDurationOptions.contains(mins) else {
                        return "Error: pomodoro_duration_minutes must be one of \(Settings.pomoPomoDurationOptions)"
                    }
                    coord.updatePomoPomoDuration(minutes: mins)
                }
                if let mins = args["break_duration_minutes"]?.intValue {
                    guard Settings.breakDurationOptions.contains(mins) else {
                        return "Error: break_duration_minutes must be one of \(Settings.breakDurationOptions)"
                    }
                    coord.updateBreakDuration(minutes: mins)
                }
                if let auto = args["auto_start"]?.boolValue {
                    coord.updateAutoStart(auto)
                }
                return nil
            }

            if let error = validationError {
                return .init(content: [.text(text: error, annotations: nil, _meta: nil)], isError: true)
            }

            let snapshot = await MainActor.run {
                makeSettingsSnapshot(coordinatorRef.coordinator)
            }
            return .init(content: [.text(text: encodeJSON(snapshot), annotations: nil, _meta: nil)])

        default:
            return .init(content: [.text(text: "Unknown tool: \(params.name)", annotations: nil, _meta: nil)], isError: true)
        }
    }
}

@MainActor
private func makeStatusSnapshot(_ coordinator: AppCoordinator) -> StatusSnapshot {
    let engine = coordinator.engine
    return StatusSnapshot(
        phase: engine.phase.rawValue,
        state: engine.state.rawValue,
        remainingSeconds: engine.remainingSeconds,
        totalSeconds: engine.totalSeconds,
        formattedTime: engine.statusItemTitle,
        currentPomodoroNumber: engine.currentPomodoroNumber,
        completedPomodorosInCycle: engine.completedPomodorosInCycle,
        progressFraction: engine.currentPomoPomoProgressFraction
    )
}

@MainActor
private func makeSettingsSnapshot(_ coordinator: AppCoordinator) -> SettingsSnapshot {
    let engine = coordinator.engine
    return SettingsSnapshot(
        pomoPomoDurationMinutes: engine.pomoPomoDurationMinutes,
        breakDurationMinutes: engine.breakDurationMinutes,
        autoStart: engine.autoStart
    )
}

private func encodeJSON<T: Codable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(value),
          let string = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return string
}
