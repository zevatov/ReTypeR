import Foundation

/// Append-only local log of conversion attempts, kept for later analysis
/// (missed conversions, OCR quality, dictionary improvements).
/// Stored only on this Mac, never sent anywhere.
final class ConversionLogger {
    static let shared = ConversionLogger()

    private let queue = DispatchQueue(label: "com.retyper.conversionlogger")
    private let maxBytes: Int64 = 5 * 1024 * 1024

    private lazy var fileURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ReTypeR", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("conversion_log.jsonl")
    }()

    /// - Parameters:
    ///   - source: where the conversion came from ("hotkey" or "ocr")
    ///   - changed: whether the converter actually modified the text
    func log(source: String, input: String, output: String, changed: Bool) {
        // Privacy-first (S-03/REL-4): the log is opt-in and disabled by
        // default — neither rotation nor writing may run while it is off.
        guard PreferencesManager.shared.isConversionLogEnabled else { return }

        let entry: [String: Any] = [
            "ts": ISO8601DateFormatter().string(from: Date()),
            "source": source,
            "input": input,
            "output": output,
            "changed": changed
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              let line = String(data: data, encoding: .utf8) else { return }

        queue.async { [weak self] in
            guard let self = self else { return }
            self.rotateIfNeeded()
            if let handle = FileHandle(forWritingAtPath: self.fileURL.path) {
                handle.seekToEndOfFile()
                handle.write((line + "\n").data(using: .utf8)!)
                try? handle.close()
            } else {
                try? (line + "\n").data(using: .utf8)?.write(to: self.fileURL)
            }
        }
    }

    /// Removes the current log and its rotated copy (user-initiated cleanup
    /// from Settings). IO errors are logged quietly and never thrown.
    func clearLog() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let oldURL = self.fileURL.deletingLastPathComponent()
                .appendingPathComponent("conversion_log.old.jsonl")
            for url in [self.fileURL, oldURL] {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch let error as NSError where error.code == NSFileNoSuchFileError {
                    // Nothing to remove — already clean.
                } catch {
                    NSLog("[ConversionLogger] clearLog failed for %@: %@",
                          url.lastPathComponent, error.localizedDescription)
                }
            }
        }
    }

    /// Keep at most ~5 MB plus one rotated previous file.
    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int64, size > maxBytes else { return }
        let old = fileURL.deletingLastPathComponent()
            .appendingPathComponent("conversion_log.old.jsonl")
        try? FileManager.default.removeItem(at: old)
        try? FileManager.default.moveItem(at: fileURL, to: old)
    }
}
