import Cocoa
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check Accessibility permission on startup
        PermissionsManager.shared.checkAccessibility()
        
        // If not granted, present the Onboarding View to guide the user
        if !PermissionsManager.shared.isAccessibilityGranted {
            DispatchQueue.main.async {
                WindowManager.shared.showOnboarding()
            }
        }
        
        // Setup hotkey listener when accessibility permission is granted
        PermissionsManager.shared.$isAccessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { isGranted in
                if isGranted {
                    HotkeyManager.shared.setup()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to conversion events to present the overlay Toast
        ConversionEngine.shared.conversionCompletedPublisher
            .receive(on: DispatchQueue.main)
            .sink { original, converted in
                WindowManager.shared.showToast(original: original, converted: converted)
            }
            .store(in: &cancellables)
    }
}
