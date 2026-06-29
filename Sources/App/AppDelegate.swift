import Cocoa
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check Accessibility permission on startup
        PermissionsManager.shared.checkAccessibility()
        
        // If not granted, present the Onboarding View to guide the user
        if !PermissionsManager.shared.isAccessibilityGranted {
            DispatchQueue.main.async {
                WindowManager.shared.showOnboarding()
            }
        }
        
        // Setup status item manually for left/right click distinction
        setupStatusItem()
        
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
            
        // Reactively update menu bar status icon on settings changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
            
        // Reactively update menu bar status icon on permission changes
        PermissionsManager.shared.$isAccessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        popover = NSPopover()
        // Allow popover size to adapt or be fixed
        popover.contentSize = NSSize(width: 250, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
        
        updateStatusIcon()
    }
    
    @objc func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showRightClickMenu()
        } else {
            togglePopover()
        }
    }
    
    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func showRightClickMenu() {
        let menu = NSMenu()
        
        let settingsItem = NSMenuItem(title: "Настройки...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Выйти", action: #selector(terminateApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        if let button = statusItem.button {
            let pt = NSPoint(x: 0, y: button.bounds.height)
            menu.popUp(positioning: nil, at: pt, in: button)
        }
    }
    
    @objc func openSettings() {
        Task { @MainActor in
            WindowManager.shared.showSettings()
        }
    }
    
    @objc func terminateApp() {
        confirmExit()
    }
    
    func confirmExit() {
        let alert = NSAlert()
        alert.messageText = "Выход"
        alert.informativeText = "Вы действительно хотите выйти из приложения?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Выйти")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
    
    func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        
        let isEnabled = PreferencesManager.shared.isAppEnabled
        let isGranted = PermissionsManager.shared.isAccessibilityGranted
        
        let statusColor: NSColor
        if !isEnabled {
            statusColor = .systemRed
        } else if !isGranted {
            statusColor = .systemOrange
        } else {
            statusColor = .systemGreen
        }
        
        let baseImage = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "ReTypeR") ?? NSImage()
        let size = NSSize(width: 22, height: 18)
        let compositeImage = NSImage(size: size, flipped: false) { rect in
            NSColor.white.set()
            
            let keyboardSize = NSSize(width: 17, height: 11)
            let keyboardRect = NSRect(
                x: 0,
                y: (rect.height - keyboardSize.height) / 2,
                width: keyboardSize.width,
                height: keyboardSize.height
            )
            baseImage.draw(in: keyboardRect)
            
            // Draw the status dot in the bottom right corner with a tiny gap
            let dotRadius: CGFloat = 2.5
            let dotRect = NSRect(
                x: rect.width - dotRadius * 2,
                y: 1,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            
            // Draw a stroke/background under the dot for high contrast in all themes
            let strokePath = NSBezierPath(ovalIn: dotRect.insetBy(dx: -0.75, dy: -0.75))
            NSColor.windowBackgroundColor.set()
            strokePath.fill()
            
            let path = NSBezierPath(ovalIn: dotRect)
            statusColor.set()
            path.fill()
            
            return true
        }
        
        compositeImage.isTemplate = false
        button.image = compositeImage
    }
}
