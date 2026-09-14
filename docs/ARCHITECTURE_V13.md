# ReTypeR v1.3 — Архитектурная спецификация: алгоритм конвертации (A–H) и OCR для защищённых чатов

> **⚠️ HISTORICAL / REMOVED FROM PROD (2026-09-14).** Часть 2 этой спеки (OCR,
> Approach S, `screencapture` CLI, ScreenCaptureKit) описывает функцию, которая
> **удалена из прод-кода 2026-09-14**: [`Sources/Core/OCRService.swift`](../Sources/Core/OCRService.swift)
> не существует, `NSScreenCaptureUsageDescription` и Screen Recording убраны,
> хоткей `ocrCapture` и pref `isOCRModeEnabled` удалены. Текст ниже сохранён
> дословно как историческая спека — руководством к внедрению OCR не является.
> Часть 1 (алгоритм конвертации A–H) остаётся актуальной; упомянутый в классе C
> [`ConversionSource`](../Sources/Core/SmartScorer.swift:8) сохранён в коде как
> внутренний scoring-флаг (тесты
> `testOCRBasicModeMatchesHotkeyBasicMode`, `testLog07HyphenatedOcrJunkUntouched`).
> Ручные сценарии T-O-01…T-O-08 из Части 3 — removed / N/A
> ([`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md)).

> **Provenance.** Документ восстановлен дословно из экспорта истории чата
> [`roo_task_aug-23-2026_12-15-44-pm.md`](../roo_task_aug-23-2026_12-15-44-pm.md:5282)
> (оригинал создан 2026-08-23, read-back внутри экспорта — строки 5282–5919).
> Дата восстановления: 2026-08-25. Ссылки на файлы приведены к относительным путям
> этого репозитория; текст спецификации ниже не редактировался.

> Статус (исторический): implementation spec. База: диагностика Child A (8 классов багов).
> Ограничение: позиционирование окон, дизайн и UX не меняются. Меняются только
> [`SmartScorer`](../Sources/Core/SmartScorer.swift), [`LayoutMapper`](../Sources/Core/LayoutMapper.swift),
> [`ConversionEngine`](../Sources/Core/ConversionEngine.swift) (только шаг 4) и
> [`OCRService.captureAndRecognize()`](../Sources/Core/OCRService.swift:98)
> (последний — удалён из прод-кода 2026-09-14, ссылка историческая).

---

## Часть 1. Алгоритм конвертации — фиксы классов A–H

### 1.0 Текущая архитектура (as-is)

Пайплайн: [`ConversionEngine.performConversion()`](../Sources/Core/ConversionEngine.swift:22)
→ [`LayoutMapper.convert(_:smart:)`](../Sources/Core/LayoutMapper.swift:108)
→ [`SmartScorer.convert()`](../Sources/Core/SmartScorer.swift:120).

Ключевые точки отказа (подтверждено кодом):

| Класс | Причина в коде | Место |
|---|---|---|
| A | `isValidWord()` доверяет NSSpellChecker любому len≥2 токену-аббревиатуре | [`SmartScorer.isValidToken()`](../Sources/Core/SmartScorer.swift:174) |
| B | Голос считают только undecided-токены (`$1.isUndecided`), valid-токены игнорируются; нет памяти направления | [`SmartScorer.convert()`](../Sources/Core/SmartScorer.swift:190) |
| C | OCR-мусор проходит как «undecided» и голосует вместе с настоящими опечатками | там же |
| D | `isLatin()`/`isCyrillic()` используют `contains` — смешанный токен `CustomЕП` валиден | [`SmartScorer.isCyrillic()`](../Sources/Core/SmartScorer.swift:342) |
| E | CAPS-логика отсутствует явно; подозрение на устаревший рантайм | — |
| F | Нет эвристики разделения слипшихся слов | — |
| G | Порог голоса в буквах (`>= 6`) — один длинный никнейм перевешивает | [`SmartScorer.convert()`](../Sources/Core/SmartScorer.swift:198) |
| H | `targetLayoutID` считается по input до конвертации; tie-breaker дублируется | [`ConversionEngine.performConversion()`](../Sources/Core/ConversionEngine.swift:46), [`LayoutMapper.tieBreakPrefersAToB()`](../Sources/Core/LayoutMapper.swift:165) |

---

### 1.1 Класс A — короткие слова и аббревиатуры

**Проблема.** `kb`, `bb`, `gb`, `ye`, `tot`, `bp`: NSSpellChecker признаёт их валидными
(аббревиатуры есть во встроенных словарях), срабатывает ранний skip в
[`isValidToken(segment:)`](../Sources/Core/SmartScorer.swift:174) — токен никогда не конвертируется.

**Дизайн решения — трёхуровневая валидация вместо бинарной.**

Вводим перечисление `WordTrust` и функцию `classifyWord()`:

```swift
enum WordTrust { case strongValid, weakValid, invalid }

// Псевдокод замены isValidWord():
func classifyWord(_ word: String, language: String) -> WordTrust {
    let lower = word.lowercased()

    // Уровень 1: явные белые списки — сильное доверие.
    if language == "ru" && ruFunctionWords.contains(lower) { return .strongValid }
    if language == "en" && enFunctionWords.contains(lower) { return .strongValid }
    if word.count == 1 && singleLetters(language).contains(lower) { return .strongValid }

    // Уровень 2: частотные списки топ-N (новый ресурс, см. §1.1.1).
    if frequencyRank(lower, language: language) <= topN { return .strongValid }

    // Уровень 3: spellchecker — доверие ТОЛЬКО при len >= 4.
    // Для len 2..3 spellchecker-валидность НЕ считается доказательством:
    // аббревиатуры ("kb", "gb", "bp") неотличимы от опечатки раскладки.
    if word.count >= 4 && spellCheckerSaysValid(word, language) { return .weakValid }

    return .invalid
}
```

**Правила использования trust в [`convert()`](../Sources/Core/SmartScorer.swift:149):**

```swift
let originalTrust = classifyToken(segment, originalLang)
let candidateTrust = classifyToken(candidate, candidateLang)

switch (originalTrust, candidateTrust) {
case (.strongValid, _):
    keep(segment)                       // исходник точно слово — не трогаем
case (_, .strongValid) where originalTrust != .strongValid:
    output(candidate)                   // кандидат — точное слово, исходник нет
case (.invalid, .weakValid):
    output(candidate)                   // len>=4: spellchecker-кандидат принимаем
case (.weakValid, _):
    keep(segment)                       // исходник len>=4 прошёл spellchecker — не трогаем
default:
    // оба invalid ИЛИ короткая пара (len<=3): решает контекстное голосование (§1.2)
    markUndecided(...)
}
```

Ключевой инвариант: **для токенов длиной ≤3 символов spellchecker больше не является
арбитром**. Пара («валидная аббревиатура», «валидное слово другой раскладки») уходит в
голосование, где контекст предложения (§1.2) почти всегда даёт правильный ответ.

#### 1.1.1 Новый ресурс: частотные списки

- Формат: два файла `Resources/frequency_ru.txt`, `Resources/frequency_en.txt`
  (одно слово на строку, по убыванию частоты; источники — открытые корпусы:
  OpenCorpora top-list / Google Books Ngrams top-50k, лицензии совместимы).
- Загрузка ленивая, один раз, в `Set<String>` + `Dictionary<String, Int>` рангов;
  память ~1–2 МБ на язык при топ-30k.
- API: `private func frequencyRank(_ word: String, language: String) -> Int?`.
- Расширяемость: пользовательский словарь `~/Library/Application Support/ReTypeR/user_words.json`
  мержится поверх (приоритет выше частотного списка) — закрывает ники/жаргон.

**Компромисс:** топ-N списки добавляют ~2 МБ в бандл. Альтернатива (Core ML-классификатор)
уже отклонена проектом ради размера ([заметка проекта](https://obsidian)).

---

### 1.2 Класс B — осцилляция направления (строки 42↔43 лога)

**Проблема.** В [`convert()`](../Sources/Core/SmartScorer.swift:189) голосуют только
undecided-токены. Valid-токены (сильные свидетельства направления!) исключены из голоса,
и гистерезиса нет → соседние вызовы дают разные направления.

**Дизайн:**

1. **Все решённые токены участвуют в голосе с весом.**

```swift
struct Vote {
    var aScore: Double = 0   // свидетельство «исходник был в раскладке A»
    var bScore: Double = 0
}

// Вес свидетельства зависит от типа токена:
//   strongValid-слово исходника  → вес 3.0 (почти доказательство)
//   weakValid-слово исходника    → вес 1.5
//   undecided-токен              → вес 1.0 на каждую букву (как сейчас)
for item in items {
    switch item.resolution {
    case .keptStrong(let isA): vote.add(isA ? 3.0 : 0, isA ? 0 : 3.0)
    case .keptWeak(let isA):   vote.add(isA ? 1.5 : 0, isA ? 0 : 1.5)
    case .converted(let wasA): vote.add(wasA ? 3.0 : 0, wasA ? 0 : 3.0)
    case .undecided:
        vote.aScore += Double(item.aLetters)
        vote.bScore += Double(item.bLetters)
    }
}
```

Обоснование веса 3.0: одно настоящее слово надёжнее трёх мусорных букв; при этом
6+ букв мусора всё ещё могут его перевесить (см. порог §1.4).

2. **Гистерезис против осцилляции между вызовами.**

```swift
// Состояние в SmartScorer (не static — экземпляр shared живёт весь запуск):
private var lastDirection: Direction?      // nil | .aToB | .bToA
private var lastDirectionAt: Date?
private let hysteresisWindow: TimeInterval = 90   // сек
private let hysteresisBias: Double = 1.5         // эквивалент 1.5 голоса

// При подсчёте итога:
if let last = lastDirection, Date().timeIntervalSince(lastDirectionAt!) < hysteresisWindow {
    // предыдущее направление получает бонус, чтобы инвертироваться,
    // направление должно выиграть ЯВНО, а не на волоске
    if last == .aToB { vote.aScore += hysteresisBias } else { vote.bScore += hysteresisBias }
}
```

Гистерезис применяется только когда разница голосов меньше `hysteresisBias * 2`;
явный перевес (>2 голосов) всегда побеждает — это защита от залипания направления
при реальной смене языка пользователем.

3. **Сброс состояния**: `lastDirection = nil` при пустом результате голосования
   (нет undecided и нет converted) и при паузе > `hysteresisWindow`.

---

### 1.3 Класс C — OCR-мусор на смешанном тексте

**Проблема.** Русское слово на смешанном OCR-тексте (`т-шаблонов` → `n-if,kjyjd`)
конвертируется, потому что OCR-фрагмент невалиден в обоих языках и уходит в голос.

**Дизайн — флаг источника + ужесточение правил для OCR.**

[`OCRService.deliver(result:)`](../Sources/Core/OCRService.swift:202) уже вызывает
[`LayoutMapper.convert()`](../Sources/Core/LayoutMapper.swift:104). Добавляем параметр
источника без изменения сигнатуры для hotkey-пути:

```swift
// LayoutMapper:
func convert(_ text: String, smart: Bool = ..., source: ConversionSource = .hotkey)

enum ConversionSource { case hotkey, ocr }

// SmartScorer.convert(..., source: ConversionSource):
// Для .ocr дополнительно:
//   1. Токен, содержащий ≥1 цифру или символы вне allowedPunctuation+letters
//      (например «•»), помечается protected — он не голосует (сейчас «• USa•C»
//      уже защищён тестом, но правило сделать системным).
//   2. Минимальная доля «шумовых» символов токена (не letter, не allowedPunct)
//      > 30% → protected.
//   3. Порог голоса поднят: undecidedTotal >= 8 (вместо 6) — см. §1.4.
```

Отдельно: случай `т-шаблонов` — это дефис внутри русского слова. Правило:
если после удаления дефиса обе части являются ru-словами (или одна часть — известный
префикс/суффикс), токен считается weakValid русским и не конвертируется. Реализация —
в `classifyToken()`: разбить по `-`, проверить части через `classifyWord`.

---

### 1.4 Класс G — порог голосования: токены vs буквы

**Проблема.** Порог `undecidedTotal >= 6` в буквах: один длинный никнейм `erafox`
(6 букв) одиноко решает свою судьбу → `укфащч`.

**Дизайн — двойной порог:**

```swift
let undecidedTokens = items.filter { $0.isUndecided }

// Условие применения голоса:
//   (a) минимум 2 undecided-ТОКЕНА, ИЛИ
//   (b) 1 undecided-токен, но он имеет strongValid-«соседа» по направлению
//       (т.е. общий голос уже смещён решёнными токенами §1.2),
//   (c) подавляющее большинство: max >= min * 2 (сохраняется),
//   (d) суммарный буквенный порог: total >= 6 сохраняется как нижняя граница.
let tokenCount = undecidedTokens.count
let contextBias = max(vote.aScore, vote.bScore) - min(vote.aScore, vote.bScore)
let mayVote = (tokenCount >= 2) || (tokenCount == 1 && contextBias >= 3.0)

if mayVote && undecidedTotal >= 6 && undecidedMax >= undecidedMin * 2 {
    // применяем направление ко всем undecided, как сейчас
}
```

Эффект: одиночный `erafox` (tokenCount==1, соседей-свидетельств нет) остаётся как есть —
безопасный дефолт. Одиночный токен среди русских слов (`Привет, erafox!` где `erafox`
набран в RU-раскладке как `укфащч`) получит направление от соседа `Привет` (weight 3.0).

---

### 1.5 Класс D — mixed-script токены

**Проблема.** `isLatin()`/`isCyrillic()` с семантикой `contains`: `CustomЕП` содержит
латиницу → `isLatin == true`; spellchecker толерантен к смешанным токенам → ложная
валидность.

**Дизайн — строгая однородность скрипта:**

```swift
func scriptOf(_ text: String) -> Script? {
    // Script: .latin | .cyrillic | nil (mixed или нет букв)
    var seen: Set<Script> = []
    for ch in text where ch.isLetter {
        seen.insert(script(of: ch))
        if seen.count > 1 { return nil }          // mixed → nil
    }
    return seen.first
}

// В classifyToken(): токен со script == nil → немедленно invalid для ОБОИХ языков
// (не доверять spellchecker вообще). Дальше обычный путь: candidate тоже mixed →
// undecided/keep. Mixed-script токен НИКОГДА не может быть strongValid.
```

Дополнительно: `isCyrillic`/`isLatin` заменяются на `scriptOf(...) == .cyrillic/.latin`
во всех местах [`isValidWord()`](../Sources/Core/SmartScorer.swift:299). Это же правило
закрывает ложную валидность от толерантности NSSpellChecker к вкраплениям чужого скрипта.

---

### 1.6 Класс E — ALL-CAPS

**Проблема.** `KJRFK[JCN` не сконвертировался. Диагностика: spellchecker чувствителен
к регистру; `checkSpelling(of: "KJRFK[JCN")` не находит слова, а candidate `КЙРАЛЙСЪ`…
точнее `КРУПНКАШ` — тоже CAPS, spellchecker отклоняет CAPS-формы чаще.

**Дизайн — регистронезависимая проверка с восстановлением регистра:**

```swift
func classifyWord(_ word: String, language: String) -> WordTrust {
    // ... существующие проверки ...
    // Spellchecker-проба выполняется трижды: as-is, lowercased, capitalized.
    // Валидность любой формы => valid (trust по общим правилам).
    let probes = [word, word.lowercased(), word.capitalized]
    return probes.contains { spellCheckerSaysValid($0, language) } ? .weakValid : .invalid
}

// Конвертация CAPS-токена: посимвольная карта уже сохраняет регистр (aToB хранит
// и строчные, и заглавные пары из buildBidirectionalMap), поэтому отдельного
// восстановления регистра не требуется. Проверить юнит-тестом "KJRFK[JCN"→"КРУПНЫЙ"
// (пары K→К, J→Й, R→Р, F→А, [→Х, C→С, N→Т... — фактические пары берутся из карты).
```

**Операционный риск (из диагностики):** подозрение, что установленная сборка старее
исходников (нет git-истории). Обязательный шаг внедрения — перед изменениями собрать
и задеплоить текущий master, воспроизвести класс E на свежей сборке, и только потом
фиксить. Если воспроизводится — фикс выше; если нет — причина была в устаревшем рантайме.

---

### 1.7 Класс F — слипшиеся слова

**Проблема.** `rk.xvjltktq` (=`какактовтуклук`? фактически «слитно набранные два слова»)
не разделяется и не конвертируется.

**Минимальное безопасное изменение — сплит-кандидаты только для undecided-токенов:**

```swift
// После того как токен помечен undecided (оба варианта invalid):
func splitCandidates(_ token: String, map: [Character: Character], lang: String) -> [String] {
    guard token.count >= 6, token.count <= 40 else { return [] }
    var results: [String] = []
    // O(n) проход: пробуем все точки разреза, но проверку делаем инкрементально
    for i in 2...(token.count - 2) {
        let left = String(token.prefix(i))
        let right = String(token.dropFirst(i))
        let lc = convertRun(left, map); let rc = convertRun(right, map)
        if classifyWord(lc, language: lang) != .invalid,
           classifyWord(rc, language: lang) != .invalid {
            results.append(lc + " " + rc)
            if results.count >= 3 { break }     // ограничение перебора
        }
    }
    return results
}

// Применение: если ровно 1 кандидат → заменяем undecided-токен на него
// (два валидных слова одновременно — сильное свидетельство).
// Если >1 кандидатов → берём пару с максимальным суммарным частотным рангом (§1.1.1);
// при равенстве — не конвертируем (safe default).
```

Ограничения: не применяется к protected-токенам, к токенам с цифрами, к CAPS
(разрез по CAPS неоднозначен), максимум 1 разрез на токен (v1: без рекурсивного
разбиения на 3+ слова — риск ложных срабатываний растёт быстрее пользы).

---

### 1.8 Класс H — выбор целевой раскладки после конвертации

**Проблемы (по диагностике):**
1. [`ConversionEngine`](../Sources/Core/ConversionEngine.swift:31) считает `countA/countB`
   по **input**, хотя конвертация могла быть частичной (valid-слова не тронуты).
2. Пунктуационные пары карт шумят в подсчёте (`,`↔`^` и т.п. — частично уже отфильтровано
   в [`buildBidirectionalMap()`](../Sources/Core/LayoutMapper.swift:91), но не в подсчёте).
3. Тихий tie: при равенстве молча выбирается secondary.
4. Рассинхрон с tie-breaker SmartScorer.

**Дизайн — решение принимает SmartScorer, ConversionEngine только исполняет:**

```swift
// 1) SmartScorer.convert() возвращает структуру вместо String:
struct ConversionResult {
    let text: String
    let dominantSourceScript: Script?   // скрипт ИСХОДНИКА по взвешенному голосу §1.2
    let changed: Bool
}

// 2) Подсчёт доминанты — по БУКВАМ решённых и undecided токенов (не по всей строке,
//    пунктуация не участвует by construction, т.к. считаем только letters):
//    dominantSourceScript = vote.aScore >= vote.bScore ? scriptOfLangA : scriptOfLangB

// 3) Целевая раскладка = ПРОТИВОПОЛОЖНАЯ доминанте исходника (куда конвертировали):
//    target = (dominantSourceScript == scriptOf(primary)) ? secondary : primary
//    no-switch: если changed == false ИЛИ mixed-текст (обе доли > 35%) — не переключать.

// 4) Единый tie-breaker: LayoutMapper.tieBreakPrefersAToB() остаётся единственной
//    реализацией; ConversionEngine больше не имеет собственной логики выбора.
```

Изменение публичного контракта [`SmartScorer.convert()`](../Sources/Core/SmartScorer.swift:120)
— breaking change внутри модуля; вызовы обновляются в
[`LayoutMapper.convert()`](../Sources/Core/LayoutMapper.swift:116) (адаптер сохраняет
старую сигнатуру `-> String` для совместимости тестов через `result.text`).

---

### 1.9 Сводная карта изменений по файлам

| Файл | Изменение | Классы |
|---|---|---|
| [`SmartScorer.swift`](../Sources/Core/SmartScorer.swift) | `WordTrust` + `classifyWord/classifyToken`; частотные списки; строгий `scriptOf`; взвешенный голос всех токенов; гистерезис; двойной порог; split-candidates; CAPS-пробы; `ConversionResult` | A,B,C,D,E,F,G,H |
| [`LayoutMapper.swift`](../Sources/Core/LayoutMapper.swift) | Адаптер результата; `source:` параметр; tie-breaker без изменений | C,H |
| [`ConversionEngine.swift`](../Sources/Core/ConversionEngine.swift) | Шаг 4: использовать `dominantSourceScript` из результата; удалить локальный подсчёт countA/countB | H |
| [`OCRService.swift`](../Sources/Core/OCRService.swift) | Передать `source: .ocr` в конвертер (строка 212) | C |
| `Resources/frequency_ru.txt`, `frequency_en.txt` | Новые ресурсы топ-30k | A,G,F |

Порядок внедрения (каждый шаг независимо тестируем): D → E → A → G → B → H → C → F.
D и E первыми, потому что они меняют семантику валидации, на которую опираются остальные.

---

## Часть 2. Ресерч: копирование текста из приложений, запрещающих копирование

### 2.1 Как Telegram macOS детектит захват (подтверждено исходниками)

Исследование открытого клиента [`overtake/TelegramSwift`](https://github.com/overtake/TelegramSwift)
(коммит `579cebbf`, ветка master):

1. **Флаг защиты** — серверный флаг `copyProtectionEnabled` на peer'е:
   [`CoreExtension.swift`](https://github.com/overtake/TelegramSwift/blob/master/Telegram-Mac/CoreExtension.swift):

   ```swift
   extension Peer {
       var isCopyProtected: Bool {
           if let peer = self as? TelegramGroup {
               return peer.flags.contains(.copyProtectionEnabled) && !peer.groupAccess.isCreator
           } else if let peer = self as? TelegramChannel {
               return peer.flags.contains(.copyProtectionEnabled) && !(peer.adminRights != nil ...)
           } else { return false }
       }
   }
   ```

   На этом флаге клиент запрещает копирование в UI (`showProtectedCopyAlert`) и включает
   визуальную защиту окна.

2. **Детект активного захвата экрана** — тот же файл, строка 3335:

   ```swift
   let stream = CGDisplayStream(dispatchQueueDisplay: CGMainDisplayID(),
                                outputWidth: 1, outputHeight: 1,
                                pixelFormat: Int32(kCVPixelFormatType_32BGRA),
                                properties: nil, queue: DispatchQueue.main,
                                handler: { _, _, _, _ in ... })
   ```

   Это классический детектор: создание CGDisplayStream 1×1 px на главном дисплее.
   Если система разрешает создание потока захвата — приложение узнаёт, что запись
   экрана возможна/активна, и рисует защитный оверлей поверх защищённого контента.
   Серое окно — это **клиентская отрисовка** (оверлей самого Telegram), а не системный
   блэк-бокс: macOS 15 действительно перестал вырезать окна с `sharingType = .none`
   из стороннего захвата (регрессия, отражённая в tauri#14200), поэтому Telegram
   вынужден рисовать щит сам, реагируя на факт захвата.

3. **Следствие.** Детект срабатывает на *сам факт создания потока захвата дисплея*.
   Разовый снимок (`SCScreenshotManager.captureImage`) и поток (`SCStream`) оба
   проходят через подсистему захвата → оверлей появляется. Значит, побеждать надо
   не «до применения shield», а либо (а) снимая так, чтобы оверлей не успел отрисоваться,
   либо (б) обходя подсистему захвата экрана целиком.

### 2.2 Оценка путей обхода

| # | Подход | Механизм | Работает? | Оценка |
|---|---|---|---|---|
| 1 | `SCStreamConfiguration.ignoreShieldsDisplay` / флаги macOS 15 | ScreenCaptureKit shield-bypass | ❌ Не существует публичного флага «игнорировать клиентский оверлей». SCK честно захватывает композит экрана; серый прямоугольник — часть композита, нарисованная самим Telegram. `ignoresShields`-API в SDK нет (проверено по докам ScreenCaptureKit macOS 15). | Отпадает |
| 2 | Захват «до shield»: гонка — снять кадр до первой отрисовки оверлея | `CGWindowListCreateImage(kCGWindowListOptionIncludingWindow)` на окно Telegram | ⚠️ Частично. Оверлей Telegram держится постоянно, пока детект видит захват; при создании нашего потока детект срабатывает раньше, чем мы успеваем снять. Гонка нестабильна, ломается при любом апдейте Telegram. | Отпадает как основной |
| 3 | **Accessibility API: чтение текста напрямую** | `AXUIElement` → `AXValue` текстовых элементов окна Telegram | ✅/⚠️ Telegram-Swift — нативный AppKit: текст сообщений — атрибутированные строки в кастомных view. AX-дерево экспонирует часть текста, но: (а) требует разрешения Accessibility у пользователя, (б) кастомные list-item view часто отдают пустые AXValue, (в) на защищённых чатах клиент может сознательно глушить AXRole описания. Требует прототипа. | Резерв №2 |
| 4 | **Системный скриншот Cmd+Shift+4 программно** | `screencapture` CLI / эмуляция клавиш | ✅ Системный `screencapture` работает от имени системы: детект Telegram (CGDisplayStream создаётся процессом Telegram) не видит *чужой* одноразовый CLI-захват так же надёжно, как поток; ключевой момент — системный скриншот в защищённых чатах Telegram macOS **не затемняет** окно (затемнение включается на время *активной записи*, а CLI делает мгновенный снимок без запуска записи). Проверка пользователем обязательна (см. тест T-O-01). | **Выбран №1** |
| 5 | web.telegram.org в WKWebView | Скриншот WebView | ✅ Технически работает (web-клиент не контролирует захват), но меняет UX: нужен вход в аккаунт внутри нашего окна, отдельная сессия. Нарушает ограничение «тот же хоткей, та же рамка». | Отпадает для v1.3 |

Уточнение к №4: `screencapture` (и `CGWindowListCreateImage` из нашего процесса) требуют
TCC-разрешение Screen Recording — оно у приложения уже есть. Эмуляция Cmd+Shift+4
(CGEvent) требует разрешения Accessibility/Input Monitoring и оставляет системный UI —
предпочтительнее прямой вызов `/usr/sbin/screencapture -x -R x,y,w,h file.png`:
тихо, без звука (`-x`), с областью (`-R`), атомарно.

**Почему это легитимно:** функция читает текст, который пользователь уже видит на своём
экране, для личного использования (копировать самому себе). Это не обход DRM:
Telegram не шифрует контент от пользователя (пользователь — получатель сообщения);
ограничение `noforwards` — политика распространения, а не техническая защита доступа.
Риски: (1) нарушение ToS Telegram теоретически возможно — ограничить функцию
личным использованием, не публиковать «обход защиты» как фичу в маркетинге;
(2) приватность третьих лиц — пользователь отвечает сам; (3) хрупкость — при изменении
поведения Telegram путь деградирует до текущего (серый кадр → OCR вернёт мусор →
нужен детект серого кадра, см. §2.4).

### 2.3 Выбранные подходы

- **Основной (Approach S):** системный CLI-снимок области через `screencapture -x -R`,
  чтение PNG, дальше существующий Vision-пайплайн без изменений.
- **Резервный (Approach A):** Accessibility-чтение текста окна Telegram
  (`AXUIElementCopyAttributeValue(kAXFocusedWindowAttribute)` → обход дерева → сбор
  `AXValue` строк). Внедряется вторым этапом, если Approach S перестанет работать
  или даст плохое качество на Retina/тёмных темах.

### 2.4 Интеграция в [`OCRService`](../Sources/Core/OCRService.swift) без изменения UX

UX неизменен: хоткей → рамка выбора → текст в буфере. Меняется только источник кадра
внутри [`captureAndRecognize(rect:screen:)`](../Sources/Core/OCRService.swift:98).

```swift
// Новый провайдер кадра (protocol для тестируемости):
protocol ScreenFrameProvider {
    func capture(rect: CGRect, displayID: CGDirectDisplayID) async -> CGImage?
}

// Провайдер 1 (основной): системный CLI
final class SystemCaptureProvider: ScreenFrameProvider {
    func capture(rect: CGRect, displayID: CGDirectDisplayID) async -> CGImage? {
        // 1. tmp-файл: URL(fileURLWithPath: NSTemporaryDirectory())
        //    .appendingPathComponent("retyper-\(UUID().uuidString).png")
        // 2. Process: /usr/sbin/screencapture -x -R rect.origin.x,rect.origin.y,w,h <tmp>
        //    Координаты: screencapture принимает глобальные точки (top-left origin!)
        //    → конвертировать из NS bottom-left: y_cli = screenHeight - maxY
        // 3. NSImage(contentsOf: tmp) → cgImage(forProposedRect:context:hints:)
        // 4. удалить tmp (defer try? FileManager.removeItem)
        // 5. fallback: если exit code != 0 → вернуть nil (цепочка ниже)
    }
}

// Провайдер 2 (fallback, текущий): ScreenCaptureKit — код уже существует
final class ScreenKitProvider: ScreenFrameProvider { /* текущее тело captureAndRecognize */ }

// Оркестрация в OCRService.captureAndRecognize(rect:screen:):
let image = await SystemCaptureProvider().capture(...)   // Attempt 1
                 ?? await ScreenKitProvider().capture(...) // Attempt 2 (как сегодня)

// Детект «серого кадра» (защита от деградации): считать среднюю яркость и
// дисперсию crop'а; если variance < threshold и mean в диапазоне серого —
// показать toast «Защищённый контент: попробуйте ещё раз» вместо копирования мусора.
```

Точки внимания:
- Масштаб Retina: `screencapture -R` пишет физические пиксели; существующий код
  масштабирования в [`captureAndRecognize(fullImage:)`](../Sources/Core/OCRService.swift:120)
  рассчитывает scale как `fullImage.width / screenFrame.width` — переиспользуется без правок,
  если CLI вернул изображение всего рета-качества области (проверить тестом T-O-03).
- Таймаут процесса: 3 c, kill иначе.
- Sandbox: если приложение sandboxed, нужен temporary-exception или com.apple.security.temporary-exception.mach-lookup для запуска /usr/sbin/screencapture; XcodeGen project.yml проверить. Если sandbox жёсткий — fallback на CGWindowListCreateImage одного окна Telegram (kCGWindowListOptionIncludingWindow) из нашего процесса (тот же TCC).
- Приватность: tmp-файл удаляется сразу; логирование только факта, не содержимого.

---

## Часть 3. Регрессионные тесты

### 3.1 Конвертация (XCTest, [`Tests/ReTypeRTests/`](../Tests/ReTypeRTests/LayoutMapperTests.swift))

Существующие тесты сохраняются без изменений (регрессия). Новые:

| ID | Класс | Вход → Ожидание | Проверяет |
|---|---|---|---|
| T-C-A1 | A | `ghbdtn kb gb bp` → `привет kb gb bp` (kb/gb/bp остаются: нет контекстных свидетельств) | Аббревиатуры без контекста не портятся |
| T-C-A2 | A | `sqsq kb rjhjkt` (контекст: `rjhjkt`→`толчок`?) — подобрать реальный кейс: `f kb jyj to`` → `а kb оно ещё`… уточнить: `b z ei`k` уже покрыт; новый: `ye tot` при соседнем valid RU-слове → конвертируются | Контекст решает короткие токены |
| T-C-B1 | B | Последовательные вызовы: `convert("руддщ цщкдв")` затем `convert("ntcn")` → второй даёт `тест`, не осциллирует | Гистерезис |
| T-C-B2 | B | `Привет, ntcn, ghbdtn` → всё EN-часть конвертируется одним направлением | Взвешенный голос с valid-токенами |
| T-C-C1 | C | OCR-режим: `source: .ocr`, вход `т-шаблонов n-if,kjyjd` → без изменений | OCR-мусор не конвертируется |
| T-C-D1 | D | `CustomЕП` → без изменений | Mixed-script строгость |
| T-C-D2 | D | `ЕПtest` → без изменений | Mixed-script (обратный порядок) |
| T-C-E1 | E | `KJRFK[JCN` → `КРУПНЫЙ…` (по фактической карте) | CAPS-конвертация |
| T-C-E2 | E | `GHBDTN` → `ПРИВЕТ` | CAPS-регистр сохраняется |
| T-C-F1 | F | `rk.xvjltktq` → разделение на 2 валидных слова либо без изменений (не мусор) | Слипшиеся слова |
| T-C-G1 | G | `erafox` одиночно → без изменений | Одиночный undecided не трогается |
| T-C-G2 | G | `Привет, erafox!` где erafox=укфащч → конвертируется по контексту | Контекстный допуск одиночки |
| T-C-H1 | H | Конвертация RU→EN текста: `targetLayoutID == primary` | Переключение по output |
| T-C-H2 | H | Mixed 50/50 → переключения нет | No-switch при mixed |
| T-C-H3 | H | `changed == false` → переключения нет | No-switch при отсутствии изменений |

Инфраструктура: расширить mock-словарь [`testWords`](../Sources/Core/SmartScorer.swift:64)
минимумами для новых кейсов; частотные списки в тестах подменяются fixture-файлом
(10–20 слов) через injection-точку `FrequencyStore.protocol`.

### 3.2 OCR (ручные + unit где возможно)

| ID | Сценарий | Ожидание |
|---|---|---|
| T-O-01 | Открытый Telegram-чат (обычный), выделить область с текстом | Текст распознан и скопирован (CLI-путь) |
| T-O-02 | Защищённый канал Telegram, та же область | Текст распознан, серого кадра нет; если серый — toast-предупреждение, не мусор в буфере |
| T-O-03 | Retina-дисплей, мелкий шрифт | Корректный масштаб crop'а (нет сдвига/размытия) |
| T-O-04 | Мультидисплей: область на втором экране | Правильный дисплей и координаты |
| T-O-05 | Отказ TCC Screen Recording | Стандартный запрос разрешения, без падения |
| T-O-06 | `screencapture` недоступен (переименован/sandbox) | Авто-fallback на ScreenCaptureKit, UX прежний |
| T-O-07 | Тёмная тема Telegram | Распознавание не хуже светлой темы |
| T-O-08 | tmp-файлы | После операции каталог Temp не содержит retyper-*.png |

### 3.3 Критерии приёмки

1. Все существующие тесты зелёные + новые T-C-* зелёные в CI (headless: spellchecker-mock).
2. Ручной прогон `docs/MANUAL_TEST_TEXT.md` — 10/10 блоков без регрессий.
3. T-O-02 подтверждён на актуальной версии Telegram macOS 11.x на macOS 15.
4. Лог `conversion_log.jsonl`: доля `changed=false` на эталонном корпусе не выросла.

---

## Открытые вопросы / риски

1. **E (CAPS)**: подтвердить на свежей сборке до написания фикса (устаревший рантайм).
2. **Approach S**: поведение `screencapture` на защищённых чатах проверить вручную
   до коммита (T-O-02) — поведение клиента может отличаться от open-source TelegramSwift.
3. Sandbox-политика запуска внешнего процесса — выяснить при реализации (devops-вопрос).
4. Частотные списки: выбрать источник и проверить лицензию (OpenCorpora — CC BY-SA;
   Google Books — ограничение на редистрибуцию → предпочтителен OpenCorpora/Hunspell-словари).
