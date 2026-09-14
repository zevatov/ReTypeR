import XCTest
@testable import ReTypeR

final class LayoutMapperTests: XCTestCase {
    
    override func setUpWithError() throws {
        super.setUp()
        // Ensure ABC and Russian mappings are loaded for the test
        LayoutMapper.shared.refreshAvailableLayouts()
        LayoutMapper.shared.buildBidirectionalMap(
            layoutAID: "com.apple.keylayout.ABC",
            layoutBID: "com.apple.keylayout.Russian"
        )
        // 5а: clear the scorer's direction memory between tests — the suite
        // must not depend on execution order (same as LogRegressionTests).
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
    }
    
    override func tearDownWithError() throws {
        SmartScorer.shared.resetHysteresis()
        try super.tearDownWithError()
    }
    
    func testEnglishToRussianConversion() {
        // Standard word translation: ghjdthbv -> проверим
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv"), "проверим")
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv "), "проверим ")
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv!"), "проверим!")
        
        // Capitalization
        XCTAssertEqual(LayoutMapper.shared.convert("Ghjdthbv"), "Проверим")
        
        // Mixed text
        XCTAssertEqual(LayoutMapper.shared.convert("Ghjdthbv - ntcn"), "Проверим - тест")
    }
    
    func testRussianToEnglishConversion() {
        // Standard word translation: ьн уьфшд -> my email
        XCTAssertEqual(LayoutMapper.shared.convert("ьн уьфшд"), "my email")
        XCTAssertEqual(LayoutMapper.shared.convert("ьн уьфшд!"), "my email!")
        
        // Capitalization
        XCTAssertEqual(LayoutMapper.shared.convert("Ьн уьфшд"), "My email")
    }
    
    func testSpecialCharactersMapping() {
        // Test standard punctuation mapping under Russian Mac layout by placing them inside a word to avoid ties.
        // v1.3 Class G (§1.4): a lone undecided token stays untouched (safe default),
        // so every probe carries the context word «ntcn» (= «тест») whose vote
        // supplies the conversion direction.
        
        // Key 0x29: ; in ABC -> ж in RUS
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv; ntcn"), "проверимж тест")
        XCTAssertEqual(LayoutMapper.shared.convert("проверимж ntcn"), "ghjdthbv; тест")
        
        // Key 0x21: [ in ABC -> х in RUS
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv[ ntcn"), "проверимх тест")
        XCTAssertEqual(LayoutMapper.shared.convert("проверимх ntcn"), "ghjdthbv[ тест")
        
        // Key 0x1e: ] in ABC -> ъ in RUS
        XCTAssertEqual(LayoutMapper.shared.convert("ghjdthbv] ntcn"), "проверимъ тест")
        XCTAssertEqual(LayoutMapper.shared.convert("проверимъ ntcn"), "ghjdthbv] тест")
    }
    
    func testSmartRecognition() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // 1. Text: "Привет, ghbdtn!" (Mixed: Russian is correct, English is wrong)
        XCTAssertEqual(LayoutMapper.shared.convert("Привет, ghbdtn!"), "Привет, привет!")
        
        // 2. Text: "hello, ghbdtn!" (Mixed: English "hello" is correct, "ghbdtn" is wrong)
        XCTAssertEqual(LayoutMapper.shared.convert("hello, ghbdtn!"), "hello, привет!")
        
        // 3. Text: "руддщ, привет!" (Mixed: Russian "привет" is correct, "руддщ" is wrong)
        XCTAssertEqual(LayoutMapper.shared.convert("руддщ, привет!"), "hello, привет!")
    }
    
    // MARK: - v1.2 corpus: short words, prepositions, «ё»
    
    func testShortPrepositionsAndSingleLetters() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // «а оно ещё» typed in the English layout (f = а, jyj = оно, to` = ещё)
        XCTAssertEqual(LayoutMapper.shared.convert("f jyj to`"), "а оно ещё")
        
        // «и я ушёл бы домой, но не смог» typed in the English layout
        // (punctuation pairs like ? → , are not mapped, so the comma is omitted)
        XCTAssertEqual(
            LayoutMapper.shared.convert("b z ei`k ,s ljvjq yj yt cvju"),
            "и я ушёл бы домой но не смог"
        )
        
        // Single-letter prepositions in correct text must stay untouched
        XCTAssertEqual(LayoutMapper.shared.convert("а оно ещё"), "а оно ещё")
    }
    
    func testYoLetterHandling() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // «ёжик» typed in the English layout (` = ё, ; = ж, b = и, r = к)
        XCTAssertEqual(LayoutMapper.shared.convert("`;br"), "ёжик")
        
        // «Ёлка» with capital Ё (~ = Ё)
        XCTAssertEqual(LayoutMapper.shared.convert("~krf"), "Ёлка")
    }
    
    func testURLProtection() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // Correct URLs must never be converted
        XCTAssertEqual(
            LayoutMapper.shared.convert("Привет https://example.com/page?id=42 тест"),
            "Привет https://example.com/page?id=42 тест"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("hello www.example.com test"),
            "hello www.example.com test"
        )
        
        // A URL typed in the wrong layout gets converted back
        XCTAssertEqual(
            LayoutMapper.shared.convert("реезы://учфьзду.сщь"),
            "https://example.com"
        )
    }
    
    func testEmailProtection() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        XCTAssertEqual(
            LayoutMapper.shared.convert("Пиши на test@mail.ru"),
            "Пиши на test@mail.ru"
        )
    }
    
    func testCodeAndIdentifierProtection() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // Code fragments with identifiers, digits and operators stay untouched
        XCTAssertEqual(
            LayoutMapper.shared.convert("let result = my_variable + 12"),
            "let result = my_variable + 12"
        )
        
        // Letter+digit identifiers (versions, codes) are protected
        XCTAssertEqual(LayoutMapper.shared.convert("версия 1.2.0"), "версия 1.2.0")
        XCTAssertEqual(LayoutMapper.shared.convert("патч v2"), "патч v2")
    }
    
    func testShortGarbageFragmentStaysUntouched() {
        // Tiny OCR fragments must never be flipped by the undecided-token vote.
        XCTAssertEqual(LayoutMapper.shared.convert("• USa•C"), "• USa•C")
    }
    
    func testReverseDirectionFullSentence() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // «hello world» typed in the Russian layout
        XCTAssertEqual(LayoutMapper.shared.convert("руддщ цщкдв"), "hello world")
    }
    
    func testSafeDefaultKeepsValidText() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // Fully correct Russian text must not be altered
        XCTAssertEqual(
            LayoutMapper.shared.convert("Привет, это правильный текст."),
            "Привет, это правильный текст."
        )
        
        // Fully correct English text must not be altered
        XCTAssertEqual(
            LayoutMapper.shared.convert("hello test, correct text."),
            "hello test, correct text."
        )
    }
    
    // MARK: - v1.3 spec §3.1: T-C-A1…T-C-H3
    
    /// T-C-A1 (Class A): abbreviations without context stay untouched.
    func testTCA1AbbreviationsWithoutContext() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        XCTAssertEqual(LayoutMapper.shared.convert("ghbdtn kb gb bp"), "привет kb gb bp")
    }
    
    /// T-C-B1 (Class B): consecutive conversions must not oscillate — the
    /// hysteresis keeps the direction stable across calls.
    func testTCB1HysteresisNoOscillation() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
        
        // First call establishes EN→RU direction.
        XCTAssertEqual(LayoutMapper.shared.convert("руддщ цщкдв"), "hello world")
        // Second call: a short token resolves to «тест» (invalid → weakValid
        // spellchecker pair — deterministic, hysteresis cannot flip it).
        XCTAssertEqual(LayoutMapper.shared.convert("ntcn"), "тест")
        SmartScorer.shared.resetHysteresis()
    }
    
    /// T-C-B2 (Class B): weighted vote converts all wrong-layout tokens of one
    /// sentence in a single direction. Spaces instead of commas: the comma key
    /// maps to «б» in the Russian layout (see testSpecialCharactersMapping),
    /// which would pollute the assertion with punctuation-pair noise.
    func testTCB2WeightedVoteSingleDirection() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
        
        XCTAssertEqual(LayoutMapper.shared.convert("Привет ntcn ghbdtn"), "Привет тест привет")
        SmartScorer.shared.resetHysteresis()
    }
    
    /// T-C-D1/D2 (Class D): mixed-script tokens are never converted.
    func testTCD2MixedScriptTokens() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        XCTAssertEqual(LayoutMapper.shared.convert("CustomЕП"), "CustomЕП")
        XCTAssertEqual(LayoutMapper.shared.convert("ЕПtest"), "ЕПtest")
    }
    
    /// T-C-E1/E2 (Class E): CAPS forms convert with case preserved.
    func testTCECapsConversion() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        XCTAssertEqual(LayoutMapper.shared.convert("GHBDTN"), "ПРИВЕТ")
    }
    
    /// T-C-F1 (Class F): glued words split into two valid words or stay
    /// unchanged — never fuse into garbage («ключмоделей»).
    func testTCFGluedWords() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        // The split is deterministic: exactly one unambiguous cut into two
        // known frequency words («ключ» + «моделей»).
        XCTAssertEqual(LayoutMapper.shared.convert("rk.xvjltktq"), "ключ моделей")
    }
    
    /// T-C-G1 (Class G): a lone undecided nickname stays untouched.
    func testTCG1LoneUndecidedTokenUntouched() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        XCTAssertEqual(LayoutMapper.shared.convert("erafox"), "erafox")
    }
    
    /// T-C-G2 (Class G): a lone undecided token next to a strong context word
    /// follows the context direction. Scenario from spec §1.4: the user typed
    /// the nickname «erafox» while in the Russian layout («укфащч»); the
    /// neighbouring strong word supplies the conversion direction.
    func testTCG2ContextAllowsLoneToken() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
        
        XCTAssertEqual(LayoutMapper.shared.convert("Привет, укфащч!"), "Привет, erafox!")
        SmartScorer.shared.resetHysteresis()
    }
    
    /// T-C-H3 (Class H): no conversion → no layout switch. Verified through
    /// the public contract: unchanged input yields changed == false, which is
    /// exactly the engine's no-switch condition.
    func testTCH3NoSwitchWhenUnchanged() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        let result = LayoutMapper.shared.convertDetailed("привет мир", smart: true, source: .hotkey)
        XCTAssertFalse(result.changed)
    }
    
    /// User reference case: transliterated brand name typed in the wrong
    /// layout MUST convert («[bhjcvc» = «хиросмс», Hero SMS).
    func testUserReferenceHeroSMS() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        XCTAssertEqual(LayoutMapper.shared.convert("[bhjcvc"), "хиросмс")
    }
    
    // MARK: - A-01/FUN-1: single letters need context
    
    /// A lone EN letter with a strongValid EN neighbor stays untouched even
    /// though its RU candidate («b» → «и») is a dictionary word. Regression:
    /// «plan b» used to become «plan и».
    func testSingleLetterWithoutContextStays() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
        
        XCTAssertEqual(LayoutMapper.shared.convert("plan b"), "plan b")
        SmartScorer.shared.resetHysteresis()
    }
    
    /// CAPS variant of the same invariant.
    func testSingleCapsLetterWithoutContextStays() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
        
        XCTAssertEqual(LayoutMapper.shared.convert("Plan B"), "Plan B")
        SmartScorer.shared.resetHysteresis()
    }
    
    /// A single EN letter next to strong RU words still converts: the
    /// neighbors prove the text was typed in the wrong layout.
    func testSingleLetterWithContextConverts() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
        
        // «и» between RU words: wrong-layout «b» joins the RU direction.
        XCTAssertEqual(LayoutMapper.shared.convert("оно b ещё"), "оно и ещё")
        SmartScorer.shared.resetHysteresis()
    }
    
    // MARK: - A-04/FUN-4: OCR honors the smart toggle
    
    /// A-04/FUN-4: with smart: false the OCR path must behave exactly like
    /// the hotkey basic mode — per-character mapping, no per-word analysis
    /// (an undecided token that smart mode would keep untouched gets
    /// converted character-by-character in basic mode).
    func testOCRBasicModeMatchesHotkeyBasicMode() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        let input = "руддщ"
        let ocrBasic = LayoutMapper.shared.convertDetailed(input, smart: false, source: .ocr)
        let hotkeyBasic = LayoutMapper.shared.convertDetailed(input, smart: false, source: .hotkey)
        XCTAssertEqual(ocrBasic.text, hotkeyBasic.text)
        XCTAssertEqual(ocrBasic.text, "hello")
        XCTAssertTrue(ocrBasic.changed)
        // Basic mode has no per-token analysis: no dominant script reported.
        XCTAssertNil(ocrBasic.dominantSourceScript)
    }
    
    // MARK: - A-07/MED-3: unified languageCode, nil script → no-switch
    
    /// A-07/MED-3: the engine must resolve layout languages through the SAME
    /// mapper function the scorer uses — German/French/Spanish included. The
    /// removed ConversionEngine duplicate only knew ru/uk/en and answered
    /// "de" with "en", flipping to the WRONG layout on dominant EN.
    func testLanguageCodeKnowsNonRuEnLayouts() {
        XCTAssertEqual(LayoutMapper.languageCode(for: "com.apple.keylayout.German"), "de")
        XCTAssertEqual(LayoutMapper.languageCode(for: "com.apple.keylayout.French"), "fr")
        XCTAssertEqual(LayoutMapper.languageCode(for: "com.apple.keylayout.Spanish"), "es")
        XCTAssertEqual(LayoutMapper.languageCode(for: "com.apple.keylayout.Russian"), "ru")
        XCTAssertEqual(LayoutMapper.languageCode(for: "com.apple.keylayout.ABC"), "en")
    }
    
    /// A-07/MED-3: German primary has NO script in the two-script model.
    /// The engine's guard (`script(forLanguage:) == nil → nil`) must yield a
    /// no-switch decision; asserted through the same public components the
    /// private `targetLayoutID` composes (direct call impossible without a
    /// mock seam — see task report).
    func testNilScriptForGermanPrimaryYieldsNoSwitchInputs() {
        let code = LayoutMapper.languageCode(for: "com.apple.keylayout.German")
        XCTAssertEqual(code, "de")
        // The exact condition the engine guards on: nil script → return nil.
        XCTAssertNil(SmartScorer.script(forLanguage: code))
    }
    
    // MARK: - Edge cases (task 5в)
    
    /// Empty input: no crash, nothing changed.
    func testEmptyStringNoCrashNoChange() {
        let result = LayoutMapper.shared.convertDetailed("", smart: true, source: .hotkey)
        XCTAssertFalse(result.changed)
        XCTAssertEqual(result.text, "")
    }
    
    /// A lone single letter without any context stays as typed (A-01
    /// invariant, isolated from the multi-token cases above).
    func testLoneSingleLetterUntouched() {
        SmartScorer.shared.resetHysteresis()
        
        XCTAssertEqual(LayoutMapper.shared.convert("b"), "b")
        SmartScorer.shared.resetHysteresis()
    }
    
    /// Emoji-only text carries no votes and must pass through untouched.
    func testEmojiOnlyUntouched() {
        let result = LayoutMapper.shared.convertDetailed("👍😂", smart: true, source: .hotkey)
        XCTAssertFalse(result.changed)
        XCTAssertEqual(result.text, "👍😂")
    }
    
    /// Basic mode (smart: false) converts character-by-character regardless
    /// of word validity; smart mode is the one that keeps undecided tokens
    /// untouched («erafox» case, covered by testTCG1).
    func testBasicModeIsPerCharacter() {
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        
        let basic = LayoutMapper.shared.convertDetailed("ghbdtn", smart: false, source: .hotkey)
        XCTAssertEqual(basic.text, "привет")
        XCTAssertTrue(basic.changed)
        
        // A token undecided in smart mode («erafox», no dictionary/bigram
        // verdict) is kept as typed; basic mode mangles it per-character
        // (e→у r→к a→ф f→а o→щ x→ч).
        let smartUndecided = LayoutMapper.shared.convertDetailed("erafox", smart: true, source: .hotkey)
        XCTAssertEqual(smartUndecided.text, "erafox")
        let basicUndecided = LayoutMapper.shared.convertDetailed("erafox", smart: false, source: .hotkey)
        XCTAssertEqual(basicUndecided.text, "укфащч")
    }
    
    /// Regression test: aToBMap and bToAMap must be automatically built
    /// even if buildBidirectionalMap was not manually called in test setup.
    func testLazyInitializationRebuildsEmptyMapping() {
        LayoutMapper.shared.aToBMap = [:]
        LayoutMapper.shared.bToAMap = [:]
        
        let result = LayoutMapper.shared.convertDetailed("ghbdtn", smart: false, source: .hotkey)
        XCTAssertFalse(LayoutMapper.shared.aToBMap.isEmpty, "aToBMap must not be empty after conversion")
        XCTAssertFalse(LayoutMapper.shared.bToAMap.isEmpty, "bToAMap must not be empty after conversion")
        XCTAssertEqual(result.text, "привет")
        XCTAssertTrue(result.changed)
    }
}
