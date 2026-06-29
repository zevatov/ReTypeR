import Foundation
import SwiftUI

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @AppStorage("isToastEnabled") var isToastEnabled: Bool = true
    @AppStorage("autoSelectAllText") var autoSelectAllText: Bool = false
    @AppStorage("switchLayoutAfterConversion") var switchLayoutAfterConversion: Bool = true
    @AppStorage("isAppEnabled") var isAppEnabled: Bool = true
    @AppStorage("isHistoryEnabled") var isHistoryEnabled: Bool = true
    @AppStorage("isSmartRecognitionEnabled") var isSmartRecognitionEnabled: Bool = true
    
    @AppStorage("primaryLayoutID") var primaryLayoutID: String = "com.apple.keylayout.US"
    @AppStorage("secondaryLayoutID") var secondaryLayoutID: String = "com.apple.keylayout.RussianWin"
    
    init() {
        // Automatic keyboard layout detection for defaults
        LayoutMapper.shared.refreshAvailableLayouts()
        let installed = LayoutMapper.shared.getInstalledLayouts()
        
        if UserDefaults.standard.string(forKey: "primaryLayoutID") == nil {
            if let english = installed.first(where: { $0.id.lowercased().contains("us") || $0.id.lowercased().contains("abc") }) {
                primaryLayoutID = english.id
            } else if let first = installed.first {
                primaryLayoutID = first.id
            }
        }
        if UserDefaults.standard.string(forKey: "secondaryLayoutID") == nil {
            if let russian = installed.first(where: { $0.id.lowercased().contains("russian") || $0.id.lowercased().contains("ru") }) {
                secondaryLayoutID = russian.id
            } else if installed.count > 1 {
                secondaryLayoutID = installed[1].id
            }
        }
    }
    
    // Call this when layouts change
    func updateMapping() {
        LayoutMapper.shared.buildBidirectionalMap(layoutAID: primaryLayoutID, layoutBID: secondaryLayoutID)
    }
}
