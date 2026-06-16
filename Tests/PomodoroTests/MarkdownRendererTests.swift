import Foundation
import Testing
@testable import PomodoroKit

struct MarkdownRendererTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var sampleDate: Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 6
        components.day = 16
        components.hour = 9
        components.minute = 30
        return calendar.date(from: components)!
    }

    @Test func rendersFreshDocument() {
        let markdown = MarkdownRenderer.renderDocument(
            date: sampleDate,
            summary: MarkdownSummary(),
            timelineLines: [],
            calendar: calendar
        )

        #expect(markdown.contains("# Pomodoro — 2026-06-16"))
        #expect(markdown.contains("## Summary"))
        #expect(markdown.contains("- Pomodoros completed: 0"))
        #expect(markdown.contains("## Timeline"))
        #expect(markdown.contains("_No events yet._"))
    }

    @Test func applyEventUpdatesSummary() {
        var summary = MarkdownSummary()
        summary = MarkdownRenderer.applyEvent(
            .pomoPomoCompleted(durationMinutes: 25),
            at: sampleDate,
            to: summary,
            calendar: calendar
        )

        #expect(summary.pomodorosCompleted == 1)
        #expect(summary.totalFocusMinutes == 25)
        #expect(summary.firstActivityTime == "09:30")
        #expect(summary.lastActivityTime == "09:30")
    }

    @Test func parseAndRoundTripSummary() {
        let original = MarkdownSummary(
            pomodorosCompleted: 3,
            totalFocusMinutes: 75,
            firstActivityTime: "08:00",
            lastActivityTime: "11:15"
        )
        let document = MarkdownRenderer.renderDocument(
            date: sampleDate,
            summary: original,
            timelineLines: ["- 08:00 — App launched"],
            calendar: calendar
        )

        let parsed = MarkdownRenderer.parseSummary(from: document)
        #expect(parsed == original)

        let timeline = MarkdownRenderer.parseTimeline(from: document)
        #expect(timeline == ["- 08:00 — App launched"])
    }

    @Test func timelineLineFormatting() {
        let line = LogEvent.pomoPomoStarted(number: 2, durationMinutes: 25)
            .timelineLine(at: sampleDate, calendar: calendar)
        #expect(line == "- 09:30 — PomoPomo #2 started (25 min)")
    }

    @Test func timerResetTimelineLine() {
        let line = LogEvent.timerReset.timelineLine(at: sampleDate, calendar: calendar)
        #expect(line == "- 09:30 — Timer reset")
    }

    @Test func timerResetDoesNotAffectSummaryCounts() {
        var summary = MarkdownSummary(pomodorosCompleted: 2, totalFocusMinutes: 50)
        summary = MarkdownRenderer.applyEvent(
            .timerReset,
            at: sampleDate,
            to: summary,
            calendar: calendar
        )

        #expect(summary.pomodorosCompleted == 2)
        #expect(summary.totalFocusMinutes == 50)
        #expect(summary.lastActivityTime == "09:30")
    }
}
