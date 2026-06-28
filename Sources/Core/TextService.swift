import Foundation
import AppKit
import ApplicationServices

class TextService {
    static let shared = TextService()
    
    /// Retrieves the currently selected text, trying Accessibility API first, falling back to Clipboard.
    func getSelectedText(completion: @escaping (String?) -> Void) {
        if let axText = getSelectedTextViaAccessibility() {
            completion(axText)
            return
        }
        
        // Fallback: Clipboard
        getSelectedTextViaClipboard(completion: completion)
    }
    
    /// Selects all text by simulating Cmd+A
    func selectAllText(completion: @escaping () -> Void) {
        simulateKeyPress(virtualKey: 0x00, flags: .maskCommand) // 0x00 is 'A'
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            completion()
        }
    }
    
    /// Replaces the selected text by putting new text in clipboard and pasting it.
    func replaceSelectedText(with newText: String) {
        let pasteboard = NSPasteboard.general
        
        // 1. Save existing clipboard items
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [String: Data] in
            var typeData: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typeData[type.rawValue] = data
                }
            }
            return typeData
        } ?? []
        
        // 2. Set new content
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        
        // 3. Simulate Cmd+V to paste
        simulateKeyPress(virtualKey: 0x09, flags: .maskCommand) // 0x09 is 'V'
        
        // 4. Restore original clipboard after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            for itemData in savedItems {
                let newItem = NSPasteboardItem()
                for (type, data) in itemData {
                    newItem.setData(data, forType: NSPasteboard.PasteboardType(type))
                }
                pasteboard.writeObjects([newItem])
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getSelectedTextViaAccessibility() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()
        
        var focusedElementValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue)
        
        guard result == .success, let val = focusedElementValue else {
            return nil
        }
        let focusedElement = val as! AXUIElement
        
        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if textResult == .success, let selectedText = selectedTextValue as? String, !selectedText.isEmpty {
            return selectedText
        }
        
        return nil
    }
    
    private func getSelectedTextViaClipboard(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [String: Data] in
            var typeData: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    typeData[type.rawValue] = data
                }
            }
            return typeData
        } ?? []
        
        pasteboard.clearContents()
        
        // Simulate Cmd+C to copy
        simulateKeyPress(virtualKey: 0x08, flags: .maskCommand) // 0x08 is 'C'
        
        // Give the target app a moment to write to the clipboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let copiedText = pasteboard.string(forType: .string)
            
            // Restore clipboard
            pasteboard.clearContents()
            for itemData in savedItems {
                let newItem = NSPasteboardItem()
                for (type, data) in itemData {
                    newItem.setData(data, forType: NSPasteboard.PasteboardType(type))
                }
                pasteboard.writeObjects([newItem])
            }
            
            completion(copiedText)
        }
    }
    
    private func simulateKeyPress(virtualKey: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        
        keyDown?.flags = flags
        keyUp?.flags = flags
        
        let loc = CGEventTapLocation.cghidEventTap
        keyDown?.post(tap: loc)
        keyUp?.post(tap: loc)
    }
}
