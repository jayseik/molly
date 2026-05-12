import Foundation
import ServiceManagement

enum LaunchRegistration {
    /// Registers Molly as login item helper when supported (macOS 13+ SMAppService).
    @MainActor static func apply(_ enabled: Bool) throws {
        guard #available(macOS 13, *) else {
            throw NSError(domain: "Molly", code: 1, userInfo: [NSLocalizedDescriptionKey: "Launch at login requires macOS 13+"])
        }

        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
        }

        UserDefaults.standard.set(enabled, forKey: MollyPreferenceKeys.launchAtLogin)
    }

    @MainActor static func readSystemFlag() -> Bool {
        guard #available(macOS 13, *) else {
            return UserDefaults.standard.bool(forKey: MollyPreferenceKeys.launchAtLogin)
        }
        return SMAppService.mainApp.status == .enabled
    }
}
