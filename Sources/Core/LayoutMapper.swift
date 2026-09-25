import Foundation
import Carbon
import AppKit

struct KeyboardLayoutInfo: Identifiable, Hashable {
    let id: String
    let localizedName: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

class LayoutMapper {
    static let shared = LayoutMapper()
    
    private var availableLayouts: [TISInputSource] = []
    
    // Mapping dictionaries
    var aToBMap: [Character: Character] = [:]
    var bToAMap: [Character: Character] = [:]
    
    init() {
        refreshAvailableLayouts()
    }
    
    func refreshAvailableLayouts() {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout as Any
        ]
        
        guard let sourceList = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }
        
        self.availableLayouts = sourceList
    }
    
    func getInstalledLayouts() -> [KeyboardLayoutInfo] {
        return availableLayouts.compactMap { source in
            guard let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
                  let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
                return nil
            }
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            return KeyboardLayoutInfo(id: id, localizedName: name)
        }
    }
    
    func buildBidirectionalMap(layoutAID: String, layoutBID: String) {
        if availableLayouts.isEmpty {
            refreshAvailableLayouts()
        }
        
        let sourceA = findLayout(for: layoutAID)
        let sourceB = findLayout(for: layoutBID)
        let resolvedDataA = sourceA.flatMap { getKeyboardLayoutData(from: $0) }
        let resolvedDataB = sourceB.flatMap { getKeyboardLayoutData(from: $0) }
        
        guard let dataA = resolvedDataA, let dataB = resolvedDataB else {
            applyHardcodedFallbackOrClear(
                layoutAID: layoutAID,
                layoutBID: layoutBID,
                sourcesMissing: sourceA == nil || sourceB == nil
            )
            return
        }
        
        var aToB: [Character: Character] = [:]
        var bToA: [Character: Character] = [:]
        
        let modifierStates: [UInt32] = [
            0, // none
            UInt32(shiftKey >> 8) & 0xFF // shift
        ]
        
        // Printable keycodes based on standard ANSI layout
        let printableKeyCodes: [UInt16] = [
            0x00, 0x0B, 0x08, 0x02, 0x0E, 0x03, 0x05, 0x04, 0x22, 0x26, 0x28, 0x25,
            0x2E, 0x2D, 0x1F, 0x23, 0x0C, 0x0F, 0x01, 0x11, 0x20, 0x09, 0x0D, 0x07,
            0x10, 0x06, 0x1D, 0x12, 0x13, 0x14, 0x15, 0x17, 0x16, 0x1A, 0x1C, 0x19,
            0x1B, 0x18, 0x21, 0x1E, 0x29, 0x27, 0x2B, 0x2F, 0x2C, 0x2A, 0x32
        ]
        
        for keyCode in printableKeyCodes {
            for modifier in modifierStates {
                guard let charA = characterForKeyCode(keyCode, modifiers: modifier, keyboardLayout: dataA)?.first,
                      let charB = characterForKeyCode(keyCode, modifiers: modifier, keyboardLayout: dataB)?.first else {
                    continue
                }
                
                // Skip control characters
                guard let scalarA = charA.unicodeScalars.first, scalarA.value >= 32 else { continue }
                
                if charA != charB {
                    // Only map if at least one character is a letter,
                    // to prevent mapping punctuation to other punctuation (like , to ^)
                    if charA.isLetter || charB.isLetter {
                        aToB[charA] = charB
                        bToA[charB] = charA
                    }
                }
            }
        }
        
        self.aToBMap = aToB
        self.bToAMap = bToA
        NSLog("[LayoutMapper] Built bidirectional map with %d entries between %@ and %@", aToB.count, layoutAID, layoutBID)
    }
    
    // Auto-detection based on character frequencies
    func convert(_ text: String) -> String {
        return convert(text, smart: PreferencesManager.shared.isSmartRecognitionEnabled)
    }
    
    func convert(_ text: String, smart: Bool) -> String {
        return convertDetailed(text, smart: smart).text
    }
    
    /// Legacy signature preserved for compatibility (v1.3 §1.8):
    /// hotkey path defaults to `.hotkey` source.
    func convert(_ text: String, smart: Bool = true, source: ConversionSource) -> String {
        return convertDetailed(text, smart: smart, source: source).text
    }
    
    /// Full result adapter (v1.3 §1.8): exposes the scorer's decision so the
    /// engine can switch layouts by OUTPUT dominance instead of counting input.
    func convertDetailed(
        _ text: String,
        smart: Bool = true,
        source: ConversionSource = .hotkey
    ) -> ConversionResult {
        if aToBMap.isEmpty || bToAMap.isEmpty {
            PreferencesManager.shared.updateMapping()
        }

        guard smart else {
            let basic = convertBasic(text)
            // Basic mode has no per-token analysis; report no dominant script.
            return ConversionResult(text: basic, dominantSourceScript: nil, changed: basic != text)
        }
        
        let langA = LayoutMapper.languageCode(for: PreferencesManager.shared.primaryLayoutID)
        let langB = LayoutMapper.languageCode(for: PreferencesManager.shared.secondaryLayoutID)
        
        return SmartScorer.shared.convert(
            text,
            aToB: aToBMap,
            bToA: bToAMap,
            languageA: langA,
            languageB: langB,
            source: source,
            tieBreakerAToB: { [weak self] in self?.tieBreakPrefersAToB() ?? false }
        )
    }
    
    private func convertBasic(_ text: String) -> String {
        if aToBMap.isEmpty || bToAMap.isEmpty {
            PreferencesManager.shared.updateMapping()
        }

        let countA = text.filter { aToBMap.keys.contains($0) }.count
        let countB = text.filter { bToAMap.keys.contains($0) }.count
        
        if countA != countB {
            if countA > countB {
                return String(text.map { aToBMap[$0] ?? $0 })
            } else {
                return String(text.map { bToAMap[$0] ?? $0 })
            }
        } else {
            // Tie-breaker: use active keyboard layout
            if let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
               let currentID = getLayoutID(for: currentSource) {
                // If currently active layout is primary (A), convert A -> B
                if currentID == PreferencesManager.shared.primaryLayoutID {
                    return String(text.map { aToBMap[$0] ?? $0 })
                } else {
                    return String(text.map { bToAMap[$0] ?? $0 })
                }
            }
            // Default fallback
            return String(text.map { bToAMap[$0] ?? $0 })
        }
    }
    
    /// A-07/MED-3: single source of truth for layout ID → language code.
    /// Internal static so ConversionEngine resolves the same code the scorer
    /// sees (de/fr/es included); the private duplicate in ConversionEngine
    /// was removed.
    static func languageCode(for layoutID: String) -> String {
        let lower = layoutID.lowercased()
        // Full layout names first: short substrings must not shadow them
        // («fr-EN-ch» contains "en", «r-USS-ian» contains "us").
        if lower.contains("russian") { return "ru" }
        if lower.contains("ukrainian") { return "uk" }
        if lower.contains("german") { return "de" }
        if lower.contains("french") { return "fr" }
        if lower.contains("spanish") { return "es" }
        if lower.contains("us") || lower.contains("english") || lower.contains("abc") { return "en" }
        // Two-letter codes as a fallback for third-party layout IDs.
        if lower.contains("ru") { return "ru" }
        if lower.contains("uk") { return "uk" }
        if lower.contains("de") { return "de" }
        if lower.contains("fr") { return "fr" }
        if lower.contains("es") { return "es" }
        if lower.contains("en") { return "en" }
        return "en"
    }
    
    /// Tie-breaker for ambiguous conversions: use the active keyboard layout,
    /// mirroring convertBasic behavior.
    private func tieBreakPrefersAToB() -> Bool {
        if let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
           let currentID = getLayoutID(for: currentSource) {
            return currentID == PreferencesManager.shared.primaryLayoutID
        }
        return false
    }
    
    func switchToLayout(id: String) {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceID: id as CFString
        ]
        guard let list = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first else {
            return
        }
        TISSelectInputSource(source)
    }
    
    /// US ABC ↔ Mac Russian (ЙЦУКЕН), lower + upper. Digits and identical
    /// punctuation are omitted: only pairs that differ and include a letter.
    private static let fallbackUStoRU: [Character: Character] = [
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
        "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д", ";": "ж", "'": "э",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь", ",": "б", ".": "ю", "`": "ё",
        "Q": "Й", "W": "Ц", "E": "У", "R": "К", "T": "Е", "Y": "Н", "U": "Г", "I": "Ш", "O": "Щ", "P": "З", "{": "Х", "}": "Ъ",
        "A": "Ф", "S": "Ы", "D": "В", "F": "А", "G": "П", "H": "Р", "J": "О", "K": "Л", "L": "Д", ":": "Ж", "\"": "Э",
        "Z": "Я", "X": "Ч", "C": "С", "V": "М", "B": "И", "N": "Т", "M": "Ь", "<": "Б", ">": "Ю", "~": "Ё"
    ]
    
    // MARK: - Private Helpers
    
    private func applyHardcodedFallbackOrClear(layoutAID: String, layoutBID: String, sourcesMissing: Bool) {
        if Self.isHardcodedUSRussianPair(layoutAID, layoutBID) {
            let usToRU = Self.fallbackUStoRU
            let ruToUS = Dictionary(uniqueKeysWithValues: usToRU.map { ($0.value, $0.key) })
            if Self.isUSABCLayout(layoutAID) {
                aToBMap = usToRU
                bToAMap = ruToUS
            } else {
                aToBMap = ruToUS
                bToAMap = usToRU
            }
            NSLog("[LayoutMapper] Using hardcoded fallback map (TIS API unavailable in headless environment)")
            NSLog("[LayoutMapper] Built bidirectional map with %d entries between %@ and %@", aToBMap.count, layoutAID, layoutBID)
            return
        }
        
        self.aToBMap = [:]
        self.bToAMap = [:]
        if sourcesMissing {
            NSLog("[LayoutMapper] Failed to find layout sources for %@ or %@", layoutAID, layoutBID)
        } else {
            NSLog("[LayoutMapper] Failed to get keyboard layout data for %@ or %@", layoutAID, layoutBID)
        }
    }
    
    private static func isHardcodedUSRussianPair(_ layoutAID: String, _ layoutBID: String) -> Bool {
        let aIsUS = isUSABCLayout(layoutAID)
        let bIsUS = isUSABCLayout(layoutBID)
        let aIsRU = isMacRussianLayout(layoutAID)
        let bIsRU = isMacRussianLayout(layoutBID)
        return (aIsUS && bIsRU) || (aIsRU && bIsUS)
    }
    
    /// ABC, `.US`, and `com.apple.keylayout.US`. Bare "us" is intentionally
    /// not matched: it is a substring of "Russian".
    private static func isUSABCLayout(_ id: String) -> Bool {
        let lower = id.lowercased()
        return lower.contains("abc") || lower.contains(".us") || lower == "com.apple.keylayout.us"
    }
    
    /// Mac Russian. `RussianWin` also matches: the Win suffix is not required.
    private static func isMacRussianLayout(_ id: String) -> Bool {
        id.lowercased().contains("russian")
    }
    
    private func findLayout(for id: String) -> TISInputSource? {
        if let exact = availableLayouts.first(where: { getLayoutID(for: $0) == id }) {
            return exact
        }
        let lower = id.lowercased()
        if lower.contains("us") || lower.contains("abc") || lower.contains("en") {
            if let match = availableLayouts.first(where: {
                guard let sid = getLayoutID(for: $0)?.lowercased() else { return false }
                return sid.contains("abc") || sid.contains("us") || sid.contains("en")
            }) {
                return match
            }
        }
        if lower.contains("russian") || lower.contains("ru") {
            if let match = availableLayouts.first(where: {
                guard let sid = getLayoutID(for: $0)?.lowercased() else { return false }
                return sid.contains("russian") || sid.contains("ru")
            }) {
                return match
            }
        }
        return nil
    }
    
    private func getLayoutID(for source: TISInputSource) -> String? {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    }
    
    private func getKeyboardLayoutData(from source: TISInputSource) -> UnsafePointer<UCKeyboardLayout>? {
        guard let dataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(dataPtr).takeUnretainedValue()
        return CFDataGetBytePtr(data).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
    }
    
    private func characterForKeyCode(_ keyCode: UInt16, modifiers: UInt32, keyboardLayout: UnsafePointer<UCKeyboardLayout>) -> String? {
        var deadKeyState: UInt32 = 0
        let maxLength = 4
        var actualLength = 0
        var chars = [UniChar](repeating: 0, count: maxLength)
        
        let status = UCKeyTranslate(
            keyboardLayout,
            keyCode,
            UInt16(kUCKeyActionDown),
            modifiers,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            maxLength,
            &actualLength,
            &chars
        )
        
        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: actualLength)
    }
}
