import SwiftUI

@main
struct ReTypeRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Build initial mapping
        PreferencesManager.shared.updateMapping()
    }
    
    var body: some Scene {
        MenuBarExtra("ReTypeR", systemImage: "keyboard.badge.ellipsis") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
