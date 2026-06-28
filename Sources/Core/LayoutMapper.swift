import Foundation
import Carbon

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
    private var aToBMap: [Character: Character] = [:]
    private var bToAMap: [Character: Character] = [:]
    
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
        guard let sourceA = availableLayouts.first(where: { getLayoutID(for: $0) == layoutAID }),
              let sourceB = availableLayouts.first(where: { getLayoutID(for: $0) == layoutBID }) else {
            return
        }
        
        guard let dataA = getKeyboardLayoutData(from: sourceA),
              let dataB = getKeyboardLayoutData(from: sourceB) else {
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
                    aToB[charA] = charB
                    bToA[charB] = charA
                }
            }
        }
        
        self.aToBMap = aToB
        self.bToAMap = bToA
    }
    
    // Auto-detection based on character frequencies
    func convert(_ text: String) -> String {
        let countA = text.filter { aToBMap.keys.contains($0) }.count
        let countB = text.filter { bToAMap.keys.contains($0) }.count
        
        if countA > countB {
            // Convert A to B
            return String(text.map { aToBMap[$0] ?? $0 })
        } else {
            // Convert B to A
            return String(text.map { bToAMap[$0] ?? $0 })
        }
    }
    
    // MARK: - Private Helpers
    
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
