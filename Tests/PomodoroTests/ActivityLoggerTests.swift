import Foundation
import Testing
@testable import PomodoroKit

struct ActivityLoggerTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func makeTempLogRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PomodoroTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    @Test func writesDayDirectoryAndMarkdownFile() throws {
        let logRoot = makeTempLogRoot()
        defer { try? FileManager.default.removeItem(at: logRoot) }

        let sampleDate = date(year: 2026, month: 6, day: 16, hour: 9, minute: 30)
        let clock = TestClock(start: sampleDate)
        let logger = ActivityLogger(
            fileManager: .default,
            clock: clock,
            calendar: calendar,
            logRootDirectory: logRoot
        )

        logger.log(.appLaunched)
        logger.log(.pomoPomoStarted(number: 1, durationMinutes: 25))
        logger.log(.pomoPomoCompleted(durationMinutes: 25))

        let dayDirectory = FilePaths.dayDirectory(for: sampleDate, logRoot: logRoot, calendar: calendar)
        let markdownFile = FilePaths.dayMarkdownFile(for: sampleDate, logRoot: logRoot, calendar: calendar)

        #expect(FileManager.default.fileExists(atPath: dayDirectory.path))
        #expect(FileManager.default.fileExists(atPath: markdownFile.path))

        let content = try String(contentsOf: markdownFile, encoding: .utf8)
        #expect(content.contains("# Pomodoro — 2026-06-16"))
        #expect(content.contains("- Pomodoros completed: 1"))
        #expect(content.contains("- Total focus minutes: 25"))
        #expect(content.contains("- First activity: 09:30"))
        #expect(content.contains("- Last activity: 09:30"))
        #expect(content.contains("- 09:30 — App launched"))
        #expect(content.contains("- 09:30 — PomoPomo #1 started (25 min)"))
        #expect(content.contains("- 09:30 — PomoPomo completed (25 min)"))
    }

    @Test func dayRolloverWritesSeparateFiles() throws {
        let logRoot = makeTempLogRoot()
        defer { try? FileManager.default.removeItem(at: logRoot) }

        let dayOne = date(year: 2026, month: 6, day: 16, hour: 23, minute: 45)
        let dayTwo = date(year: 2026, month: 6, day: 17, hour: 0, minute: 15)
        let clock = TestClock(start: dayOne)
        let logger = ActivityLogger(
            fileManager: .default,
            clock: clock,
            calendar: calendar,
            logRootDirectory: logRoot
        )

        logger.log(.appLaunched)
        clock.set(dayTwo)
        logger.log(.appQuit)

        let dayOneFile = FilePaths.dayMarkdownFile(for: dayOne, logRoot: logRoot, calendar: calendar)
        let dayTwoFile = FilePaths.dayMarkdownFile(for: dayTwo, logRoot: logRoot, calendar: calendar)

        #expect(dayOneFile != dayTwoFile)
        #expect(FileManager.default.fileExists(atPath: dayOneFile.path))
        #expect(FileManager.default.fileExists(atPath: dayTwoFile.path))

        let dayOneContent = try String(contentsOf: dayOneFile, encoding: .utf8)
        let dayTwoContent = try String(contentsOf: dayTwoFile, encoding: .utf8)

        #expect(dayOneContent.contains("# Pomodoro — 2026-06-16"))
        #expect(dayOneContent.contains("- 23:45 — App launched"))
        #expect(!dayOneContent.contains("App quit"))

        #expect(dayTwoContent.contains("# Pomodoro — 2026-06-17"))
        #expect(dayTwoContent.contains("- 00:15 — App quit"))
        #expect(!dayTwoContent.contains("App launched"))
    }
}
