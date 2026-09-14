import Cocoa
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var statusTimer: Timer?
    
    var statusItem: NSStatusItem!
    private var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (menu-bar only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Build initial keyboard layout mapping
        PreferencesManager.shared.updateMapping()
        
        // Setup status item in system menu bar
        setupStatusItem()
        
        // Check Accessibility permission on startup
        PermissionsManager.shared.checkAccessibility()
        
        // If not granted, present the Onboarding View to guide the user
        if !PermissionsManager.shared.isAccessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                WindowManager.shared.showOnboarding()
            }
        } else {
            // Show brief welcoming toast so user immediately sees that ReTypeR has launched in the menu bar
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.3"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                WindowManager.shared.showInfoToast(message: "ReTypeR \(version) запущен в строке меню")
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
            
        // Reactively update menu bar status icon on permission changes
        PermissionsManager.shared.$isAccessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        // Periodic heartbeat to refresh icon and detect permission/theme changes (identical to SingAR)
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        togglePopover()
        return true
    }

    deinit {
        statusTimer?.invalidate()
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
    
    func setupStatusItem() {
        // Clean up stale position artifacts from old releases
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position ReTypeRStatusItem")
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Path ReTypeRStatusItem")
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position ReTypeR")

        // Guarantee placement in safe third-party status bar area (to the left of system Clock/Control Center)
        let prefKey = "NSStatusItem Preferred Position Item-0"
        let currentPos = UserDefaults.standard.double(forKey: prefKey)
        // System items (Clock, Control Center, Battery, WiFi) take up the rightmost ~380pt.
        // Positions < 400 collide with the Clock; positions > 1800 are stale absolute coordinates from multi-monitor setups.
        if currentPos < 400 || currentPos > 1800 {
            UserDefaults.standard.set(620.0, forKey: prefKey)
            UserDefaults.standard.synchronize()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
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
        if let popover, popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            showPopover(button)
        }
    }

    func showPopover(_ sender: NSStatusBarButton) {
        closePopover()

        let pop = NSPopover()
        // SingAR compact width: 290pt
        pop.contentSize = NSSize(width: 290, height: 380)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(rootView: MenuBarView())
        self.popover = pop

        NSApp.activate(ignoringOtherApps: true)
        pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        sender.window?.makeKey()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        popover = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
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
        alert.informativeText = "Вы действительно хотите выйти из ReTypeR?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Выйти")
        alert.addButton(withTitle: "Отмена")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
    
    func updateStatusIcon() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let button = self.statusItem?.button else { return }
            
            let isEnabled = PreferencesManager.shared.isAppEnabled
            let isGranted = PermissionsManager.shared.isAccessibilityGranted
            
            // 1. Determine Status Dot Color
            let dotColor: NSColor
            if !isEnabled {
                dotColor = .systemRed       // 🔴 Paused
            } else if !isGranted {
                dotColor = .systemOrange    // 🟡 Missing permissions
            } else {
                dotColor = .systemGreen     // 🟢 Active & Ready
            }
            
            // 2. Keyboard Glyph Styling with dynamic dark/light appearance resolution
            let isDark = (UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark")
                || (button.window?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
                || (NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
            let baseColor: NSColor = isDark ? .white : NSColor(white: 0.1, alpha: 1.0)
            let activeColor = isEnabled ? baseColor : NSColor(white: 0.5, alpha: 1.0)

            let symbolName = "keyboard"
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let colorConfig = NSImage.SymbolConfiguration(paletteColors: [activeColor])
            let finalConfig = config.applying(colorConfig)

            guard let glyph = NSImage(systemSymbolName: symbolName, accessibilityDescription: "ReTypeR")?
                .withSymbolConfiguration(finalConfig) else { return }

            let totalWidth: CGFloat = 28
            let totalHeight: CGFloat = 18

            let combinedImage = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
                let glyphRect = NSRect(
                    x: 0,
                    y: (totalHeight - glyph.size.height) / 2,
                    width: glyph.size.width,
                    height: glyph.size.height
                )
                glyph.draw(in: glyphRect)

                // Draw Status Circle Dot on the right (🟢/🟡/🔴)
                let dotSize: CGFloat = 6.0
                let dotRect = NSRect(
                    x: totalWidth - dotSize - 1,
                    y: (totalHeight - dotSize) / 2,
                    width: dotSize,
                    height: dotSize
                )
                let path = NSBezierPath(ovalIn: dotRect)
                dotColor.setFill()
                path.fill()

                return true
            }
            
            button.image = combinedImage
            button.toolTip = isEnabled ? (isGranted ? "ReTypeR: Работает" : "ReTypeR: Требуются разрешения") : "ReTypeR: На паузе"
        }
    }
}
