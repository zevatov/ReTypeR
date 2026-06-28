import Foundation
import ApplicationServices
import AppKit

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var isAccessibilityGranted: Bool = false
    
    init() {
        checkAccessibility()
    }
    
    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        self.isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }
    
    func requestAccessibility() {
        let key = "hasPromptedAccessibility"
        let hasPrompted = UserDefaults.standard.bool(forKey: key)
        
        NSLog("[PermissionsManager] requestAccessibility called. hasPrompted: \(hasPrompted)")
        
        if !hasPrompted {
            // First time: only trigger the native macOS dialog so it doesn't get covered by System Settings window.
            // The native dialog itself has a button to open System Settings.
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
            let _ = AXIsProcessTrustedWithOptions(options)
            UserDefaults.standard.set(true, forKey: key)
        } else {
            // Subsequent times: since the native dialog won't pop up again, open Settings directly.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
