import Foundation
import SwiftUI

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @AppStorage("isToastEnabled") var isToastEnabled: Bool = true
    @AppStorage("autoSelectAllText") var autoSelectAllText: Bool = false
    
    @AppStorage("primaryLayoutID") var primaryLayoutID: String = "com.apple.keylayout.US"
    @AppStorage("secondaryLayoutID") var secondaryLayoutID: String = "com.apple.keylayout.RussianWin"
    
    // Call this when layouts change
    func updateMapping() {
        LayoutMapper.shared.buildBidirectionalMap(layoutAID: primaryLayoutID, layoutBID: secondaryLayoutID)
    }
}
