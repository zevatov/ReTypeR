import Foundation
import ApplicationServices
import AppKit

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()
    
    @Published var isAccessibilityGranted: Bool = false
    
    /// Polls AX trust state at runtime to detect permission revocation
    /// (C-04/FUN-2). Started lazily after the first confirmed grant so we
    /// never spam checks during onboarding.
    private var accessibilityMonitorTimer: Timer?
    
    init() {
        checkAccessibility()
    }
    
    func checkAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        self.isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
        updateAccessibilityMonitor()
    }
    
    // MARK: - Accessibility revocation monitor (C-04/FUN-2)
    
    /// Starts the monitor once (and only once) after the first confirmed
    /// grant; afterwards the timer keeps detecting granted <-> revoked
    /// transitions and shows exactly one toast per transition.
    private func updateAccessibilityMonitor() {
        guard isAccessibilityGranted else { return }
        guard accessibilityMonitorTimer == nil else { return }
        
        let timer = Timer(timeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollAccessibilityTrust()
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityMonitorTimer = timer
    }
    
    private func pollAccessibilityTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        
        guard granted != isAccessibilityGranted else { return }
        
        isAccessibilityGranted = granted
        
        // One toast per state transition (C-04/FUN-2): revoked -> inform the
        // user conversion stopped working; re-granted -> confirm recovery.
        let message = granted
            ? "Доступ Универсального доступа восстановлен"
            : "Доступ Универсального доступа отключён — конвертация не работает"
        Task { @MainActor in
            WindowManager.shared.showInfoToast(message: message)
        }
    }
    
    deinit {
        accessibilityMonitorTimer?.invalidate()
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
    
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
