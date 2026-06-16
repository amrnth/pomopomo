import Foundation
import Testing
@testable import PomodoroKit

struct SettingsStoreTests {
    private func makeStore() -> (SettingsStore, UserDefaults, String) {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(defaults: defaults), defaults, suiteName)
    }

    @Test func roundTripPersistsSettings() {
        let (store, defaults, _) = makeStore()

        var settings = store.settings
        settings.pomoPomoDurationMinutes = 30
        settings.breakDurationMinutes = 15
        settings.autoStart = true
        settings.completedPomodorosInCycle = 2
        store.settings = settings
        store.save()

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.settings == settings)
        #expect(defaults.integer(forKey: "pomoPomoDurationMinutes") == 30)
        #expect(defaults.integer(forKey: "breakDurationMinutes") == 15)
        #expect(defaults.bool(forKey: "autoStart") == true)
        #expect(defaults.integer(forKey: "completedPomodorosInCycle") == 2)
    }

    @Test func defaultsUseFiftyMinutePomoPomo() {
        let (store, _, _) = makeStore()
        #expect(store.settings.pomoPomoDurationMinutes == 50)
        #expect(store.settings.breakDurationMinutes == 5)
        #expect(store.settings.autoStart == false)
        #expect(store.settings.completedPomodorosInCycle == 0)
    }
}
