import Foundation
import Combine

class ConversionEngine {
    static let shared = ConversionEngine()
    
    // Notification for the UI to show the Toast
    let conversionCompletedPublisher = PassthroughSubject<(original: String, converted: String), Never>()
    
    func convertSelectedText() {
        guard PreferencesManager.shared.isAppEnabled else { return }
        
        if PreferencesManager.shared.autoSelectAllText {
            TextService.shared.selectAllText {
                self.performConversion()
            }
        } else {
            performConversion()
        }
    }
    
    private func performConversion() {
        TextService.shared.getSelectedText { [weak self] selectedText in
            guard let self = self,
                  let text = selectedText,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            
            // 1. Convert text (v1.3 §1.8 Class H): the scorer owns the layout
            // decision; the engine only executes it.
            let result = LayoutMapper.shared.convertDetailed(
                text,
                smart: PreferencesManager.shared.isSmartRecognitionEnabled,
                source: .hotkey
            )
            let convertedText = result.text
            
            // 1.5 Log the attempt (incl. unchanged — these are the interesting misses)
            ConversionLogger.shared.log(source: "hotkey", input: text, output: convertedText, changed: result.changed)
            
            // 2. If nothing changed, return
            if !result.changed { return }
            
            // 3. Replace text
            TextService.shared.replaceSelectedText(with: convertedText)
            
            // 4. Switch layout if setting is enabled (v1.3 §1.8 Class H):
            // target = layout OPPOSITE to the dominant source script;
            // no-switch when changed == false or mixed input.
            if PreferencesManager.shared.switchLayoutAfterConversion,
               let targetLayoutID = self.targetLayoutID(for: text, result: result) {
                LayoutMapper.shared.switchToLayout(id: targetLayoutID)
            }
            
            // 5. Update stats and history
            StatisticsManager.shared.recordConversion(original: text, converted: convertedText)
            
            // 6. Notify UI to show toast if enabled
            if PreferencesManager.shared.isToastEnabled {
                DispatchQueue.main.async {
                    self.conversionCompletedPublisher.send((original: text, converted: convertedText))
                }
            }
        }
    }
    
    /// Class H (v1.3 §1.8): resolves the post-conversion system layout from the
    /// scorer's decision. Returns nil when switching must NOT happen:
    /// - `dominantSourceScript == nil` (basic mode / no recognizable script), or
    /// - mixed input: both latin and cyrillic letter shares exceed 35%.
    private func targetLayoutID(for originalText: String, result: ConversionResult) -> String? {
        guard let dominantScript = result.dominantSourceScript else { return nil }
        
        // Mixed-text no-switch rule (§1.8): both shares > 35% → keep layout.
        if isMixed(originalText, threshold: 0.35) { return nil }
        
        let prefs = PreferencesManager.shared
        // A-07/MED-3: resolve the primary language through the SAME mapper the
        // scorer uses (de/fr/es included). When the primary layout has no
        // known script (e.g. German), a script comparison is meaningless and
        // used to flip to the WRONG layout — no-switch is the safe default.
        guard let primaryScript = SmartScorer.script(forLanguage: LayoutMapper.languageCode(for: prefs.primaryLayoutID)) else {
            return nil
        }
        // Target is OPPOSITE to the dominant source script (where we converted to).
        let dominantIsPrimary = dominantScript == primaryScript
        return dominantIsPrimary ? prefs.secondaryLayoutID : prefs.primaryLayoutID
    }
    
    /// True when BOTH latin and cyrillic letter shares of the source exceed
    /// `threshold` — genuinely mixed content where a layout switch would be
    /// wrong more often than right (v1.3 §1.8).
    private func isMixed(_ text: String, threshold: Double) -> Bool {
        var latin = 0
        var cyrillic = 0
        for ch in text where ch.isLetter {
            switch SmartScorer.script(of: ch) {
            case .latin: latin += 1
            case .cyrillic: cyrillic += 1
            case nil: continue
            }
        }
        let total = latin + cyrillic
        guard total > 0 else { return false }
        let latinShare = Double(latin) / Double(total)
        let cyrillicShare = Double(cyrillic) / Double(total)
        return latinShare > threshold && cyrillicShare > threshold
    }
    
}
