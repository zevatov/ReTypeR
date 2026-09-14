import Foundation
import AppKit
import ApplicationServices

/// Reads and replaces the selected text of the frontmost application.
///
/// Primary path: Accessibility API (AXSelectedText / AXSelectedTextRange).
/// Fallback path: clipboard round-trip with save/restore of the previous
/// pasteboard contents (used by apps that expose no AX text attributes).
class TextService {
    static let shared = TextService()

    private let systemWideElement = AXUIElementCreateSystemWide()
    private let operationTimeout: TimeInterval = 1.0
    /// Text captured during the last successful AX read; used to verify
    /// the selection has not changed before replacing it.
    private var lastAXSelectedText: String?

    // MARK: - Public API

    func selectAllText(completion: @escaping () -> Void) {
        simulateKeyPress(.selectAll) // Cmd+A
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            completion()
        }
    }

    func getSelectedText(completion: @escaping (String?) -> Void) {
        if let text = getSelectedTextViaAccessibility() {
            lastAXSelectedText = text
            completion(text)
            return
        }
        // Selection was not readable via AX; the re-check in
        // replaceSelectedText is skipped for this round.
        lastAXSelectedText = nil
        getSelectedTextViaClipboard(completion: completion)
    }

    func replaceSelectedText(with newText: String) {
        // Silent guard: if the selection changed since it was read,
        // cancel the replacement without dialogs to keep the focus.
        if let expected = lastAXSelectedText,
           let current = getSelectedTextViaAccessibility(),
           current != expected {
            return
        }
        if setAXSelectedText(newText) { return }
        pasteText(newText)
    }

    // MARK: - Accessibility path

    /// MED-5: bounds the synchronous AX messaging of a specific element to
    /// `operationTimeout` seconds (the system default is 6 s). Applied right
    /// before every Copy/Set round-trip so a hung target app can never stall
    /// the main thread longer than the pasteboard polling budget.
    @discardableResult
    private func applyMessagingTimeout(to element: AXUIElement) -> AXError {
        AXUIElementSetMessagingTimeout(element, Float(operationTimeout))
    }

    private func focusedElement() -> AXUIElement? {
        applyMessagingTimeout(to: systemWideElement)
        var element: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &element)
        guard result == .success, let app = element else { return nil }

        let appElement = app as! AXUIElement
        applyMessagingTimeout(to: appElement)
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused else { return nil }
        let resolvedElement = focusedElement as! AXUIElement
        applyMessagingTimeout(to: resolvedElement)
        return resolvedElement
    }

    private func getSelectedTextViaAccessibility() -> String? {
        guard let element = focusedElement() else { return nil }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard result == .success, let selected = value as? String else { return nil }
        return selected
    }

    private func setAXSelectedText(_ text: String) -> Bool {
        guard let element = focusedElement() else { return false }

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    // MARK: - Clipboard fallback

    private func getSelectedTextViaClipboard(completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Save full pasteboard state to restore it afterwards.
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types ?? [] {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString("", forType: .string)

        // Baseline AFTER our own clearContents so the poll below detects
        // the app's copy writing to the pasteboard, not our clear (C-03).
        let baselineCount = pasteboard.changeCount

        simulateKeyPress(.copy) // Cmd+C

        // Poll for the copy to land instead of a fixed delay (C-03/FUN-3).
        waitForPasteboardChange(originalCount: baselineCount, pasteboard: pasteboard) { [weak self] landed in
            guard let self = self else { return }
            // Landed → read the copied text: "" = empty selection,
            // nil would mean the app wrote nothing readable (C-07).
            // Timed out → the copy never landed: treat as failure (nil).
            let copied = landed ? pasteboard.string(forType: .string) : nil
            self.restorePasteboard(pasteboard, savedItems: savedItems, previousContents: previousContents)
            completion(copied)
        }
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Save full pasteboard state (images/files/RTFD included) so it can
        // be restored after the paste — same mechanism as the read path.
        let savedItems: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types ?? [] {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateKeyPress(.paste) // Cmd+V

        // MED-6 fix: Cmd+V makes the target app READ the pasteboard — it
        // almost never writes, so `changeCount` never moves and polling it
        // would skip the restore forever (converted text left in clipboard).
        // A grace delay is the reliable trigger: the app processes the
        // synthetic keypress within milliseconds, then the original
        // clipboard state is restored.
        let pasteGraceDelay: TimeInterval = 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + pasteGraceDelay) { [weak self] in
            self?.restorePasteboard(pasteboard, savedItems: savedItems, previousContents: previousContents)
        }
    }

    // MARK: - Pasteboard polling

    /// Polls `pasteboard.changeCount` every ~25 ms until it changes or
    /// `operationTimeout` elapses. Reschedules itself on the main queue via
    /// `asyncAfter` — never blocks the thread with a sleep.
    private func waitForPasteboardChange(
        originalCount: Int,
        pasteboard: NSPasteboard,
        elapsed: TimeInterval = 0,
        pollResult: @escaping (Bool) -> Void
    ) {
        if pasteboard.changeCount != originalCount {
            pollResult(true)
            return
        }
        if elapsed >= operationTimeout {
            pollResult(false)
            return
        }
        let step: TimeInterval = 0.025
        DispatchQueue.main.asyncAfter(deadline: .now() + step) { [weak self] in
            self?.waitForPasteboardChange(
                originalCount: originalCount,
                pasteboard: pasteboard,
                elapsed: elapsed + step,
                pollResult: pollResult
            )
        }
    }

    /// Restores the previously saved pasteboard state. When the pasteboard
    /// had no items and no string before the operation, `clearContents()`
    /// restores that emptiness so the converted text is not left in the
    /// clipboard forever (MED-6).
    private func restorePasteboard(
        _ pasteboard: NSPasteboard,
        savedItems: [[NSPasteboard.PasteboardType: Data]],
        previousContents: String?
    ) {
        pasteboard.clearContents()
        if !savedItems.isEmpty {
            for savedEntry in savedItems {
                let pbItem = NSPasteboardItem()
                for (type, data) in savedEntry {
                    pbItem.setData(data, forType: type)
                }
                pasteboard.writeObjects([pbItem])
            }
        } else if let previousContents = previousContents {
            pasteboard.setString(previousContents, forType: .string)
        } else {
            // The pasteboard was empty before the operation: keep it empty.
            pasteboard.clearContents()
        }
    }

    // MARK: - Key events

    /// HID virtual key codes + modifier flags for the synthetic system
    /// shortcuts. Values are pinned to HIToolbox `Events.h`:
    /// `kVK_ANSI_A = 0x00`, `kVK_ANSI_C = 0x08`, `kVK_ANSI_V = 0x09`.
    /// Internal and pure so unit tests can verify the mapping without
    /// posting real events (regression guard for the v1.3 "bare v" bug:
    /// the clipboard-fallback copy posted kVK_ANSI_V with no modifiers).
    enum SyntheticKey {
        case selectAll
        case copy
        case paste

        var virtualKey: UInt16 {
            switch self {
            case .selectAll: return 0x00 // kVK_ANSI_A
            case .copy: return 0x08      // kVK_ANSI_C
            case .paste: return 0x09     // kVK_ANSI_V
            }
        }

        var flags: CGEventFlags {
            .maskCommand
        }
    }

    private func simulateKeyPress(_ key: SyntheticKey) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key.virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key.virtualKey, keyDown: false) else {
            return
        }
        keyDown.flags = key.flags
        keyUp.flags = key.flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
