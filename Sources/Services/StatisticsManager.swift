import Foundation
import SwiftUI

class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()
    
    @AppStorage("totalConversions") var totalConversions: Int = 0
    @AppStorage("totalCharactersConverted") var totalCharactersConverted: Int = 0
    
    func recordConversion(characterCount: Int) {
        totalConversions += 1
        totalCharactersConverted += characterCount
    }
    
    func reset() {
        totalConversions = 0
        totalCharactersConverted = 0
    }
}
