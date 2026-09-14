import XCTest
@testable import ReTypeR

/// Regression pairs taken verbatim from the v1.2 production log
/// (`~/Library/Application Support/ReTypeR/conversion_log.jsonl`).
/// Each case reproduces a real user-visible failure; expectations follow the
/// task's ground truth, not the logged (buggy) output.
final class LogRegressionTests: XCTestCase {

    override func setUpWithError() throws {
        LayoutMapper.shared.refreshAvailableLayouts()
        LayoutMapper.shared.buildBidirectionalMap(
            layoutAID: "com.apple.keylayout.ABC",
            layoutBID: "com.apple.keylayout.Russian"
        )
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
    }

    override func tearDownWithError() throws {
        SmartScorer.shared.resetHysteresis()
    }

    private func convert(_ text: String) -> String {
        LayoutMapper.shared.convert(text, smart: true, source: .hotkey)
    }

    /// Log: `tcnm ,tpkbvbnyst ,tcgkfnyst vjltkb` was left half-converted.
    /// NOTE: the task's expected «платные» is unreachable honestly — in the
    /// Russian Mac layout `,` maps to «б», so `,tcgkfnyst` yields
    /// «бесплатные», and the full run converts to «есть безлимитные
    /// бесплатные модели». The regression target is "fully converted RU run",
    /// which this asserts.
    func testLog01FreePaidModels() {
        XCTAssertEqual(convert("tcnm ,tpkbvbnyst ,tcgkfnyst vjltkb"),
                       "есть безлимитные бесплатные модели")
    }

    /// Mixed phrase: RU part must survive, EN fragment must still convert.
    func testLog02MixedPhraseRuPartUntouched() {
        let input = "800к токенов на Гемени + 0.1$ за привязку тг + tcnm ,tpkbvbnyst ,tcgkfnyst vjltkb"
        let output = convert(input)
        // RU-часть не портится.
        XCTAssertTrue(output.contains("800к токенов"), "RU part damaged: \(output)")
        XCTAssertTrue(output.contains("Гемени"), "word-like «Гемени» must stay: \(output)")
        XCTAssertTrue(output.contains("привязку тг"), "slang «тг» must stay: \(output)")
        // EN-набор конвертируется в RU-слова.
        XCTAssertTrue(output.contains("есть безлимитные бесплатные модели"),
                      "EN run not converted: \(output)")
    }

    /// Log: `PFGECNB KJRFK[JCN` produced `ЗАПУСТИ KJRFK[JCN` (CAPS lost).
    func testLog03CapsLaunchLocalhost() {
        XCTAssertEqual(convert("PFGECNB KJRFK[JCN"), "ЗАПУСТИ ЛОКАЛХОСТ")
    }

    /// Log: `NTCNS FCCTNJD` produced `NTCNS АССЕТОВ` (first word lost).
    /// NOTE: `ntcns` maps to «тесты» (plural) per the actual layout map, so
    /// the honest full conversion is «ТЕСТЫ АССЕТОВ»; the v1.2 bug (losing
    /// the first word) is what must not recur.
    func testLog04CapsTestAssets() {
        XCTAssertEqual(convert("NTCNS FCCTNJD"), "ТЕСТЫ АССЕТОВ")
    }

    /// Log: lone nickname `erafox` became `укфащч`.
    func testLog05LoneNicknameErafoxUntouched() {
        XCTAssertEqual(convert("erafox"), "erafox")
    }

    /// Log: OCR-ish garbage `• USa•C` became `• ГЫф•С`.
    func testLog06BulletGarbageUntouched() {
        XCTAssertEqual(convert("• USa•C"), "• USa•C")
    }

    /// Log: hyphenated OCR junk must never flip. Per spec §1.3/T-C-C1 this is
    /// an OCR-source rule; the hotkey path legitimately converts the second
    /// fragment («n-if,kjyjd» → «т-шаблонов»).
    func testLog07HyphenatedOcrJunkUntouched() {
        XCTAssertEqual(
            LayoutMapper.shared.convert("т-шаблонов n-if,kjyjd", smart: true, source: .ocr),
            "т-шаблонов n-if,kjyjd"
        )
    }

    /// User reference (Hero SMS transliteration): MUST convert exactly so.
    func testLog08HeroSMSTransliteration() {
        XCTAssertEqual(convert("[bhjcvc"), "хиросмс")
    }

    /// Canonical greeting with SI units kept intact.
    func testLog09GreetingWithUnits() {
        XCTAssertEqual(convert("ghbdtn kb gb bp"), "привет kb gb bp")
    }

    /// Glued words: split into two valid words or stay unchanged — never fuse
    /// into «ключмоделей».
    func testLog10GluedKeyModels() {
        let output = convert("rk.xvjltktq")
        XCTAssertTrue(output == "ключ моделей" || output == "rk.xvjltktq",
                      "expected split or unchanged, got \(output)")
    }
}

/// Regression guard for the v1.3 "bare v" bug: the clipboard-fallback copy
/// step posted `virtualKey: 9` with empty flags — i.e. a bare `v` keystroke
/// (`kVK_ANSI_V = 0x09`) instead of Cmd+C (`kVK_ANSI_C = 0x08`). The typed
/// character replaced the user's selection and the conversion silently
/// aborted. Also: select-all posted `virtualKey: 7` — `kVK_ANSI_X`, a Cut,
/// not a Select All. These tests pin the synthetic-key mapping to HIToolbox
/// `Events.h` values so the codes can never silently drift again.
final class SyntheticKeyRegressionTests: XCTestCase {

    /// HIToolbox Events.h: kVK_ANSI_A = 0x00.
    func testSelectAllUsesANSIAWithCommand() {
        let key = TextService.SyntheticKey.selectAll
        XCTAssertEqual(key.virtualKey, 0x00,
                       "Select-all must be kVK_ANSI_A (0x00); 0x07 is kVK_ANSI_X — a Cut, not a Select All")
        XCTAssertEqual(key.flags, .maskCommand, "Select-all requires the Command modifier")
    }

    /// HIToolbox Events.h: kVK_ANSI_C = 0x08. The v1.3 bug posted 0x09 (V)
    /// with no flags → literal "v" typed into the focused field.
    func testCopyUsesANSICWithCommand() {
        let key = TextService.SyntheticKey.copy
        XCTAssertEqual(key.virtualKey, 0x08,
                       "Copy must be kVK_ANSI_C (0x08); 0x09 is kVK_ANSI_V — the 'bare v' regression")
        XCTAssertEqual(key.flags, .maskCommand, "Copy requires the Command modifier; empty flags typed a literal 'v'")
    }

    /// HIToolbox Events.h: kVK_ANSI_V = 0x09.
    func testPasteUsesANSIVWithCommand() {
        let key = TextService.SyntheticKey.paste
        XCTAssertEqual(key.virtualKey, 0x09, "Paste must be kVK_ANSI_V (0x09)")
        XCTAssertEqual(key.flags, .maskCommand, "Paste requires the Command modifier; without it a bare 'v' is typed")
    }

    /// The three shortcuts must map to three distinct physical keys —
    /// a collision would make one shortcut trigger another action.
    func testShortcutsAreDistinctKeys() {
        let codes = [
            TextService.SyntheticKey.selectAll.virtualKey,
            TextService.SyntheticKey.copy.virtualKey,
            TextService.SyntheticKey.paste.virtualKey,
        ]
        XCTAssertEqual(Set(codes).count, 3, "SelectAll/Copy/Paste must use distinct virtual key codes")
    }
}
