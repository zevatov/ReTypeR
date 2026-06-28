import Foundation
import SwiftUI
import Combine

struct ConversionRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let original: String
    let converted: String
    let timestamp: Date
}

class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()
    
    @AppStorage("totalConversions") var totalConversions: Int = 0
    @AppStorage("totalCharactersConverted") var totalCharactersConverted: Int = 0
    
    @Published var history: [ConversionRecord] = []
    
    private let maxHistoryItems = 50
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadHistory()
        
        // Listen to UserDefaults changes to clear history if disabled
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if !PreferencesManager.shared.isHistoryEnabled {
                    self?.clearHistoryOnly()
                }
            }
            .store(in: &cancellables)
    }
    
    func recordConversion(original: String, converted: String) {
        totalConversions += 1
        totalCharactersConverted += converted.count
        
        if PreferencesManager.shared.isHistoryEnabled {
            let record = ConversionRecord(id: UUID(), original: original, converted: converted, timestamp: Date())
            history.insert(record, at: 0)
            if history.count > maxHistoryItems {
                history = Array(history.prefix(maxHistoryItems))
            }
            saveHistory()
        }
    }
    
    func reset() {
        totalConversions = 0
        totalCharactersConverted = 0
        clearHistoryOnly()
    }
    
    private func clearHistoryOnly() {
        history.removeAll()
        saveHistory()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "conversionHistory"),
           let decoded = try? JSONDecoder().decode([ConversionRecord].self, from: data) {
            self.history = decoded
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "conversionHistory")
        } else {
            UserDefaults.standard.removeObject(forKey: "conversionHistory")
        }
    }
}
