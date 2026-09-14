import Foundation
import ServiceManagement
import Combine

/// Manages the "launch at login" toggle via SMAppService (macOS 13+).
class LaunchManager: ObservableObject {
    static let shared = LaunchManager()

    @Published var isLaunchAtLoginEnabled: Bool = false

    private init() {
        isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        setupDefaultLaunchAtLogin()
    }

    /// First-run convenience: register launch-at-login once, silently.
    private func setupDefaultLaunchAtLogin() {
        let key = "hasSetDefaultLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        guard SMAppService.mainApp.status == .notRegistered else { return }
        do {
            try SMAppService.mainApp.register()
            isLaunchAtLoginEnabled = true
        } catch {
            NSLog("Failed to toggle launch at login: \(error.localizedDescription)")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isLaunchAtLoginEnabled = enabled
        } catch {
            NSLog("Failed to toggle launch at login: \(error.localizedDescription)")
            isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
