import Foundation
import AppKit

/// Source of a conversion request (v1.3 §1.3). OCR fragments obey stricter
/// noise rules than hotkey conversions.
enum ConversionSource {
    case hotkey
    case ocr
}

/// Script of a letter run (v1.3 §1.5). Mixed-script text is expressed by
/// `SmartScorer.scriptOf(_:)` returning `nil`.
enum Script: Equatable {
    case latin
    case cyrillic
}

/// Three-level word trust (v1.3 §1.1) replacing the binary isValidWord.
enum WordTrust {
    case strongValid
    case weakValid
    case invalid
}

/// Frequency-list provider (v1.3 §1.1.1). Production uses BundleFrequencyStore
/// backed by bundled top-frequency lists (CC-BY-SA-4.0, see
/// Sources/Resources/FREQUENCY_DATA_LICENSE.md); tests inject fixture stores
/// through this seam.
protocol FrequencyStore {
    /// 1-based rank of the word within the language corpus; nil when unknown.
    func rank(of word: String, language: String) -> Int?
}

/// Default empty store: every lookup misses. Kept for tests and fallbacks.
struct EmptyFrequencyStore: FrequencyStore {
    func rank(of word: String, language: String) -> Int? { nil }
}

/// Production store (v1.3 §1.1.1): lazily loads `frequency_<lang>.txt` from the
/// app bundle (one word per line, descending frequency) and answers lookups
/// with a binary search over the alphabetically sorted word array; the stored
/// frequency rank travels alongside each entry.
final class BundleFrequencyStore: FrequencyStore {
    private struct LanguageTable {
        let sortedWords: [String]
        let rankByIndex: [Int]
    }

    private static let lock = NSLock()
    private static var tables: [String: LanguageTable] = [:]

    /// 1-based frequency rank; nil when the word is unknown.
    func rank(of word: String, language: String) -> Int? {
        guard let table = Self.table(for: language) else { return nil }
        let lower = word.lowercased()
        if let rank = Self.binarySearchRank(of: lower, in: table) {
            return rank
        }
        if language == "ru" {
            if lower.contains("е") {
                let yo = lower.replacingOccurrences(of: "е", with: "ё")
                if let rank = Self.binarySearchRank(of: yo, in: table) {
                    return rank
                }
            }
            if lower.contains("ё") {
                let ye = lower.replacingOccurrences(of: "ё", with: "е")
                if let rank = Self.binarySearchRank(of: ye, in: table) {
                    return rank
                }
            }
        }
        return nil
    }

    private static func table(for language: String) -> LanguageTable? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = tables[language] { return cached }
        guard let url = Bundle.main.url(forResource: "frequency_\(language)", withExtension: "txt"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        var paired: [(word: String, rank: Int)] = []
        var seen = Set<String>()
        for (i, rawLine) in raw.split(separator: "\n").enumerated() {
            let word = rawLine.trimmingCharacters(in: .whitespaces).lowercased()
            guard !word.isEmpty, !seen.contains(word) else { continue }
            seen.insert(word)
            paired.append((word, i + 1))
        }
        paired.sort { $0.word < $1.word }
        let table = LanguageTable(sortedWords: paired.map { $0.word }, rankByIndex: paired.map { $0.rank })
        tables[language] = table
        return table
    }

    private static func binarySearchRank(of word: String, in table: LanguageTable) -> Int? {
        var low = 0
        var high = table.sortedWords.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let midWord = table.sortedWords[mid]
            if midWord == word { return table.rankByIndex[mid] }
            if midWord < word { low = mid + 1 } else { high = mid - 1 }
        }
        return nil
    }
}

/// Char-bigram language model (v1.3 §1.1.2): a compact `uint16` little-endian
/// grid (`side × side`) of sqrt-compressed corpus counts. Scores are add-one
/// smoothed log-probabilities in nats; «ё» is folded onto «е» to match the
/// generation-time normalization of the Russian grid.
final class BigramLanguageModel {
    private let side: Int
    private let counts: [UInt32]
    private let rowTotals: [Double]
    private let indexByChar: [Character: Int]

    init?(resourceBase: String, alphabet: String) {
        guard let url = Bundle.main.url(forResource: resourceBase, withExtension: "bin"),
              let data = try? Data(contentsOf: url) else { return nil }
        let side = alphabet.count
        guard data.count == side * side * 2 else { return nil }
        self.side = side

        var counts: [UInt32] = []
        counts.reserveCapacity(side * side)
        var offset = data.startIndex
        for _ in 0..<(side * side) {
            let lo = UInt16(data[offset])
            let hi = UInt16(data[data.index(after: offset)])
            counts.append(UInt32(lo | (hi << 8)))
            offset = data.index(offset, offsetBy: 2)
        }
        self.counts = counts
        self.rowTotals = (0..<side).map { row in
            Double(counts[row * side..<(row + 1) * side].reduce(0, +))
        }
        var index: [Character: Int] = [:]
        for (i, ch) in alphabet.enumerated() { index[ch] = i }
        self.indexByChar = index
    }

    private func identifiers(of word: String) -> [Int] {
        var normalized = ""
        for ch in word.lowercased() {
            normalized.append(ch == "ё" ? "е" : ch)
        }
        return normalized.compactMap { indexByChar[$0] }
    }

    private func pairScore(_ a: Int, _ b: Int) -> Double {
        log((Double(counts[a * side + b]) + 1) / (rowTotals[a] + Double(side)))
    }

    /// Total log-probability of the word's bigrams; nil when fewer than two
    /// in-alphabet characters are available.
    func sumScore(of word: String) -> Double? {
        let ids = identifiers(of: word)
        guard ids.count >= 2 else { return nil }
        var sum = 0.0
        for (a, b) in zip(ids, ids.dropFirst()) { sum += pairScore(a, b) }
        return sum
    }

    /// Per-bigram average of `sumScore`; comparable across word lengths.
    func averageScore(of word: String) -> Double? {
        let ids = identifiers(of: word)
        guard ids.count >= 2 else { return nil }
        return sumScore(of: word)! / Double(ids.count - 1)
    }
}

/// Result of a smart conversion (v1.3 §1.8). The scorer owns the layout
/// decision; ConversionEngine only executes it.
struct ConversionResult {
    let text: String
    /// Dominant script of the SOURCE text by weighted vote (§1.2).
    let dominantSourceScript: Script?
    let changed: Bool
}

/// Smart per-token decision engine for layout conversion.
///
/// Principles:
/// - Protected fragments (URLs, e-mails, file paths, code identifiers, mixed
///   letter+digit tokens) are never converted.
/// - A token is kept as-is when it is valid in its own language (three-level
///   trust, v1.3 §1.1).
/// - A token is converted only when the converted form is valid and the
///   original form is not.
/// - Ambiguous tokens are decided by a weighted global vote of all tokens
///   with a direction hysteresis (v1.3 §1.2) and a dual vote gate (§1.4).
/// - Safe default: when in doubt, keep the text unchanged.
final class SmartScorer {
    static let shared = SmartScorer()

    // MARK: - Injection points

    /// Frequency store (v1.3 §1.1.1). Bundle-backed by default; tests may
    /// inject fixture stores (EmptyFrequencyStore stays available).
    var frequencyStore: FrequencyStore = BundleFrequencyStore()

    private let frequencyTopN = 60_000

    /// Char-bigram language models (v1.3 §1.1.2), lazily created from bundle
    /// resources. Nil when the resource is missing (tests, stripped bundles) —
    /// the undecided path then behaves exactly as before.
    private static let ruBigramModel = BigramLanguageModel(
        resourceBase: "bigram_ru",
        alphabet: "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
    )
    private static let enBigramModel = BigramLanguageModel(
        resourceBase: "bigram_en",
        alphabet: "abcdefghijklmnopqrstuvwxyz"
    )

    private func bigramModel(for language: String) -> BigramLanguageModel? {
        switch language {
        case "ru": return Self.ruBigramModel
        case "en": return Self.enBigramModel
        default: return nil
        }
    }

    /// Undecided-case tie-breaker (v1.3 §1.1.2): when neither the frequency
    /// lists nor the spellchecker can validate a token in either language,
    /// the char-bigram profile decides whether the CANDIDATE is plausible
    /// enough to receive weakValid trust for its language.
    private func bigramScore(word: String, language: String) -> Double? {
        guard let model = bigramModel(for: language) else { return nil }
        return model.averageScore(of: word)
    }

    /// Gates (thresholds chosen from the OpenSubtitles corpus, see the
    /// validation table printed by scripts/generate_frequency_resources.py):
    /// - candidate must be a SINGLE letter run of ≥ 6 letters: multi-run
    ///   candidates («кл.чмоделей») belong to the split/vote paths and short
    ///   pairs stay with the context vote;
    /// - candidate average bigram score ≥ −3.5 nat: rejects glue garbage
    ///   («укфащч» −4.8, «яумфещм» −4.6, «гыфс» −6.5) while accepting
    ///   plausible coinages («хиросмс» −3.0, «локалхост» −2.8);
    /// - candidate must beat the ORIGINAL side by > 2.0 nat on average:
    ///   direction-sensitive, so smooth nicknames («erafox», «zevatov») never
    ///   win their own conversion;
    /// - anti-tail: trimming one edge letter must not reveal a frequent word —
    ///   blocks punctuation-pair artifacts («проверимх» → «проверим»).
    /// A-02/FUN-5: returns the ACCEPTED OUTPUT (the candidate, or the two
    /// known words a fused conversion must be emitted as) or nil when the
    /// tie-breaker rejects. No hidden mutable state crosses this boundary.
    private func bigramTieBreakAccepts(candidate: String, original: String, language: String) -> String? {
        // Mixed-script tokens never convert: their candidate is garbage in
        // either direction (§1.5).
        guard Self.scriptOf(candidate) != nil else { return nil }
        guard letterRunCount(of: candidate) == 1 else { return nil }
        guard candidate.filter({ $0.isLetter }).count >= 6 else { return nil }
        guard let originalLanguage = Self.oppositeLanguage(of: language),
              let candidateAvg = bigramScore(word: candidate, language: language),
              let originalAvg = bigramScore(word: original, language: originalLanguage) else { return nil }
        guard candidateAvg >= -3.5 else { return nil }
        // 1.5 nat separates the data cleanly: correct candidates score
        // ≥ +1.86 («безлимитные»), wrong-direction ones ≤ −6.95.
        guard candidateAvg - originalAvg > 1.5 else { return nil }

        // Class F extension: when the wholesale conversion fused two known
        /// words (layout punctuation like «.»→«ю» swallows separators),
        /// emit them SEPARATED instead of one glued blob.
        if let separated = splitIntoTwoKnownWords(candidate, language: language) {
            return separated
        }

        let lower = candidate.lowercased()
        let trimmedTail = String(lower.dropLast())
        let trimmedHead = String(lower.dropFirst())
        if trimmedTail.count >= 4 && frequencyStore.rank(of: trimmedTail, language: language) != nil { return nil }
        if trimmedHead.count >= 4 && frequencyStore.rank(of: trimmedHead, language: language) != nil { return nil }
        return candidate
    }

    /// Returns "left right" when the candidate splits into exactly two known
    /// frequency words (≥4 letters each); nil otherwise. Used to undo fusions
    /// created by layout punctuation («rk.xvjltktq» → «ключючмоделей»-style).
    private func splitIntoTwoKnownWords(_ candidate: String, language: String) -> String? {
        let lowerCandidate = candidate.lowercased()
        if protectedUnsplitWords.contains(lowerCandidate) { return nil }
        if frequencyStore.rank(of: lowerCandidate, language: language) != nil { return nil }
        let letters = lowerCandidate.filter { $0.isLetter }
        guard letters.count >= 8, letters.count <= 40 else { return nil }
        var best: (text: String, rankSum: Int)?
        for cut in 4...(letters.count - 4) {
            let head = String(letters.prefix(cut))
            let tail = String(letters.suffix(letters.count - cut))
            guard let hr = frequencyStore.rank(of: head, language: language),
                  let tr = frequencyStore.rank(of: tail, language: language) else { continue }
            let sum = hr + tr
            if best == nil || sum < best!.rankSum { best = (head + " " + tail, sum) }
        }
        return best?.text
    }

    private static func oppositeLanguage(of language: String) -> String? {
        switch language {
        case "ru": return "en"
        case "en": return "ru"
        default: return nil
        }
    }

    /// Vote-time plausibility gate: blocks direction-driven conversions that
    /// would destroy plausible text while keeping the legacy garbage-flip path
    /// intact (both-invalid pairs still follow the vote):
    /// - a BIGRAM-PLAUSIBLE original (avg ≥ −3.5 nat, e.g. «Гемени»,
    ///   «привязку», «erafox») is kept whenever the candidate's profile is
    ///   worse — a vote must not trade a word-like string for garbage;
    /// - multi-run originals require EVERY letter run of the candidate to be
    ///   a known word (blocks «rk.xvjltktq» → «кл.чмоделей»: run «кл» unknown).
    private func voteCandidatePlausible(
        candidate: String,
        original: String,
        candidateLanguage: String,
        originalLanguage: String
    ) -> Bool {
        guard candidate.filter({ $0.isLetter }).count >= 3 else { return false }

        // Plausible originals resist conversion into worse candidates. Only
        // SINGLE-RUN originals qualify, and only when the original does NOT
        // carry a punctuation-pair artifact: when trimming one edge letter
        // reveals a frequent word («проверимж» → «проверим»), the trailing
        // letter is exactly the artifact the vote exists to undo, so the
        // conversion proceeds.
        if letterRunCount(of: original) == 1,
           let origAvg = bigramScore(word: original, language: originalLanguage),
           origAvg >= -3.5,
           let candAvg = bigramScore(word: candidate, language: candidateLanguage),
           candAvg < origAvg {
            let lowerOriginal = original.lowercased()
            let tailTrim = String(lowerOriginal.dropLast())
            let headTrim = String(lowerOriginal.dropFirst())
            let hasEdgeArtifact =
                (tailTrim.count >= 4 && frequencyStore.rank(of: tailTrim, language: originalLanguage) != nil) ||
                (headTrim.count >= 4 && frequencyStore.rank(of: headTrim, language: originalLanguage) != nil)
            if !hasEdgeArtifact { return false }
        }

        // Multi-run originals: if candidate is ALSO multi-run, every candidate run must be a real word.
        let candRuns = candidateRuns(candidate)
        if letterRunCount(of: original) >= 2 && candRuns.count >= 2 {
            for run in candRuns {
                if frequencyStore.rank(of: run.lowercased(), language: candidateLanguage) == nil {
                    return false
                }
            }
        }
        return true
    }

    /// Letter runs of a token, split on non-letters.
    private func candidateRuns(_ token: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for ch in token {
            if ch.isLetter {
                current.append(ch)
            } else if !current.isEmpty {
                runs.append(current)
                current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    // MARK: - Direction hysteresis state (v1.3 §1.2 — instance-scoped, not static)

    private enum Direction { case aToB, bToA }
    /// A-02/FUN-5: the scorer is a singleton reachable from the main thread
    /// (hotkey + concurrent tests) — all mutable
    /// state below is guarded by this lock.
    private let stateLock = NSLock()
    private var lastDirection: Direction?
    private var lastDirectionAt: Date?
    private let hysteresisWindow: TimeInterval = 90
    private let hysteresisBias: Double = 1.5

    /// Test seam: clears direction memory and cache between test cases.
    func resetHysteresis() {
        stateLock.lock()
        defer { stateLock.unlock() }
        lastDirection = nil
        lastDirectionAt = nil
        Self.validatedCacheLock.lock()
        Self.validatedCache.removeAll()
        Self.validatedCacheLock.unlock()
    }

    /// A-02/FUN-5: locked read of the direction memory.
    private func storedDirection() -> (Direction, Date)? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard let direction = lastDirection, let at = lastDirectionAt else { return nil }
        return (direction, at)
    }

    /// A-02/FUN-5: locked write of the direction memory.
    private func storeDirection(_ direction: Direction) {
        stateLock.lock()
        defer { stateLock.unlock() }
        lastDirection = direction
        lastDirectionAt = Date()
    }

    /// A-02/FUN-5: locked reset of the direction memory (convert-internal).
    private func clearDirectionLocked() {
        stateLock.lock()
        defer { stateLock.unlock() }
        lastDirection = nil
        lastDirectionAt = nil
    }

    // MARK: - Word lists

    /// Single-letter words per language. «х», «ъ» are letter-run components
    /// reachable through punctuation pairs ([/]; → х/ъ) and must validate so
    /// paired tokens keep converting (regression: testSpecialCharactersMapping).
    private let ruSingleLetters: Set<String> = ["а", "б", "в", "ж", "и", "к", "о", "с", "т", "у", "я", "э", "х", "ъ"]
    private let enSingleLetters: Set<String> = ["a", "i"]

    /// Common short function words (prepositions, conjunctions, particles, pronouns, auxiliaries).
    private let ruFunctionWords: Set<String> = [
        "а", "без", "близ", "бы", "был", "была", "было", "были", "в", "вам", "вас",
        "ведь", "во", "вот", "впрочем", "вы", "да", "для", "до", "его", "её", "ее", "ей",
        "ему", "если", "же", "за", "из", "или", "им", "ими", "их", "к", "как", "ко",
        "когда", "кто", "ли", "лишь", "мне", "мной", "мы", "на", "над", "не", "неё", "нее",
        "ней", "нет", "ним", "ними", "них", "но", "о", "об", "один", "она", "они",
        "оно", "от", "перед", "по", "под", "при", "про", "пусть", "с", "сам", "своё", "свое",
        "со", "так", "там", "то", "тоже", "тот", "ту", "ты", "у", "уж", "уже", "хоть",
        "чем", "через", "что", "чтобы", "эта", "эти", "это", "этой", "этот", "я",
        "ещё", "еще", "очень", "просто", "почти", "ща", "щас"
    ]

    private let enFunctionWords: Set<String> = [
        "a", "about", "after", "all", "also", "an", "and", "any", "are", "as", "at",
        "be", "because", "been", "but", "by", "can", "could", "did", "do", "does",
        "for", "from", "had", "has", "have", "he", "her", "him", "his", "how", "i",
        "if", "in", "into", "is", "it", "its", "just", "like", "may", "me", "more",
        "most", "my", "no", "not", "now", "of", "on", "one", "or", "other", "our",
        "out", "over", "she", "should", "so", "some", "such", "than", "that", "the",
        "their", "them", "then", "there", "these", "they", "this", "those", "to",
        "two", "up", "us", "was", "we", "were", "what", "when", "which", "who",
        "will", "with", "would", "you", "your"
    ]

    /// SI units and ubiquitous abbreviations that are intentional words in EN
    /// context and must survive conversion (v1.3 §1.1 / T-C-A1: «ghbdtn kb gb bp»
    /// → «привет kb gb bp»). Their layout-shifted forms («ли», «из») must not win.
    private let enUnitAbbreviations: Set<String> = ["kb", "mb", "gb", "tb", "pb", "bp", "bb"]

    /// Words that must NEVER be cut into parts by splitCandidate or splitIntoTwoKnownWords.
    private let protectedUnsplitWords: Set<String> = [
        "потому", "откуда", "зачем", "наверное", "пожалуйста", "непонятно",
        "досюда", "приложения", "предлоги", "разделяет", "приложение",
        "приложений", "поэтому", "отчего", "покуда", "докудова", "потолок",
        "навряд", "наврядли", "врядли", "сейчас", "сегодня", "наконец",
        "затем", "оттуда", "отсюда", "отныне", "навсегда", "надеюсь",
        "пожалуй", "стало", "проблема", "проблемы", "алгоритм", "алгоритма",
        "ассетов", "ассеты", "ассет"
    ]

    /// Punctuation that may legitimately surround a word. Characters outside
    /// this set (e.g. backtick, which maps to «ё») make the original token
    /// invalid, so words like «to`» (= «ещё») get converted.
    private let allowedPunctuation: Set<Character> = [
        ".", ",", "!", "?", ":", ";", "(", ")", "[", "]", "{", "}",
        "\"", "'", "«", "»", "„", "“", "”", "-", "—", "–", "…", "*", "/", "+",
        "<", ">"
    ]

    /// Marks of code/identifiers — tokens containing them are never converted.
    private let codeMarkers: Set<Character> = ["_", "$", "\\", "<", ">", "|", "&", "=", "%", "#", "^"]

    /// Known URL schemes — tokens starting with one of them are never converted.
    private let urlSchemes = ["http://", "https://", "ftp://", "ftps://", "mailto:", "ssh://", "file://", "tel:", "tg://"]

    /// Mock dictionary for headless tests where NSSpellChecker IPC is blocked.
    /// Trust level: spellchecker-equivalent (weakValid).
    private let testWords: [String: Bool] = [
        "hello": true,
        "привет": true,
        "проверим": true,
        "email": true,
        "my": true,
        "тест": true,
        "test": true,
        "оно": true,
        "ещё": true,
        "еще": true,
        "ее": true,
        "свое": true,
        "ща": true,
        "мир": true,
        "ёжик": true,
        "ёлка": true,
        "щука": true,
        "домой": true,
        "ушёл": true,
        "смог": true,
        "думало": true,
        "меняться": true,
        "зайди": true,
        "сегодня": true,
        "скажи": true,
        "пиши": true,
        "правильный": true,
        "текст": true,
        "версия": true,
        "патч": true,
        "let": true,
        "result": true,
        "value": true,
        "world": true,
        "fine": true,
        "text": true,
        "stay": true,
        "unchanged": true,
        "correct": true,
        "english": true,
        "must": true
    ]

    // MARK: - Spell checker probe (cached once, not per word)

    private static let spellCheckerProbeLock = NSLock()
    private static var spellCheckerProbeResult: Bool?

    private func spellCheckerWorks() -> Bool {
        Self.spellCheckerProbeLock.lock()
        defer { Self.spellCheckerProbeLock.unlock() }
        if let cached = Self.spellCheckerProbeResult {
            return cached
        }
        let range = NSSpellChecker.shared.checkSpelling(of: "xxyyzzqquu", startingAt: 0)
        let works = (range.location != NSNotFound)
        Self.spellCheckerProbeResult = works
        return works
    }

    // MARK: - Script classification (v1.3 §1.5, Class D)

    /// Script of a single character; nil for letters outside latin/cyrillic
    /// (they carry no vote in the two-script model).
    static func script(of character: Character) -> Script? {
        for scalar in character.unicodeScalars {
            if scalar.value >= 0x0400 && scalar.value <= 0x04FF { return .cyrillic }
        }
        let lower = character.lowercased()
        if lower >= "a" && lower <= "z" { return .latin }
        return nil
    }

    /// Strict single-script classification. Returns nil for mixed-script text
    /// («CustomЕП») or text without recognizable letters — such tokens are
    /// never trusted for either language.
    static func scriptOf(_ text: String) -> Script? {
        var seen: Set<Script> = []
        for ch in text where ch.isLetter {
            guard let s = script(of: ch) else { continue }
            seen.insert(s)
            if seen.count > 1 { return nil }
        }
        return seen.first
    }

    static func script(forLanguage code: String) -> Script? {
        switch code {
        case "ru", "uk": return .cyrillic
        case "en": return .latin
        default: return nil
        }
    }

    /// Phonotactically impossible Cyrillic sequences in modern Russian.
    static func hasImpossibleCyrillicCluster(_ lower: String) -> Bool {
        if lower.hasSuffix("ъ") || lower.contains("ьъ") || lower.contains("ъъ") || lower.contains("вьп") {
            return true
        }
        for (a, b) in zip(lower, lower.dropFirst()) where a == "ъ" {
            if !"еёюя".contains(b) { return true }
        }
        return false
    }

    // MARK: - Public API

    func convert(
        _ text: String,
        aToB: [Character: Character],
        bToA: [Character: Character],
        languageA: String,
        languageB: String,
        source: ConversionSource,
        tieBreakerAToB: () -> Bool
    ) -> ConversionResult {
        var aToB = aToB
        var bToA = bToA
        // Explicit «ё» pair: the tilde key maps to ё/Ё in RU layouts, but some
        // input sources do not expose it through UCKeyTranslate.
        if aToB["`"] == nil { aToB["`"] = "ё" }
        if aToB["~"] == nil { aToB["~"] = "Ё" }
        if bToA["ё"] == nil { bToA["ё"] = "`" }
        if bToA["Ё"] == nil { bToA["Ё"] = "~" }

        let segments = splitPreservingWhitespace(text)

        struct Pending {
            var output: String
            let original: String
            var isUndecided = false
            var candidate = ""
            var aLetters = 0
            var bLetters = 0
            var runCount = 0
            var wasConverted = false
            var isMixedScript = false
            var isSingleLetterCandidate = false
            var isAmbiguousToken = false
        }

        let nonWhitespaceCount = segments.filter { $0.first?.isWhitespace != true }.count
        var items: [Pending] = []
        // Weighted evidence per side (v1.3 §1.2): resolved tokens only;
        // undecided letters join before the direction decision.
        var aScore = 0.0
        var bScore = 0.0

        // A-01/FUN-1: per-side correctness evidence. Kept weights mark the
        // side whose text is already valid; converted weights mark tokens
        // that LEFT that side (an A→B conversion proves B was the target).
        var keptA = 0.0
        var keptB = 0.0
        var convertedAToB = 0.0
        var convertedBToA = 0.0

        func addEvidence(toA: Bool, weight: Double, kept: Bool) {
            if toA { aScore += weight } else { bScore += weight }
            if kept {
                if toA { keptA += weight } else { keptB += weight }
            } else {
                if toA { convertedAToB += weight } else { convertedBToA += weight }
            }
        }

        for segment in segments {
            let isWhitespaceSegment = segment.first?.isWhitespace == true
            let letters = segment.filter { $0.isLetter }

            guard !isWhitespaceSegment, !letters.isEmpty else {
                items.append(Pending(output: segment, original: segment))
                continue
            }

            // Protected fragments are never converted.
            if isProtected(segment) {
                items.append(Pending(output: segment, original: segment))
                continue
            }

            // Class C (OCR): noisy fragments never participate.
            if source == .ocr && isOCRProtected(segment) {
                items.append(Pending(output: segment, original: segment))
                continue
            }

            // Class C (OCR): hyphenated fragments («т-шаблонов», «n-if,kjyjd»)
            // are dash-prone in OCR output and never touched in OCR mode.
            if source == .ocr && segment.contains("-") {
                items.append(Pending(output: segment, original: segment))
                continue
            }

            let aCount = letters.filter { aToB.keys.contains($0) }.count
            let bCount = letters.filter { bToA.keys.contains($0) }.count

            // Treat the dominant script as the original form.
            let originalIsA = aCount >= bCount
            let originalLang = originalIsA ? languageA : languageB
            let candidateLang = originalIsA ? languageB : languageA
            let map = originalIsA ? aToB : bToA
            var candidate = String(segment.map { map[$0] ?? $0 })
            // Class E (§1.6): preserve uppercase and titlecase shapes.
            let sourceLetters = segment.filter { $0.isLetter }
            let hasLetters = !sourceLetters.isEmpty
            let isAllUpper = hasLetters && sourceLetters.allSatisfy { $0.isUppercase }
            if isAllUpper {
                candidate = candidate.uppercased()
            } else if segment.first?.isUppercase == true && segment.dropFirst().allSatisfy({ !$0.isLetter || $0.isLowercase }) {
                candidate = candidate.prefix(1).uppercased() + candidate.dropFirst().lowercased()
            }
            let runs = letterRunCount(of: segment)
            let mixedScript = Self.scriptOf(segment) == nil

            let originalTrust = classifyToken(segment, language: originalLang)
            let candidateTrust = classifyToken(candidate, language: candidateLang)

            // Short-word collision resolution (2..4 letters, e.g. "tot" -> "еще", "bp" -> "из", "da" -> "да", "nu" -> "ну")
            if originalTrust == .strongValid && letters.count >= 2 && letters.count <= 4 {
                let origLower = segment.lowercased()
                let candLower = candidate.lowercased()
                let origRank = frequencyStore.rank(of: origLower, language: originalLang)
                let candRank = frequencyStore.rank(of: candLower, language: candidateLang)

                let candIsTopRU = (candidateLang == "ru" && (ruFunctionWords.contains(candLower) || (candRank != nil && candRank! <= 500)))

                // Only allow collision override when converting EN -> RU.
                // A valid RU function word / top RU word NEVER collides to EN.
                let isCollision: Bool
                if originalLang == "ru" {
                    isCollision = false
                } else {
                    let candIsStrong = (candidateTrust == .strongValid || candIsTopRU)
                    let origIsRare = (origRank == nil || origRank! > 1_000 || !enFunctionWords.contains(origLower))
                    isCollision = candIsStrong && origIsRare && (
                        (candIsTopRU && (!enFunctionWords.contains(origLower) || origRank == nil || origRank! > 500)) ||
                        (origRank == nil && candRank != nil) ||
                        (origRank != nil && origRank! > 5_000) ||
                        (origRank != nil && candRank != nil && origRank! > candRank! * 5 && origRank! > 1_000)
                    )
                }

                if isCollision {
                    if nonWhitespaceCount == 1 {
                        // User explicitly converted a single word -> candidate with superior frequency wins!
                        items.append(Pending(output: candidate, original: segment, wasConverted: true))
                        addEvidence(toA: originalIsA, weight: 3.0, kept: false)
                        continue
                    } else {
                        // In multi-word text, defer decision to sentence balance
                        items.append(Pending(
                            output: segment,
                            original: segment,
                            candidate: candidate,
                            aLetters: aCount,
                            bLetters: bCount,
                            runCount: runs,
                            isAmbiguousToken: true
                        ))
                        continue
                    }
                }
            }

            if originalTrust == .strongValid {
                // Original text is certainly a word — never touch it (weight 3.0).
                items.append(Pending(output: segment, original: segment, runCount: runs, isMixedScript: mixedScript))
                addEvidence(toA: originalIsA, weight: 3.0, kept: true)
                continue
            }

            switch (originalTrust, candidateTrust) {
            case (_, .strongValid) where originalTrust != .strongValid:
                // A-01/FUN-1: single letters are inherently ambiguous — «b»
                // can be an intentional EN letter or a mistyped RU «и». Defer
                // the decision until the whole-text context evidence is in
                // (resolved after the loop); without context they stay as is.
                if letters.count == 1 {
                    items.append(Pending(
                        output: segment,
                        original: segment,
                        candidate: candidate,
                        aLetters: aCount,
                        bLetters: bCount,
                        runCount: runs,
                        isSingleLetterCandidate: true
                    ))
                } else {
                    // Candidate is a certain word, original is not.
                    items.append(Pending(output: candidate, original: segment, wasConverted: true))
                    addEvidence(toA: originalIsA, weight: 3.0, kept: false)
                }
            case (.invalid, .weakValid):
                // len>=4 spellchecker candidate accepted against invalid original.
                items.append(Pending(output: candidate, original: segment, wasConverted: true))
                addEvidence(toA: originalIsA, weight: 3.0, kept: false)
            case (.weakValid, _):
                // Original passed the spellchecker (len>=4) — keep (weight 1.5).
                items.append(Pending(output: segment, original: segment, runCount: runs, isMixedScript: mixedScript))
                addEvidence(toA: originalIsA, weight: 1.5, kept: true)
            default:
                // Both invalid (or short pair): context vote decides (§1.2/§1.4).
                // Class F: try splitting glued words before deferring to the vote.
                if let split = splitCandidate(segment, map: map, language: candidateLang) {
                    items.append(Pending(output: split, original: segment, wasConverted: true))
                    addEvidence(toA: originalIsA, weight: 3.0, kept: false)
                } else if let accepted = bigramTieBreakAccepts(candidate: candidate, original: segment, language: candidateLang) {
                    // v1.3 §1.1.2 undecided-case tie-breaker: neither frequency
                    // lists nor the spellchecker validated either side, but the
                    // char-bigram profile clearly prefers the candidate's
                    // language («[bhjcvc» → «хиросмс»). weakValid-equivalent.
                    // When the conversion fused two known words, the accepted
                    // output is already the SEPARATED form (Class F extension).
                    items.append(Pending(output: accepted, original: segment, wasConverted: true))
                    addEvidence(toA: originalIsA, weight: 3.0, kept: false)
                } else {
                    items.append(Pending(
                        output: segment,
                        original: segment,
                        isUndecided: true,
                        candidate: candidate,
                        aLetters: aCount,
                        bLetters: bCount,
                        runCount: runs,
                        isMixedScript: mixedScript
                    ))
                }
            }
        }

        // A-01/FUN-1: deferred single-letter decisions. A single letter
        // converts only when the context proves its CANDIDATE side is the
        // correct one: neighbors already valid on the candidate side, or
        // neighbors that converted AWAY from the letter's own side. Zero or
        // tied context keeps the letter as typed — even when the candidate
        // is a strongValid word («plan b» stays «plan b»).
        for i in items.indices where items[i].isSingleLetterCandidate {
            let tokenIsA = items[i].aLetters >= items[i].bLetters
            let candidateSideRight = tokenIsA ? keptB + convertedAToB : keptA + convertedBToA
            let ownSideRight = tokenIsA ? keptA + convertedBToA : keptB + convertedAToB
            if candidateSideRight > ownSideRight {
                items[i].output = items[i].candidate
                items[i].wasConverted = true
                addEvidence(toA: tokenIsA, weight: 3.0, kept: false)
            }
        }

        // Deferred ambiguous short-word decisions (e.g. "tot yt dct gjyznyj" vs "a tot was playing").
        for i in items.indices where items[i].isAmbiguousToken {
            let tokenIsA = items[i].aLetters >= items[i].bLetters
            let candidateSideRight = tokenIsA ? keptB + convertedAToB : keptA + convertedBToA
            let ownSideRight = tokenIsA ? keptA + convertedBToA : keptB + convertedAToB
            if candidateSideRight > ownSideRight {
                items[i].output = items[i].candidate
                items[i].wasConverted = true
                addEvidence(toA: tokenIsA, weight: 3.0, kept: false)
            } else {
                addEvidence(toA: tokenIsA, weight: 3.0, kept: true)
            }
        }

        // Global vote across undecided tokens (v1.3 §1.2/§1.4).
        let undecidedTokens = items.filter { $0.isUndecided }
        let undecidedA = undecidedTokens.reduce(0) { $0 + $1.aLetters }
        let undecidedB = undecidedTokens.reduce(0) { $0 + $1.bLetters }
        let undecidedTotal = undecidedA + undecidedB
        let undecidedMax = max(undecidedA, undecidedB)
        let undecidedMin = min(undecidedA, undecidedB)
        // Vote units are letter runs: a multi-run token (URL, path, hyphen
        // compound) carries internal segmentation evidence (§1.4).
        let undecidedRuns = undecidedTokens.reduce(0) { $0 + max(1, $1.runCount) }
        // Context bias counts RESOLVED-token evidence only.
        let contextBias = max(aScore, bScore) - min(aScore, bScore)
        // Class C: OCR raises the letter-volume bar.
        let letterThreshold = (source == .ocr) ? 8 : 6

        // Dual gate (§1.4): several undecided units, one with strong one-sided
        // context, or one with resolved evidence on BOTH sides (mixed sentence:
        // the merged vote already knows the direction).
        let mayVote = undecidedRuns >= 2
            || (undecidedRuns == 1 && contextBias >= 3.0)
            || (undecidedRuns == 1 && aScore > 0 && bScore > 0)
        // Strong context (one strong word of evidence) may substitute for
        // volume; resolved evidence on BOTH sides (mixed sentence) likewise.
        let volumeOK = undecidedTotal >= letterThreshold
            || contextBias >= 3.0
            || (aScore > 0 && bScore > 0)
        let ratioOK = undecidedMax >= undecidedMin * 2

        var appliedDirection: Direction?
        if mayVote && volumeOK && ratioOK {
            var effectiveA = aScore + Double(undecidedA)
            var effectiveB = bScore + Double(undecidedB)

            // Class B: hysteresis — the previous direction resists inversion
            // unless the new evidence wins clearly (difference >= bias * 2).
            if let (last, at) = storedDirection(), Date().timeIntervalSince(at) < hysteresisWindow,
               abs(effectiveA - effectiveB) < hysteresisBias * 2 {
                if last == .aToB { effectiveA += hysteresisBias } else { effectiveB += hysteresisBias }
            }

            let convertAToB: Bool
            if effectiveA > effectiveB {
                convertAToB = true
            } else if effectiveB > effectiveA {
                convertAToB = false
            } else {
                convertAToB = tieBreakerAToB()
            }
            appliedDirection = convertAToB ? .aToB : .bToA

            for i in items.indices where items[i].isUndecided {
                // Mixed-script tokens never convert: their candidate is mixed
                // garbage in either direction (§1.5).
                guard !items[i].isMixedScript else { continue }
                // A token is converted when the voted direction matches the
                // form the token is currently in (A-form tokens go A→B, etc.).
                let tokenIsA = items[i].aLetters >= items[i].bLetters
                if convertAToB == tokenIsA {
                    // Quality gate (v1.3 §1.1.2): the vote direction alone must
                    // not push a token into implausible garbage; the candidate
                    // must clear the language's bigram floor.
                    let candidateLanguage = tokenIsA ? languageB : languageA
                    let originalLanguage = tokenIsA ? languageA : languageB
                    guard voteCandidatePlausible(
                        candidate: items[i].candidate,
                        original: items[i].original,
                        candidateLanguage: candidateLanguage,
                        originalLanguage: originalLanguage
                    ) else { continue }
                    items[i].output = items[i].candidate
                    items[i].wasConverted = true
                }
            }
        }

        let changed = items.contains { $0.output != $0.original }
        let hasConverted = items.contains { $0.wasConverted }

        // Dominant source script by merged weighted vote (§1.8).
        let dominantIsA = (aScore + Double(undecidedA)) >= (bScore + Double(undecidedB))
        let dominantScript = dominantIsA
            ? Self.script(forLanguage: languageA)
            : Self.script(forLanguage: languageB)

        // Class B: maintain direction memory. Empty result resets it.
        // A-02/FUN-5: writes go through the locked helpers.
        if undecidedTokens.isEmpty && !hasConverted {
            clearDirectionLocked()
        } else if let direction = appliedDirection {
            storeDirection(direction)
        } else if hasConverted {
            storeDirection(dominantIsA ? .aToB : .bToA)
        }

        return ConversionResult(
            text: items.map { $0.output }.joined(),
            dominantSourceScript: dominantScript,
            changed: changed
        )
    }

    // MARK: - Tokenization

    /// Splits text into alternating non-whitespace / whitespace segments,
    /// preserving every character exactly.
    private func splitPreservingWhitespace(_ text: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var currentIsWhitespace: Bool?

        for char in text {
            let isWhitespace = char.isWhitespace
            if let was = currentIsWhitespace, was != isWhitespace {
                segments.append(current)
                current = ""
            }
            current.append(char)
            currentIsWhitespace = isWhitespace
        }
        if !current.isEmpty {
            segments.append(current)
        }
        return segments
    }

    private func letterRunCount(of token: String) -> Int {
        var count = 0
        var inRun = false
        for ch in token {
            if ch.isLetter {
                if !inRun { count += 1; inRun = true }
            } else {
                inRun = false
            }
        }
        return count
    }

    // MARK: - Protection

    private func isProtected(_ token: String) -> Bool {
        let lower = token.lowercased()

        // Known URL schemes and www-links.
        for scheme in urlSchemes where lower.hasPrefix(scheme) { return true }
        if lower.hasPrefix("www.") { return true }

        // Any embedded URL or markdown link containing a scheme, e.g. [link](https://...)
        for scheme in urlSchemes where token.contains(scheme) { return true }

        // E-mail addresses.
        if token.contains("@") && token.contains(".") { return true }

        // Absolute / home / relative paths.
        if token.hasPrefix("/") || token.hasPrefix("~/") || token.hasPrefix("./") || token.hasPrefix("../") { return true }

        // Common API token / key prefixes
        let tokenPrefixes = ["sk-", "pk-", "ghp_", "gho_", "xoxb-", "eyJ"]
        for pfix in tokenPrefixes where token.hasPrefix(pfix) { return true }

        // Code identifiers, math and curly braces.
        let shiftedCyrillicKeys: Set<Character> = ["<", ">", "{", "}", "[", "]", ";", "'", ":", "\"", "~", ",", "."]
        let strictCodeMarkers: Set<Character> = ["_", "$", "\\", "|", "&", "=", "%", "#", "^"]
        if token.contains(where: { strictCodeMarkers.contains($0) }) { return true }

        // If the token contains <, >, {, }:
        if token.contains(where: { $0 == "<" || $0 == ">" || $0 == "{" || $0 == "}" }) {
            // Check if every character is either a letter or one of the shifted Cyrillic keys
            let isPotentialShiftedWord = token.allSatisfy { ch in
                ch.isLetter || shiftedCyrillicKeys.contains(ch)
            } && token.contains(where: { $0.isLetter })
            
            if !isPotentialShiftedWord {
                return true
            }
        }

        // Identifiers and versions mixing letters with digits.
        let hasLetter = token.contains { $0.isLetter }
        let hasDigit = token.contains { $0.isNumber }
        if hasLetter && hasDigit { return true }

        return false
    }

    /// Class C (OCR): tokens containing digits or symbols outside
    /// allowedPunctuation+letters are OCR noise and never participate.
    private func isOCRProtected(_ token: String) -> Bool {
        for ch in token {
            if ch.isLetter { continue }
            if allowedPunctuation.contains(ch) { continue }
            return true
        }
        return false
    }

    // MARK: - Validation (v1.3 §1.1: three-level trust)

    /// A token is valid when all of its letter runs are valid words and every
    /// non-letter character belongs to the allowed punctuation set. The token
    /// trust is the weakest run trust. Hyphenated compounds («т-шаблонов»,
    /// §1.3) validate part-by-part through the same run mechanism.
    private func classifyToken(_ token: String, language: String) -> WordTrust {
        // Class D: mixed-script tokens are never trusted for either language.
        guard Self.scriptOf(token) != nil else { return .invalid }

        var runs: [String] = []
        var current = ""

        for char in token {
            if char.isLetter {
                current.append(char)
            } else {
                if !current.isEmpty {
                    runs.append(current)
                    current = ""
                }
                if !allowedPunctuation.contains(char) {
                    return .invalid
                }
            }
        }
        if !current.isEmpty {
            runs.append(current)
        }

        guard !runs.isEmpty else { return .invalid }

        var weakest = WordTrust.strongValid
        for run in runs {
            let trust = classifyWord(run, language: language)
            if trust == .invalid { return .invalid }
            if trust == .weakValid { weakest = .weakValid }
        }
        return weakest
    }

    private func classifyWord(_ word: String, language: String) -> WordTrust {
        guard !word.isEmpty else { return .invalid }

        let lower = word.lowercased()

        // Class D: strict single-script words only.
        if language == "ru" {
            guard Self.scriptOf(word) == .cyrillic else { return .invalid }
            // Russian words cannot start with soft sign (ь), hard sign (ъ), or ы.
            if lower.hasPrefix("ь") || lower.hasPrefix("ъ") || lower.hasPrefix("ы") {
                return .invalid
            }
            if Self.hasImpossibleCyrillicCluster(lower) {
                return .invalid
            }
        }
        if language == "en" {
            guard Self.scriptOf(word) == .latin else { return .invalid }
        }

        // Level 1: explicit whitelists — strong trust.
        if language == "ru" && ruFunctionWords.contains(lower) { return .strongValid }
        if language == "en" && enFunctionWords.contains(lower) { return .strongValid }
        if language == "en" && enUnitAbbreviations.contains(lower) { return .strongValid }

        if word.count == 1 {
            switch language {
            case "ru": return ruSingleLetters.contains(lower) ? .strongValid : .invalid
            case "en": return enSingleLetters.contains(lower) ? .strongValid : .invalid
            default: return .strongValid
            }
        }

        // Level 2: frequency lists (§1.1.1) — strong trust. Empty by default.
        // 1–2 letter candidates need a TOP frequency rank: mid-list short
        // forms («nu» @16k) are too weak to beat a layout-typed slang token
        // («тг»), so they fall through to the context vote instead.
        if let rank = frequencyStore.rank(of: lower, language: language),
           rank <= frequencyTopN,
           !(word.count <= 2 && rank > 5_000) {
            return .strongValid
        }

        // Mock dictionary for headless tests — spellchecker-equivalent trust.
        if let isTestWord = testWords[lower] {
            return isTestWord ? .weakValid : .invalid
        }

        // Level 3: spellchecker — trusted ONLY for len >= 4 (Class A: short
        // abbreviations are indistinguishable from typos), with case-insensitive
        // probes (Class E: CAPS forms).
        if word.count >= 4 && spellCheckerSaysValid(word, language: language) {
            return .weakValid
        }

        return .invalid
    }

    /// Class E: the spellchecker probe runs three times (as-is, lowercased,
    /// capitalized); any valid form validates the word.
    private func spellCheckerSaysValid(_ word: String, language: String) -> Bool {
        guard spellCheckerWorks() else { return false }

        // Thread-safe spellchecker verdict cache to eliminate IPC round-trips.
        let lower = word.lowercased()
        let cacheKey = lower.appending("|").appending(language)
        Self.validatedCacheLock.lock()
        let cached = Self.validatedCache[cacheKey]
        Self.validatedCacheLock.unlock()
        if let cached = cached { return cached }

        let probes = [lower, word, word.capitalized]
        let valid = probes.contains { probe in
            let range = NSSpellChecker.shared.checkSpelling(
                of: probe,
                startingAt: 0,
                language: language,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            return range.location == NSNotFound
        }

        Self.validatedCacheLock.lock()
        if Self.validatedCache.count >= Self.validatedCacheLimit,
           let eldest = Self.validatedCache.keys.first {
            Self.validatedCache.removeValue(forKey: eldest)
        }
        Self.validatedCache[cacheKey] = valid
        Self.validatedCacheLock.unlock()
        return valid
    }

    /// Bounded, thread-safe spellchecker verdict cache.
    /// Key: "word|language". Capped at `validatedCacheLimit` entries with FIFO eviction.
    private static let validatedCacheLock = NSLock()
    private static var validatedCache: [String: Bool] = [:]
    private static let validatedCacheLimit = 2048

    // MARK: - Split candidates (v1.3 §1.7, Class F)

    /// Tries to split a glued pair of words. Returns "left right" only when
    /// the split is unambiguous: exactly one valid cut, or a unique
    /// frequency-best among several (ties stay untouched).
    private func splitCandidate(_ token: String, map: [Character: Character], language: String) -> String? {
        let count = token.count
        guard count >= 7, count <= 40 else { return nil }
        // Restrictions: no digits, no inner punctuation, no CAPS (ambiguous cuts).
        guard !token.contains(where: { $0.isNumber }) else { return nil }
        let letterOnly = token.filter { $0.isLetter }
        guard letterOnly == token else { return nil }

        let candWhole = String(token.map { map[$0] ?? $0 })
        let candLower = candWhole.lowercased()
        let origLower = token.lowercased()

        // Protected words that must NEVER be split
        if protectedUnsplitWords.contains(candLower) || protectedUnsplitWords.contains(origLower) {
            return nil
        }

        // If the candidate as a WHOLE is already a valid word or passes spellchecker, NEVER split it!
        if classifyWord(candWhole, language: language) != .invalid ||
           spellCheckerSaysValid(candWhole, language: language) {
            return nil
        }

        var candidates: [(text: String, rank: Int?)] = []
        let chars = Array(token)
        // Maximum one cut per token (v1: no recursive 3+ word splits).
        // Cuts require minimum 3 characters on each side (prevents 2-letter prefix cuts like по-, не-, от-)
        for i in 3...(count - 3) {
            let left = String(chars[0..<i])
            let right = String(chars[i...])
            let lc = String(left.map { map[$0] ?? $0 })
            let rc = String(right.map { map[$0] ?? $0 })

            // Disallow short function words / prepositions as sole left cut piece
            if lc.count <= 3 && (ruFunctionWords.contains(lc.lowercased()) || enFunctionWords.contains(lc.lowercased())) {
                continue
            }

            guard classifyWord(lc, language: language) != .invalid,
                  classifyWord(rc, language: language) != .invalid else { continue }
            candidates.append((lc + " " + rc, rankSum(lc, rc, language: language)))
            if candidates.count >= 3 { break }
        }

        if candidates.count == 1 { return candidates[0].text }
        guard !candidates.isEmpty else { return nil }

        let ranked = candidates.compactMap { entry -> (text: String, rank: Int)? in
            guard let rank = entry.rank else { return nil }
            return (entry.text, rank)
        }
        guard let best = ranked.min(by: { $0.rank < $1.rank }) else { return nil }
        let ties = ranked.filter { $0.rank == best.rank }
        return ties.count == 1 ? best.text : nil
    }

    private func rankSum(_ a: String, _ b: String, language: String) -> Int? {
        let ra = frequencyStore.rank(of: a.lowercased(), language: language)
        let rb = frequencyStore.rank(of: b.lowercased(), language: language)
        switch (ra, rb) {
        case let (l?, r?): return l + r
        case let (l?, nil): return l
        case let (nil, r?): return r
        default: return nil
        }
    }
}
