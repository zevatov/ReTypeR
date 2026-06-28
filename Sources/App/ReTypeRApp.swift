import SwiftUI

@main
struct ReTypeRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Build initial mapping
        PreferencesManager.shared.updateMapping()
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
