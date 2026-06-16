import Foundation

public struct MarkdownSummary: Equatable, Sendable {
    public var pomodorosCompleted: Int
    public var totalFocusMinutes: Int
    public var firstActivityTime: String?
    public var lastActivityTime: String?

    public init(
        pomodorosCompleted: Int = 0,
        totalFocusMinutes: Int = 0,
        firstActivityTime: String? = nil,
        lastActivityTime: String? = nil
    ) {
        self.pomodorosCompleted = pomodorosCompleted
        self.totalFocusMinutes = totalFocusMinutes
        self.firstActivityTime = firstActivityTime
        self.lastActivityTime = lastActivityTime
    }
}

public enum MarkdownRenderer {
    public static func heading(for date: Date, calendar: Calendar = .current) -> String {
        let day = DateFormatters.markdownHeadingDate(for: date, calendar: calendar)
        return "# Pomopomo — \(day)"
    }

    public static func renderDocument(
        date: Date,
        summary: MarkdownSummary,
        timelineLines: [String],
        calendar: Calendar = .current
    ) -> String {
        var lines: [String] = []
        lines.append(heading(for: date, calendar: calendar))
        lines.append("")
        lines.append("## Summary")
        lines.append("- Pomodoros completed: \(summary.pomodorosCompleted)")
        lines.append("- Total focus minutes: \(summary.totalFocusMinutes)")
        if let first = summary.firstActivityTime {
            lines.append("- First activity: \(first)")
        } else {
            lines.append("- First activity: —")
        }
        if let last = summary.lastActivityTime {
            lines.append("- Last activity: \(last)")
        } else {
            lines.append("- Last activity: —")
        }
        lines.append("")
        lines.append("## Timeline")
        if timelineLines.isEmpty {
            lines.append("_No events yet._")
        } else {
            lines.append(contentsOf: timelineLines)
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    public static func parseSummary(from content: String) -> MarkdownSummary {
        guard let summaryBlock = extractSection(named: "Summary", from: content) else {
            return MarkdownSummary()
        }

        var summary = MarkdownSummary()
        for line in summaryBlock.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- Pomodoros completed:") {
                summary.pomodorosCompleted = parseInt(after: ":", in: trimmed) ?? 0
            } else if trimmed.hasPrefix("- Total focus minutes:") {
                summary.totalFocusMinutes = parseInt(after: ":", in: trimmed) ?? 0
            } else if trimmed.hasPrefix("- First activity:") {
                summary.firstActivityTime = parseActivityTime(after: ":", in: trimmed)
            } else if trimmed.hasPrefix("- Last activity:") {
                summary.lastActivityTime = parseActivityTime(after: ":", in: trimmed)
            }
        }
        return summary
    }

    public static func parseTimeline(from content: String) -> [String] {
        guard let timelineBlock = extractSection(named: "Timeline", from: content) else {
            return []
        }
        return timelineBlock
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") }
    }

    public static func applyEvent(
        _ event: LogEvent,
        at date: Date,
        to summary: MarkdownSummary,
        calendar: Calendar = .current
    ) -> MarkdownSummary {
        var updated = summary
        let time = TimeFormatters.timeOfDay(date, calendar: calendar)

        if updated.firstActivityTime == nil {
            updated.firstActivityTime = time
        }
        updated.lastActivityTime = time

        if event.countsAsCompletedPomodoro {
            updated.pomodorosCompleted += 1
        }

        if case let .pomoPomoCompleted(durationMinutes) = event {
            updated.totalFocusMinutes += durationMinutes
        }

        return updated
    }

    private static func extractSection(named name: String, from content: String) -> String? {
        let marker = "## \(name)"
        guard let range = content.range(of: marker) else { return nil }
        let after = content[range.upperBound...]
        if let nextSection = after.range(of: "\n## ") {
            return String(after[..<nextSection.lowerBound]).trimmingCharacters(in: .newlines)
        }
        return String(after).trimmingCharacters(in: .newlines)
    }

    private static func parseInt(after separator: Character, in line: String) -> Int? {
        guard let idx = line.firstIndex(of: separator) else { return nil }
        let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        return Int(value)
    }

    private static func parseActivityTime(after separator: Character, in line: String) -> String? {
        guard let idx = line.firstIndex(of: separator) else { return nil }
        let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        if value == "—" || value.isEmpty { return nil }
        return value
    }
}
