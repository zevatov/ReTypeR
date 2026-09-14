import SwiftUI

/// App entry point. The real UI is the menu-bar status item owned by
/// `AppDelegate`; the SwiftUI scene body stays empty (LSUIElement app).
@main
struct ReTypeRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        PreferencesManager.shared.updateMapping()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
