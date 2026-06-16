import AppKit
import ServiceManagement

public enum LaunchAtLogin {
    public static func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Unsigned dev builds may fail; see README LaunchAgent fallback.
        }
    }
}
