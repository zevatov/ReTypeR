import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var toastWindow: NSWindow?
    private var toastTimer: Timer?
    
    @MainActor
    func showSettings() {
        if let window = settingsWindow {
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ReTypeR Настройки"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        
        // Custom background and styling
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .visible
        
        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Handle window close
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    @objc private func settingsWindowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
    
    @MainActor
    func showOnboarding() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let onboardingView = OnboardingView()
        let hostingView = NSHostingView(rootView: onboardingView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Универсальный доступ"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        
        self.onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onboardingWindowWillClose),
            name: NSWindow.willCloseNotification,
            object: window
        )
    }
    
    @MainActor
    func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
    
    @objc private func onboardingWindowWillClose(notification: Notification) {
        if let window = notification.object as? NSWindow, window == onboardingWindow {
            onboardingWindow = nil
        }
    }
    
    @MainActor
    func showToast(original: String, converted: String) {
        toastTimer?.invalidate()
        toastWindow?.close()
        
        let toastView = ConversionToast(original: original, converted: converted)
        let hostingView = NSHostingView(rootView: toastView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 56)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        
        // Position toast at bottom-center of the main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.size.width - 320) / 2
            let y = screenRect.origin.y + 40 // 40pt above dock/bottom
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        self.toastWindow = panel
        
        // Fade in
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1.0
        }
        
        // Automatically hide after 1.5 seconds
        toastTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.hideToast()
            }
        }
    }
    
    @MainActor
    private func hideToast() {
        guard let panel = toastWindow else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.35
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.close()
            if self.toastWindow == panel {
                self.toastWindow = nil
            }
        })
    }
}
