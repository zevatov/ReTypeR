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
            
            // 1. Convert text
            let countA = text.filter { LayoutMapper.shared.aToBMap.keys.contains($0) }.count
            let countB = text.filter { LayoutMapper.shared.bToAMap.keys.contains($0) }.count
            
            let convertedText = LayoutMapper.shared.convert(text)
            
            // 2. If nothing changed, return
            if text == convertedText { return }
            
            // 3. Replace text
            TextService.shared.replaceSelectedText(with: convertedText)
            
            // 4. Switch layout if setting is enabled
            if PreferencesManager.shared.switchLayoutAfterConversion {
                let targetLayoutID = (countA > countB) ? PreferencesManager.shared.secondaryLayoutID : PreferencesManager.shared.primaryLayoutID
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
}
