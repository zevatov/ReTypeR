import Foundation
import SwiftUI
import Combine

/// A single conversion stored in the in-app history.
struct ConversionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let original: String
    let converted: String
    let timestamp: Date

    init(id: UUID = UUID(), original: String, converted: String, timestamp: Date = Date()) {
        self.id = id
        self.original = original
        self.converted = converted
        self.timestamp = timestamp
    }
}

/// Aggregated conversion statistics and the recent-conversions history.
/// Counters persist via UserDefaults; history persists as JSON in
/// Application Support. History recording is gated by `isHistoryEnabled`.
class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()

    @AppStorage("totalConversions") var totalConversions: Int = 0
    @AppStorage("totalCharactersConverted") var totalCharactersConverted: Int = 0

    @Published private(set) var history: [ConversionRecord] = []

    private let maxHistoryItems = 50
    private var cancellables = Set<AnyCancellable>()

    private static var historyFileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReTypeR", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    init() {
        loadHistory()

        // Reload history when the user toggles it on again.
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if PreferencesManager.shared.isHistoryEnabled && self.history.isEmpty {
                    self.loadHistory()
                }
            }
            .store(in: &cancellables)
    }

    func recordConversion(original: String, converted: String) {
        totalConversions += 1
        totalCharactersConverted += converted.count

        guard PreferencesManager.shared.isHistoryEnabled else { return }

        let record = ConversionRecord(original: original, converted: converted)
        history.insert(record, at: 0)
        if history.count > maxHistoryItems {
            history.removeLast(history.count - maxHistoryItems)
        }
        saveHistory()
    }

    func reset() {
        totalConversions = 0
        totalCharactersConverted = 0
        history.removeAll()
        saveHistory()
    }

    // MARK: - Persistence

    private func loadHistory() {
        guard PreferencesManager.shared.isHistoryEnabled,
              let data = try? Data(contentsOf: Self.historyFileURL),
              let records = try? JSONDecoder().decode([ConversionRecord].self, from: data) else {
            return
        }
        history = records
    }

    private func saveHistory() {
        guard PreferencesManager.shared.isHistoryEnabled,
              let data = try? JSONEncoder().encode(history) else {
            return
        }
        try? data.write(to: Self.historyFileURL, options: .atomic)
    }
}
