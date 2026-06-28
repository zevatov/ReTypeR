import Foundation
import ServiceManagement

class LaunchManager: ObservableObject {
    static let shared = LaunchManager()
    
    @Published var isLaunchAtLoginEnabled: Bool = false
    
    init() {
        self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        setupDefaultLaunchAtLogin()
    }
    
    private func setupDefaultLaunchAtLogin() {
        let key = "hasSetDefaultLaunchAtLogin"
        if !UserDefaults.standard.bool(forKey: key) {
            setLaunchAtLogin(true)
            UserDefaults.standard.set(true, forKey: key)
        }
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            self.isLaunchAtLoginEnabled = enabled
        } catch {
            print("Failed to toggle launch at login: \(error)")
            // Revert on failure
            self.isLaunchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}
