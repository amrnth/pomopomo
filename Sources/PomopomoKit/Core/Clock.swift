import Foundation

public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}

    public func now() -> Date {
        Date()
    }
}

public final class TestClock: @unchecked Sendable {
    private var current: Date
    private let lock = NSLock()

    public init(start: Date = Date()) {
        current = start
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    public func set(_ date: Date) {
        lock.lock()
        defer { lock.unlock() }
        current = date
    }
}

extension TestClock: Clock {
    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}
