import Foundation

public enum FilePaths {
    public static let logRootDirectoryName = "Pomodoro"

    public static func logRoot(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        homeDirectory
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent(logRootDirectoryName, isDirectory: true)
    }

    public static func dayDirectory(
        for date: Date,
        logRoot: URL = logRoot(),
        calendar: Calendar = .current
    ) -> URL {
        let dayName = DateFormatters.dayFolderName(for: date, calendar: calendar)
        return logRoot.appendingPathComponent(dayName, isDirectory: true)
    }

    public static func dayMarkdownFile(
        for date: Date,
        logRoot: URL = logRoot(),
        calendar: Calendar = .current
    ) -> URL {
        let dayName = DateFormatters.dayFolderName(for: date, calendar: calendar)
        return dayDirectory(for: date, logRoot: logRoot, calendar: calendar)
            .appendingPathComponent("\(dayName).md")
    }
}
