import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let convertText = Self("convertText", default: .init(.space, modifiers: [.control, .shift]))
}

class HotkeyManager {
    static let shared = HotkeyManager()
    private var isSetup = false
    
    func setup() {
        guard !isSetup else { return }
        isSetup = true
        KeyboardShortcuts.onKeyUp(for: .convertText) {
            ConversionEngine.shared.convertSelectedText()
        }
    }
}
