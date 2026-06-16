import Foundation

public final class ActivityLogger: @unchecked Sendable {
    private let fileManager: FileManager
    private let clock: Clock
    private let calendar: Calendar
    private let logRootDirectory: URL
    private let lock = NSLock()

    public init(
        fileManager: FileManager = .default,
        clock: Clock = SystemClock(),
        calendar: Calendar = .current,
        logRootDirectory: URL = FilePaths.logRoot()
    ) {
        self.fileManager = fileManager
        self.clock = clock
        self.calendar = calendar
        self.logRootDirectory = logRootDirectory
    }

    public func log(_ event: LogEvent) {
        lock.lock()
        defer { lock.unlock() }

        let now = clock.now()
        let fileURL = FilePaths.dayMarkdownFile(for: now, logRoot: logRootDirectory, calendar: calendar)
        let directory = fileURL.deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return
        }

        let existingContent: String
        if fileManager.fileExists(atPath: fileURL.path) {
            existingContent = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        } else {
            existingContent = ""
        }

        var summary = MarkdownRenderer.parseSummary(from: existingContent)
        var timeline = MarkdownRenderer.parseTimeline(from: existingContent)

        summary = MarkdownRenderer.applyEvent(event, at: now, to: summary, calendar: calendar)
        timeline.append(event.timelineLine(at: now, calendar: calendar))

        let document = MarkdownRenderer.renderDocument(
            date: now,
            summary: summary,
            timelineLines: timeline,
            calendar: calendar
        )

        try? document.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
