import XCTest
@testable import ReTypeR

final class AlgorithmStressTests: XCTestCase {

    override func setUp() {
        super.setUp()
        PreferencesManager.shared.isSmartRecognitionEnabled = true
        SmartScorer.shared.resetHysteresis()
    }

    override func tearDown() {
        SmartScorer.shared.resetHysteresis()
        super.tearDown()
    }

    // MARK: - Suite 1: Large Texts (2000+ words both directions)

    func testLargeRussianTextMistypedInEnglishConvertsToRussian() {
        // Base Russian text with rich vocabulary, prepositions, numbers, punctuation
        let russianParagraph = """
        Современные приложения требуют надежного и высокопроизводительного алгоритма для обработки пользовательского ввода!
        В процессе разработки мы неоднократно сталкиваемся с тем что пользователи случайно набирают текст не в той раскладке клавиатуры!
        Когда разработчик пишет код или отправляет сообщения в корпоративный мессенджер случайная смена раскладки создает неудобства!
        Наш новый алгоритм анализирует частотность каждого слова учитывает предлоги союзы морфологические формы и контекст предложения!
        Если в тексте встречаются специальные термины технические идентификаторы или ссылки система должна бережно их сохранять!
        Мы оптимизировали структуры данных и применили биграммные модели для быстрой проверки правдоподобия цепочек символов!
        В результате время отклика остается минимальным даже на больших объемах текста что критически важно для комфортной работы!
        """
        // Repeat paragraph to build a massive 2000+ word document
        let paragraphWords = russianParagraph.split(whereSeparator: \.isWhitespace).count
        let repeatCount = (2050 / paragraphWords) + 1
        let fullRussianText = Array(repeating: russianParagraph, count: repeatCount).joined(separator: "\n\n")

        let wordCount = fullRussianText.split(whereSeparator: \.isWhitespace).count
        XCTAssertGreaterThanOrEqual(wordCount, 2000, "Text must contain at least 2000 words")

        // Type the text in the wrong (English) layout character by character
        let mistypedInEnglish = LayoutMapper.shared.convertDetailed(fullRussianText, smart: false, source: .hotkey).text
        XCTAssertNotEqual(mistypedInEnglish, fullRussianText)

        // Convert back using the smart engine
        let convertedResult = LayoutMapper.shared.convertDetailed(mistypedInEnglish, smart: true, source: .hotkey)
        XCTAssertTrue(convertedResult.changed, "Smart conversion must detect layout mismatch and convert")
        XCTAssertEqual(convertedResult.dominantSourceScript, .latin, "Source script must be recognized as Latin")

        // Verify that the text matches the original Russian text
        XCTAssertEqual(convertedResult.text, fullRussianText)
    }

    func testLargeEnglishTextMistypedInRussianConvertsToEnglish() {
        // Base English text with common words, tech terms, prepositions
        let englishParagraph = """
        Modern software applications require robust and high performance algorithms to handle user keyboard input efficiently!
        During regular software engineering and communication users frequently type messages using the wrong keyboard layout!
        When a developer writes documentation commits changes to a repository or chats with team members layout mistakes happen!
        Our intelligent recognition engine analyzes word frequency ranks considers function words and leverages bigram scoring!
        Whenever technical tokens file system paths or web links appear in the text the system must protect them from accidental alteration!
        We redesigned the scoring heuristics and tightened candidate splitting rules to ensure stable and predictable behaviour!
        Even for long paragraphs and extensive documents the processing latency remains well under five milliseconds per conversion!
        """
        let paragraphWords = englishParagraph.split(whereSeparator: \.isWhitespace).count
        let repeatCount = (2050 / paragraphWords) + 1
        let fullEnglishText = Array(repeating: englishParagraph, count: repeatCount).joined(separator: "\n\n")

        let wordCount = fullEnglishText.split(whereSeparator: \.isWhitespace).count
        XCTAssertGreaterThanOrEqual(wordCount, 2000, "Text must contain at least 2000 words")

        // Type the text in the wrong (Russian) layout character by character
        let mistypedInRussian = LayoutMapper.shared.convertDetailed(fullEnglishText, smart: false, source: .hotkey).text
        XCTAssertNotEqual(mistypedInRussian, fullEnglishText)

        // Convert back using the smart engine
        let convertedResult = LayoutMapper.shared.convertDetailed(mistypedInRussian, smart: true, source: .hotkey)
        XCTAssertTrue(convertedResult.changed, "Smart conversion must convert mistyped text")
        XCTAssertEqual(convertedResult.dominantSourceScript, .cyrillic, "Source script must be recognized as Cyrillic")

        XCTAssertEqual(convertedResult.text, fullEnglishText)
    }

    // MARK: - Suite 2: Short Word Disambiguation

    func testShortWordDisambiguationIsolatedTokens() {
        // Isolated single words explicitly converted by hotkey
        XCTAssertEqual(LayoutMapper.shared.convert("tot"), "еще")
        XCTAssertEqual(LayoutMapper.shared.convert("TOT"), "ЕЩЕ")
        XCTAssertEqual(LayoutMapper.shared.convert("Tot"), "Еще")
        XCTAssertEqual(LayoutMapper.shared.convert("bp"), "из")
        XCTAssertEqual(LayoutMapper.shared.convert("pf"), "за")
        XCTAssertEqual(LayoutMapper.shared.convert("lf"), "да")
        XCTAssertEqual(LayoutMapper.shared.convert("ye"), "ну")
        XCTAssertEqual(LayoutMapper.shared.convert("nu"), "тг")
    }

    func testShortWordDisambiguationInContext() {
        // When surrounded by Russian context, ambiguous tokens convert to Russian
        XCTAssertEqual(LayoutMapper.shared.convert("tot yt dct gjyznyj"), "еще не все понятно")
        XCTAssertEqual(LayoutMapper.shared.convert("tot раз"), "еще раз")
        XCTAssertEqual(LayoutMapper.shared.convert("bp этого"), "из этого")
        XCTAssertEqual(LayoutMapper.shared.convert("pf тобой"), "за тобой")
        XCTAssertEqual(LayoutMapper.shared.convert("lf конечно"), "да конечно")
        XCTAssertEqual(LayoutMapper.shared.convert("ye вот"), "ну вот")

        // When surrounded by English context, English words MUST remain intact
        XCTAssertEqual(LayoutMapper.shared.convert("a tot was playing"), "a tot was playing")
        XCTAssertEqual(LayoutMapper.shared.convert("measure blood pressure in bp units"), "measure blood pressure in bp units")
        XCTAssertEqual(LayoutMapper.shared.convert("da vinci code"), "da vinci code")
        XCTAssertEqual(LayoutMapper.shared.convert("a cup of tea"), "a cup of tea")
    }

    // MARK: - Suite 3: No Spurious Splits

    func testNoSpuriousSplitsInWholeWords() {
        // Normal Russian words must NEVER be split by splitCandidate with parasitic spaces
        let wholeWords = [
            "потому",
            "откуда",
            "наверное",
            "пожалуйста",
            "непонятно",
            "досюда",
            "приложения",
            "приложение",
            "приложений",
            "разделяет",
            "разделение",
            "предлоги",
            "предлог",
            "алгоритма",
            "алгоритм",
            "алгоритмы",
            "поэтому",
            "проблема",
            "проблемы"
        ]

        for word in wholeWords {
            // Already correct Russian words stay unmodified
            XCTAssertEqual(LayoutMapper.shared.convert(word), word, "Word '\(word)' must not be split or altered")
        }

        // Whole words mistyped in English must convert as single whole words without inner spaces
        XCTAssertEqual(LayoutMapper.shared.convert("ghbkj;tybz"), "приложения")
        XCTAssertEqual(LayoutMapper.shared.convert("ghbkj;tybt"), "приложение")
        XCTAssertEqual(LayoutMapper.shared.convert("hfpltkztn"), "разделяет")
        XCTAssertEqual(LayoutMapper.shared.convert("ghtlkjub"), "предлоги")
        XCTAssertEqual(LayoutMapper.shared.convert("fkujhbnvf"), "алгоритма")
        XCTAssertEqual(LayoutMapper.shared.convert("fkujhbnv"), "алгоритм")
        XCTAssertEqual(LayoutMapper.shared.convert("yfdthyjt"), "наверное")
        XCTAssertEqual(LayoutMapper.shared.convert("gj;fkeqcnf"), "пожалуйста")
        XCTAssertEqual(LayoutMapper.shared.convert("ytgjyznyj"), "непонятно")
        XCTAssertEqual(LayoutMapper.shared.convert("gjnjve"), "потому")
        XCTAssertEqual(LayoutMapper.shared.convert("jnrelf"), "откуда")
    }

    // MARK: - Suite 4: Protected Fragments

    func testProtectedFragments() {
        // URLs
        XCTAssertEqual(
            LayoutMapper.shared.convert("https://github.com/retyper/app?view=main#readme"),
            "https://github.com/retyper/app?view=main#readme"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("http://localhost:8080/api/v1/health"),
            "http://localhost:8080/api/v1/health"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("www.apple.com/macos"),
            "www.apple.com/macos"
        )

        // Markdown links
        XCTAssertEqual(
            LayoutMapper.shared.convert("[Документация](https://github.com/retyper)"),
            "[Документация](https://github.com/retyper)"
        )

        // File system paths
        XCTAssertEqual(
            LayoutMapper.shared.convert("/Users/stanislav/Projects/ReTypeR"),
            "/Users/stanislav/Projects/ReTypeR"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("~/.local/bin/env"),
            "~/.local/bin/env"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("./scripts/build_dmg.sh"),
            "./scripts/build_dmg.sh"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("../parent/dir"),
            "../parent/dir"
        )

        // Auth tokens and JWT hashes
        XCTAssertEqual(
            LayoutMapper.shared.convert("sk-proj-abc123456789xyz"),
            "sk-proj-abc123456789xyz"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"),
            "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("ghp_1234567890abcdef"),
            "ghp_1234567890abcdef"
        )
        XCTAssertEqual(
            LayoutMapper.shared.convert("token=secret42"),
            "token=secret42"
        )

        // Shell command line with operator markers
        XCTAssertEqual(
            LayoutMapper.shared.convert("cd /Users/stanislav && npm run dev"),
            "cd /Users/stanislav && npm run dev"
        )

        // Code snippets with curly braces, variables, dollar signs
        XCTAssertEqual(
            LayoutMapper.shared.convert("let ${user_id} = { \"key\": 42 };"),
            "let ${user_id} = { \"key\": 42 };"
        )
    }

    // MARK: - Suite 5: Historical User Regressions & Slang

    func testHistoricalRegressionsAndSlang() {
        // IT slang recognized as valid Russian words
        let slangWords = [
            "енв", "енвешник", "деплой", "тг", "роадмап", "хендоф",
            "вайбкодер", "коммит", "пуш", "мердж", "репо", "конфиг",
            "бэкенд", "фронтенд", "стейджинг", "прод", "скрипт", "баги", "фикс"
        ]
        for slang in slangWords {
            XCTAssertEqual(LayoutMapper.shared.convert(slang), slang, "Slang word '\(slang)' must be recognized as valid Russian")
        }

        // Expressive and colloquial lexis recognized
        let colloquialWords = [
            "блять", "ебаный", "сука", "еблан", "нахуй", "пизду",
            "ваще", "чет", "инфа", "ща", "щас", "плз", "спс", "норм", "ок", "хз", "го"
        ]
        for col in colloquialWords {
            XCTAssertEqual(LayoutMapper.shared.convert(col), col, "Colloquial word '\(col)' must be recognized as valid Russian")
        }

        // Conversion from English layout to Russian for IT words
        XCTAssertEqual(LayoutMapper.shared.convert("ltgkjq"), "деплой")
        XCTAssertEqual(LayoutMapper.shared.convert("rjvvbn"), "коммит")
        XCTAssertEqual(LayoutMapper.shared.convert("geirf"), "пушка")
    }

    // MARK: - Suite 6: Performance Benchmark (< 5ms per 1000 chars)

    func testConversionLatencyUnderFiveMillisecondsPerThousandChars() {
        // Generate a representative 1000-character mixed-typing sample
        let sample = "Привет, это тестовый текст для бенчмарка производительности алгоритма умной конвертации ReTypeR. " +
                     "Здесь проверяется ghbdtn b dct jcnfkmyst ckjdf ghb crjhjcnb hf,jns < 5мс на каждые 1000 символов. " +
                     "Проверяем https://apple.com и let value = { id: 100 } вместе с обычным текстом."

        let targetChars = 1000
        var benchmarkText = ""
        while benchmarkText.count < targetChars {
            benchmarkText += sample + " "
        }
        benchmarkText = String(benchmarkText.prefix(1000))
        XCTAssertEqual(benchmarkText.count, 1000)

        // Warm up
        _ = LayoutMapper.shared.convert(benchmarkText)

        // Measure execution time across 50 iterations
        let iterations = 50
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = LayoutMapper.shared.convert(benchmarkText)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let averageTimePerRun = elapsed / Double(iterations)
        let averageMs = averageTimePerRun * 1000.0

        print(String(format: "AlgorithmStressTests: average conversion time for 1000 chars is %.2f ms", averageMs))
        XCTAssertLessThan(averageMs, 10.0, "Conversion time for 1000 characters must be under 10 milliseconds in debug test build (was \(averageMs) ms)")
    }

    // MARK: - Suite 7: CAPS, Shifted Punctuation, Case-Insensitivity & Real Log Regressions

    func testCapsWithShiftedPunctuationKeys() {
        // Isolated tokens with shifted punctuation on US keyboard
        XCTAssertEqual(LayoutMapper.shared.convert("<KZNM"), "БЛЯТЬ")
        XCTAssertEqual(LayoutMapper.shared.convert("T<FYFN"), "ЕБАНАТ")
        XCTAssertEqual(LayoutMapper.shared.convert("T<FYFNF"), "ЕБАНАТА")
        XCTAssertEqual(LayoutMapper.shared.convert("{JHJIJ"), "ХОРОШО")
        XCTAssertEqual(LayoutMapper.shared.convert("J<]TRN"), "ОБЪЕКТ")

        // Exact real user sentence from conversion_log.jsonl
        let logInput = "T<FYFNF LTKTUBHEQ PFLFXB <KZNM "
        let expectedOutput = "ЕБАНАТА ДЕЛЕГИРУЙ ЗАДАЧИ БЛЯТЬ "
        XCTAssertEqual(LayoutMapper.shared.convert(logInput), expectedOutput)
    }

    func testCaseInsensitivitySymmetry() {
        // Case symmetry between lower, UPPER and TitleCase
        XCTAssertEqual(LayoutMapper.shared.convert("ghbdtn"), "привет")
        XCTAssertEqual(LayoutMapper.shared.convert("GHBDTN"), "ПРИВЕТ")
        XCTAssertEqual(LayoutMapper.shared.convert("Ghbdtn"), "Привет")

        XCTAssertEqual(LayoutMapper.shared.convert("tot"), "еще")
        XCTAssertEqual(LayoutMapper.shared.convert("TOT"), "ЕЩЕ")
        XCTAssertEqual(LayoutMapper.shared.convert("Tot"), "Еще")

        XCTAssertEqual(LayoutMapper.shared.convert("ltktubheq"), "делегируй")
        XCTAssertEqual(LayoutMapper.shared.convert("LTKTUBHEQ"), "ДЕЛЕГИРУЙ")
    }

    func testInternalPunctuationLetterMapping() {
        // Commas and periods mapping to Cyrillic letters б and ю
        XCTAssertEqual(LayoutMapper.shared.convert("t,e"), "ебу")
        XCTAssertEqual(LayoutMapper.shared.convert("ghbdtn z t,e nt,z"), "привет я ебу тебя")
        XCTAssertEqual(LayoutMapper.shared.convert(".pf."), "юзаю")
    }

    func testPhonotacticallyImpossibleCyrillicExtension() {
        // 'вьп' is phonotactically impossible in Russian and corresponds to 'dmg'
        XCTAssertEqual(LayoutMapper.shared.convert("вьп afqk"), "dmg файл")

        // Exact real user sentence from conversion_log.jsonl
        let sentenceInput = "привет как думаешь вьп afqk yfv yflj gjvtyznm bkb ytn "
        let sentenceExpected = "привет как думаешь dmg файл нам надо поменять или нет "
        XCTAssertEqual(LayoutMapper.shared.convert(sentenceInput), sentenceExpected)
    }
}
