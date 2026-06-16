import Foundation

public struct PanelPosition: Sendable, Equatable {
    public var originX: Double
    public var originY: Double

    public init(originX: Double, originY: Double) {
        self.originX = originX
        self.originY = originY
    }
}

public struct Settings: Codable, Sendable, Equatable {
    public static let cycleLength = 4

    public static let pomoPomoDurationOptions = [15, 20, 25, 30, 45, 50, 60, 90]
    public static let breakDurationOptions = [5, 10, 15]

    public var pomoPomoDurationMinutes: Int
    public var breakDurationMinutes: Int
    public var autoStart: Bool
    public var completedPomodorosInCycle: Int

    public init(
        pomoPomoDurationMinutes: Int = 50,
        breakDurationMinutes: Int = 5,
        autoStart: Bool = false,
        completedPomodorosInCycle: Int = 0
    ) {
        self.pomoPomoDurationMinutes = pomoPomoDurationMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.autoStart = autoStart
        self.completedPomodorosInCycle = completedPomodorosInCycle
    }

    public func pomoPomoDurationSeconds() -> Int {
        pomoPomoDurationMinutes * 60
    }

    public func breakDurationSeconds() -> Int {
        breakDurationMinutes * 60
    }
}

public protocol SettingsStoreProtocol: AnyObject, Sendable {
    var settings: Settings { get set }
    func save()
}

public final class SettingsStore: SettingsStoreProtocol, @unchecked Sendable {
    public static let shared = SettingsStore()

    private enum Keys {
        static let pomoPomoDuration = "pomoPomoDurationMinutes"
        static let breakDuration = "breakDurationMinutes"
        static let autoStart = "autoStart"
        static let completedPomodoros = "completedPomodorosInCycle"
        static let panelOriginX = "panelOriginX"
        static let panelOriginY = "panelOriginY"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    public var settings: Settings {
        get {
            lock.lock()
            defer { lock.unlock() }
            return Settings(
                pomoPomoDurationMinutes: defaults.integer(forKey: Keys.pomoPomoDuration).nonZeroOr(50),
                breakDurationMinutes: defaults.integer(forKey: Keys.breakDuration).nonZeroOr(5),
                autoStart: defaults.bool(forKey: Keys.autoStart),
                completedPomodorosInCycle: defaults.integer(forKey: Keys.completedPomodoros)
            )
        }
        set {
            lock.lock()
            defaults.set(newValue.pomoPomoDurationMinutes, forKey: Keys.pomoPomoDuration)
            defaults.set(newValue.breakDurationMinutes, forKey: Keys.breakDuration)
            defaults.set(newValue.autoStart, forKey: Keys.autoStart)
            defaults.set(newValue.completedPomodorosInCycle, forKey: Keys.completedPomodoros)
            lock.unlock()
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaultsIfNeeded()
    }

    public var panelPosition: PanelPosition? {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard defaults.object(forKey: Keys.panelOriginX) != nil,
                  defaults.object(forKey: Keys.panelOriginY) != nil else {
                return nil
            }
            return PanelPosition(
                originX: defaults.double(forKey: Keys.panelOriginX),
                originY: defaults.double(forKey: Keys.panelOriginY)
            )
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            if let newValue {
                defaults.set(newValue.originX, forKey: Keys.panelOriginX)
                defaults.set(newValue.originY, forKey: Keys.panelOriginY)
            } else {
                defaults.removeObject(forKey: Keys.panelOriginX)
                defaults.removeObject(forKey: Keys.panelOriginY)
            }
        }
    }

    public func save() {
        let current = settings
        lock.lock()
        defaults.set(current.pomoPomoDurationMinutes, forKey: Keys.pomoPomoDuration)
        defaults.set(current.breakDurationMinutes, forKey: Keys.breakDuration)
        defaults.set(current.autoStart, forKey: Keys.autoStart)
        defaults.set(current.completedPomodorosInCycle, forKey: Keys.completedPomodoros)
        lock.unlock()
    }

    private func registerDefaultsIfNeeded() {
        if defaults.object(forKey: Keys.pomoPomoDuration) == nil {
            defaults.register(defaults: [
                Keys.pomoPomoDuration: 50,
                Keys.breakDuration: 5,
                Keys.autoStart: false,
                Keys.completedPomodoros: 0,
            ])
        }
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}
