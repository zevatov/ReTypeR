# ReTypeR — Handoff следующей сессии

> ➡️ **Операционный план следующей сессии (Gemini 3.8):**
> [`docs/HANDOFF_GEMINI_38.md`](HANDOFF_GEMINI_38.md) — private GitHub, gitignore,
> synthetic verification, кнопки, auto-update OD. Этот файл — исторический снапшот.

> ⚠️ **ИСТОРИЧЕСКИЙ СНАПШОТ 2026-08-25** (с последующими историческими
> дополнениями до 2026-09-12). Всё содержимое этого документа — снимки состояния
> проекта, а не текущий план; тело не актуализировалось. Текущий статус и релиз —
> [`docs/ROADMAP.md`](ROADMAP.md) (локально подготовлен **1.3.5 / build 6**).
> Утверждения о незавершённых P0–P3 ниже по тексту — **исторические** и не являются
> текущим backlog: Этапы 0–3 завершены (актуальная сводка — раздел
> «[Статус после Этапа 3](#статус-после-этапа-3-2026-09-05)» в конце файла).
>
> ⚠️ **REMOVED FROM PROD (2026-09-14):** все упоминания ниже
> [`OCRService`](../Sources/Core/OCRService.swift), Screen Recording, Approach S,
> `SystemCaptureProvider`/`ScreenKitProvider`, `ocrCapture`, tmp-кадра
> `retyper-*.png` и серого кадра — **historical**: продуктовый OCR-режим вырезан
> из прод-кода (файл [`Sources/Core/OCRService.swift`](../Sources/Core/OCRService.swift)
> удалён; SR-разрешения и UI/хоткея OCR нет). Scoring-класс C /
> [`ConversionSource.ocr`](../Sources/Core/SmartScorer.swift:8) сохранён как
> внутренний scoring-флаг. Не возвращать эти пункты в backlog.

> Дата: 2026-08-25. Рабочая директория: `/Users/stanislav/Проекты/ReTypeR`
> (проект переехал со старого пути `/Users/stanislav/Desktop/Проекты.nosync/ReTypeR`).
> Спецификация v1.3: [`docs/ARCHITECTURE_V13.md`](ARCHITECTURE_V13.md) · План: [`docs/ROADMAP.md`](ROADMAP.md).

## 1. Что сделано (классы A–G + каркас H)

Реализация v1.3 частично в коде (все координаты проверены read-back 2026-08-25):

| Класс | Где реализован |
|---|---|
| A — короткие слова | [`enum WordTrust`](../Sources/Core/SmartScorer.swift:19), [`classifyWord`](../Sources/Core/SmartScorer.swift:555): spellchecker только при len≥4, whitelist-уровень, [`frequencyStore`](../Sources/Core/SmartScorer.swift:65) (протокол [`FrequencyStore`](../Sources/Core/SmartScorer.swift:28), дефолт [`EmptyFrequencyStore`](../Sources/Core/SmartScorer.swift:34) — частотные файлы в бандл не включены, лицензия не подтверждена) |
| B — осцилляция | гистерезис: [`lastDirection`](../Sources/Core/SmartScorer.swift:72), окно 90 c, bias 1.5; сброс через [`resetHysteresis()`](../Sources/Core/SmartScorer.swift:78) |
| C — OCR-мусор | [`ConversionSource`](../Sources/Core/SmartScorer.swift:6); OCR-путь передаёт `source: .ocr` из [`deliver(result:)`](../Sources/Core/OCRService.swift:213); защита шумных токенов [`isOCRProtected`](../Sources/Core/SmartScorer.swift:505) |
| D — mixed-script | строгий [`scriptOf(_:)`](../Sources/Core/SmartScorer.swift:207); mixed → invalid в [`classifyToken`](../Sources/Core/SmartScorer.swift:520) и [`classifyWord`](../Sources/Core/SmartScorer.swift:555) |
| E — CAPS | тройные пробы as-is/lowercased/capitalized в [`spellCheckerSaysValid`](../Sources/Core/SmartScorer.swift:607) |
| F — слипшиеся слова | [`splitCandidate`](../Sources/Core/SmartScorer.swift:629) (однозначный разрез или частотно-лучший; ties не трогаются) |
| G — порог голоса | двойной порог (2+ undecided-токена либо contextBias ≥ 3.0) внутри [`convert(...)`](../Sources/Core/SmartScorer.swift:227) |
| H — каркас | [`struct ConversionResult`](../Sources/Core/SmartScorer.swift:40) (`text`, `dominantSourceScript`, `changed`); адаптер [`convertDetailed`](../Sources/Core/LayoutMapper.swift:120) с параметром `source:` (дефолт `.hotkey`, [строка 123](../Sources/Core/LayoutMapper.swift:123)); легаси-обёртки [`convert(_:)->String`](../Sources/Core/LayoutMapper.swift:104) сохранены |

## 2. Что сломано / не доделано

1. **Класс H не завершён** в движке: [`ConversionEngine.performConversion()`](../Sources/Core/ConversionEngine.swift:22)
   на строках [31–32](../Sources/Core/ConversionEngine.swift:31) всё ещё считает
   `countA/countB` по **входному** тексту и переключает раскладку по нему
   ([строка 47](../Sources/Core/ConversionEngine.swift:47)). Нет перехода на
   `convertDetailed()`, нет no-switch правил для mixed >35%/35% и `changed == false`.
   Детали: ROADMAP [P0](ROADMAP.md).
2. **Approach S отсутствует**: в [`OCRService`](../Sources/Core/OCRService.swift) захват
   идёт только через [`SCScreenshotManager.captureImage`](../Sources/Core/OCRService.swift:110)
   ([строки 102–116](../Sources/Core/OCRService.swift:102)). Нет `ScreenFrameProvider`,
   нет `SystemCaptureProvider` (`screencapture -x -R`, таймаут 3 с, tmp-гигиена),
   нет fallback-цепочки и детекта серого кадра. Дизайн — спека §[2.4](ARCHITECTURE_V13.md).
3. **Тесты T-C-A1…T-C-H3 не добавлены**: в
   [`Tests/ReTypeRTests/LayoutMapperTests.swift`](../Tests/ReTypeRTests/LayoutMapperTests.swift)
   только 12 старых тестов ([первый](../Tests/ReTypeRTests/LayoutMapperTests.swift:16) —
   `testEnglishToRussianConversion`, [последний](../Tests/ReTypeRTests/LayoutMapperTests.swift:151) —
   `testSafeDefaultKeepsValidText`). Таблицы тестов — спека §[3.1–3.2](ARCHITECTURE_V13.md).
4. **Блокер сборки (обнаружен при handoff, сверх плана):** в [`Sources`](../Sources) нет
   определений `TextService`, `StatisticsManager`, `LaunchManager`, `OnboardingView`,
   точки входа `ReTypeRApp` и `Color+Brand` — при этом живой код на них ссылается:
   [`TextService.shared`](../Sources/Core/ConversionEngine.swift:14),
   [`StatisticsManager.shared.recordConversion`](../Sources/Core/ConversionEngine.swift:52),
   [`LaunchManager.shared`](../Sources/Views/SettingsView.swift:6),
   [`OnboardingView()`](../Sources/Services/WindowManager.swift:67). Их объектники есть в
   старой сборке (`build/DerivedData/Build/.../Objects-normal/arm64/*.o`: TextService.o,
   StatisticsManager.o, LaunchManager.o, OnboardingView.o, ReTypeRApp.o, Color+Brand.o),
   т.е. файлы существовали на момент последней сборки и потеряны при переезде.
   До их восстановления проект не компилируется.

## 3. Утраченные при переезде артефакты и восстановление

| Артефакт | Как восстанавливать |
|---|---|
| `README.md` | Написать заново под v1.3 (умная конвертация A–H, OCR через системный скриншот Approach S, требования macOS 15+, разрешения Accessibility + Screen Recording). ROADMAP [P3](ROADMAP.md) |
| `project.yml` | Воссоздать (XcodeGen): app-target ReTypeR + test-target ReTypeRTests, SPM-зависимость KeyboardShortcuts, `MARKETING_VERSION 1.3.0`. Сверить bundle id/entitlements по `build/DerivedData/Build/Products/Release/ReTypeR.app/Contents/Info.plist` (сохранился) |
| `ReTypeR.xcodeproj/` | Регенерировать: `xcodegen generate` после создания `project.yml` |
| `scripts/*` (папка пуста) | Пересоздать `scripts/build_dmg.sh` (Release + hdiutil). ROADMAP [P3](ROADMAP.md) |
| `ReTypeR.dmg` | Пересобрать скриптом после P3/P4 |
| `docs/ARCHITECTURE_V13.md` | ✅ уже восстановлен дословно из экспорта чата (provenance в шапке файла) |
| Исходники `TextService`, `StatisticsManager`, `LaunchManager`, `OnboardingView`, `ReTypeRApp`, `Color+Brand` | Приоритет: резервные копии/Time Machine старого пути `/Users/stanislav/Desktop/Проекты.nosync/ReTypeR/Sources`; иначе переписать по использованию в живом коде + сигнатурам из `.o`/`.swiftmodule` в `build/DerivedData` |

Проверка старого пути на остатки копии: `ls /Users/stanislav/Desktop/Проекты.nosync/ReTypeR 2>/dev/null`.

## 4. Карта файлов проекта

```
Sources/
  App/AppDelegate.swift          — статус-бар, permissions-подписки, toast-подписка, onboarding
  Core/HotkeyManager.swift       — хоткеи convertText (Ctrl+Shift+Space) и ocrCapture (Ctrl+Shift+O)
  Core/LayoutMapper.swift        — карты раскладок Carbon/TIS, convert/convertDetailed, switchToLayout
  Core/ConversionEngine.swift    — hotkey-конвейер: select→convert→replace→switch layout (класс H — TODO)
  Core/OCRService.swift          — region-capture оверлеи, ScreenCaptureKit-захват, Vision OCR, буфер
  Core/SmartScorer.swift         — ядро умной конвертации: классы A–G, ConversionResult, гистерезис
  Services/ConversionLogger.swift— JSONL-лог конвертаций (conversion_log.jsonl)
  Services/PermissionsManager.swift — Accessibility/Screen Recording TCC-статусы и запросы
  Services/PreferencesManager.swift — UserDefaults-настройки (smart mode, layouts, флаги UI)
  Services/WindowManager.swift   — toast/onboarding окна
  Views/MenuBarView.swift        — popover меню-бара
  Views/SettingsView.swift       — окно настроек (ссылается на утраченные LaunchManager/StatisticsManager)
  Views/Components/ConversionToast.swift — SwiftUI-toast результата
  Extensions/, Models/           — пустые каталоги
Tests/ReTypeRTests/
  LayoutMapperTests.swift        — 12 существующих тестов; сюда добавлять T-C-* (спека §3.1)
docs/
  ARCHITECTURE_V13.md            — восстановленная спецификация v1.3 (A–H, Approach S, тесты)
  MANUAL_TEST_TEXT.md            — ручной корпус (10 блоков) для регресс-прогона
  ROADMAP.md                     — план P0–P4 до релиза v1.3.0
  HANDOFF.md                     — этот файл
scripts/                         — пусто (утрачено; пересоздать build_dmg.sh)
build/DerivedData/               — артефакты старой сборки от 2026-08-06 (evidence утраченных исходников)
roo_task_aug-23-2026_12-15-44-pm.md — экспорт истории чата; источник восстановления спеки
```

## 5. Команды проверки

```bash
# Юнит-тесты (работает только после P3: восстановления project.yml/xcodeproj
# и недостающих исходников — сейчас ReTypeR.xcodeproj отсутствует):
xcodebuild -project ReTypeR.xcodeproj -scheme ReTypeR test -destination 'platform=macOS'

# Регенерация проекта (после создания project.yml):
xcodegen generate

# Ручной корпус для регресс-прогона конвертации:
# docs/MANUAL_TEST_TEXT.md — 10 блоков, критерий 10/10 без регрессий (спека §3.3)

# Поиск остатков старой копии (восстановление утраченных исходников):
ls /Users/stanislav/Desktop/Проекты.nosync/ReTypeR/Sources 2>/dev/null
```

До P3 быстрая smoke-проверка логики возможна только чтением кода и review —
компиляция недоступна (см. §2 п.4).

## 6. Статус Obsidian

Заметка `/Users/stanislav/AI_NOTES/4_Spaces/Projects/ReTypeR/Project_ReTypeR.md`
**устарела**: updated 2026-08-06, версия v1.2.0, указан старый путь Desktop,
нет информации о v1.3 (классы A–H, Approach S) и о переезде проекта.

Обновляет **владелец операции** через MCP `obsidian-knowledge-sync`
(targeted search/get до записи, allowlisted vault-relative путь
`4_Spaces/Projects/ReTypeR/Project_ReTypeR.md`, exact marker `ZOO_PIPELINE_`,
одна mutation за раз, immediate get/read-back). Агент vault не трогает;
delete/move/rename и full-Obsidian запрещены.

---

## Статус после Этапа 3 (2026-09-05)

> Документная фиксация актуального состояния. Ручные OCR-сценарии **не выполнялись** —
> их статусы PENDING: [`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md), раздел
> «v1.3 release checklist».

### Реализовано (Этапы 0–3 завершены)

- Восстановлены утраченные исходники и сборочная обвязка; класс H переключает
  раскладку по output-доминанте: [`performConversion()`](../Sources/Core/ConversionEngine.swift:22)
  использует [`convertDetailed`](../Sources/Core/LayoutMapper.swift:120) и
  [`targetLayoutID(for:)`](../Sources/Core/ConversionEngine.swift:72).
- Approach S реализован: primary [`SystemCaptureProvider`](../Sources/Core/OCRService.swift:377),
  fallback [`ScreenKitProvider`](../Sources/Core/OCRService.swift:474), контракт
  [`ScreenFrameProvider`](../Sources/Core/OCRService.swift:100).
- Обычный `xcodebuild test` — **54/54, TEST SUCCEEDED**; test-target Info.plist
  генерируется автоматически.
- Release pipeline: ad-hoc подпись + сборка DMG работают
  ([`scripts/build_dmg.sh`](../scripts/build_dmg.sh)).
- Single-instance: [`LSMultipleInstancesProhibited`](../Sources/App/Info.plist:25).
- AX timeout: [`AXUIElementSetMessagingTimeout`](../Sources/Core/TextService.swift:60),
  порог 1 с — [`operationTimeout`](../Sources/Core/TextService.swift:14).
- OCR async + multidisplay seam: [`ScreenFrameProvider`](../Sources/Core/OCRService.swift:100).
- Gray detector: [`OCRService.swift:147`](../Sources/Core/OCRService.swift:147);
  частотный кэш — [`frequencyStore`](../Sources/Core/SmartScorer.swift:65)
  (bundle-backed по умолчанию).
- UI warning: серый кадр даёт предупреждение о защищённом контенте вместо копирования
  мусора — ветка gray-проверки в [`captureAndRecognize`](../Sources/Core/OCRService.swift:122).

### Оставшиеся gaps (до финального релиза)

- Ручные сценарии T-O-01…T-O-08 и T-C-01…T-C-03 — **PENDING**, не отмечать зелёными
  ([`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md)).
- [`DiagTests`](../Tests/ReTypeRTests/DiagTests.swift:5) пока существует — удалить в
  отдельном release-child до финального релиза (см. [`docs/ROADMAP.md`](ROADMAP.md),
  раздел «Post-P4: remaining release gates»).
- Старый `ReTypeR.dmg` в корне больше отсутствует; в корне — пересобранный
  beta-артефакт [`ReTypeR 1.3 Бета.dmg`](../ReTypeR%201.3%20Бета.dmg)
  (2026-09-07, см. раздел «Пересборка DMG 1.3 beta» ниже).
- [`NSScreenCaptureUsageDescription`](../Sources/App/Info.plist:31) — требуется внешняя
  верификация в собранном `ReTypeR.app/Contents/Info.plist`.

### Фикс критического регресса 1.3 «bare v» (2026-09-07)

- Симптом: хоткей в поле ввода вместо конвертации вставлял голую букву «v».
- Первопричина: clipboard-fallback-путь
  [`TextService`](../Sources/Core/TextService.swift) постил `virtualKey: 9`
  (`kVK_ANSI_V`) с пустыми флагами вместо Cmd+C (`kVK_ANSI_C` = 0x08), а
  select-all — `virtualKey: 7` (`kVK_ANSI_X`, вырезание) вместо Cmd+A
  (0x00). Цепочка: pasteboard очищается → Cmd+C не происходит → poll
  `changeCount` истекает → конвертация отменяется, а напечатанная «v»
  затирает выделение.
- Фикс: [`enum SyntheticKey`](../Sources/Core/TextService.swift:230)
  (0x00/0x08/0x09 + единый `.maskCommand`), все три call-site переключены на
  `.selectAll`/`.copy`/`.paste`;
  [`simulateKeyPress(_:)`](../Sources/Core/TextService.swift:248).
- Регрессионная защита:
  [`SyntheticKeyRegressionTests`](../Tests/ReTypeRTests/LogRegressionTests.swift:111)
  — 4 теста, пинящие коды/флаги к HIToolbox `Events.h`
  (строки 104–147 [`LogRegressionTests.swift`](../Tests/ReTypeRTests/LogRegressionTests.swift:104)).
- Верификация 2026-09-07: `xcodebuild build` → BUILD SUCCEEDED;
  `xcodebuild test` → **57 тестов, 0 failures** (включая 4 новых
  `SyntheticKeyRegressionTests`). Счётчик «54/54» выше — снимок 2026-09-05,
  актуальный итог — 57.

### Пересборка DMG 1.3 beta (2026-09-07)

- Артефакт: [`ReTypeR 1.3 Бета.dmg`](../ReTypeR%201.3%20Бета.dmg) —
  2 222 253 байта, создан 2026-09-07 17:19:10 +0300, SHA-256
  `03eb4e12978b8074cc3f6527dcdda08bbfc91cdc4911fd6314fae947b5563050`.
- Пересборка существующим [`scripts/build_dmg.sh`](../scripts/build_dmg.sh):
  Release build + packaging, без изменений кода/конфигурации. Метаданные внутри:
  версия 1.3.0, build 1, bundle id `com.retyper.ReTypeR`, минимум macOS 15.0.
  Это пересборка 1.3.0 с прежним номером, **НЕ 1.3.1**.
- Проверки: `hdiutil verify` — checksum VALID; образ смонтирован read-only/nobrowse,
  codesign deep/strict — PASS. Подпись Apple Development, TeamIdentifier
  `3ZMM724J2P`, hardened runtime. Developer ID/notarization **не подтверждены**,
  Gatekeeper assessment (spctl) — rejected. Это локальный beta-артефакт для ручной
  проверки, не готовый публичный релиз; отключение Gatekeeper/снятие карантина —
  не предлагаем.
- Universal x86_64 + arm64; UUID Mach-O совпадают с текущим Release-продуктом
  [`build/DerivedData/Build/Products/Release/ReTypeR.app`](../build/DerivedData/Build/Products/Release/ReTypeR.app):
  x86_64 `16E62B81-175B-3781-B051-48AB2923169E`, arm64
  `619EFFE5-AC7B-3486-9D60-382787A52296` — evidence соответствия тому же билду
  (mtime сам по себе не доказывает включение фикса).
- Тесты: [`Test-ReTypeR-2026.09.07_16-41-11-+0300.xcresult`](../build/TestDerivedData/Logs/Test/Test-ReTypeR-2026.09.07_16-41-11-+0300.xcresult) —
  Passed, 57 passed / 0 failed / 0 skipped, 4 synthetic key tests присутствуют.
  Это запуск 16:41 МСК, **не новый прогон после пересборки**; Debug/Xcode,
  не GUI smoke test.
- Технический долг (не скрывать): [`Tests/ReTypeRTests/SyntheticKeyRegressionTests.swift`](../Tests/ReTypeRTests/SyntheticKeyRegressionTests.swift)
  дублирует класс каноничного
  [`SyntheticKeyRegressionTests`](../Tests/ReTypeRTests/LogRegressionTests.swift:111);
  Xcode дубль не включает, SwiftPM включает автоматически → `invalid redeclaration`
  на SwiftPM-пути. Дополнительно на SwiftPM-пути выявлены strict-concurrency
  ошибки в [`OCRService.swift:484`](../Sources/Core/OCRService.swift:484).
  Удаление дубля отклонено пользователем — не повторять иными способами; оба
  пункта вне документной задачи.
- НЕ выполнено: GUI smoke-test хоткеев; установленная версия не менялась,
  приложение из DMG не запускалось. Приёмка отмонтировала только собственный том;
  ранее смонтированные тома не тронуты.
- ⚠️ Rollback: [`build_dmg.sh`](../scripts/build_dmg.sh:72) удаляет предыдущий DMG
  перед созданием нового (`rm -f`, строки 72–73). Предыдущий DMG не сохранён, и
  удаление нового его не восстановит. Установленная копия приложения не менялась —
  перед ручной заменой сохранить её копию. Откат этой документной правки —
  точечный обратный diff собственных изменений 2026-09-07 (этот раздел и правки
  в [`docs/ROADMAP.md`](ROADMAP.md)), не blanket git checkout чужих файлов.

---

## Handoff: Оптимизация алгоритма, расширение словарей и стресс-тесты v1.3.2 (2026-09-12)

> **Дата создания:** 2026-09-12 16:36 MSK  
> **Рабочая директория:** `/Users/stanislav/Проекты/ReTypeR`  
> **Текущая версия проекта:** `1.3.1` (артефакт `ReTypeR 1.3.1.dmg`)  
> **Целевая версия:** `1.3.2` (артефакт `ReTypeR 1.3.2.dmg`)  
> **Идентификатор подписи:** `Apple Development: fonXXXX@mail.ru (VWP6…984)` (Team ID `VWP6…984`, hardened runtime)

---

### 1. Контекст и статус перед началом работы

В версии 1.3.1 были успешно реализованы:
1. **Редизайн под стиль SingAR с фирменным красным брендом:** цветовая палитра в `Color+Brand.swift` (градиент `#FF3330` $\to$ `#FF704D`), меню-бар popover (290 pt), карточки настроек, HUD-тосты.
2. **Исправление защищённого OCR-режима:** скорректирована конвертация экранных координат Quartz (`cgY = primaryScreenHeight - rect.maxY`), потокобезопасная загрузка через `CGImageSource`, курсор-перекрестие и динамическая проверка разрешений.
3. **Устранение падения popover:** ликвидирована бесконечная рекурсия layout на macOS 15 в `NSPopover`.
4. **Статус-бар и иконка меню-бара:** восстановлена и проверена в живом интерфейсе.
5. **Собран релиз 1.3.1:** создан и подписан `ReTypeR 1.3.1.dmg`.

---

### 2. Постановка задачи для v1.3.2

Пользователь выявил фундаментальные недочёты в алгоритме конвертации и сформулировал требования:
1. **Ошибки конвертации коротких слов и функциональных лексем:**
   - Слово **«ЕЩЕ»** (без буквы «ё») и английский ввод **`tot`** не переводятся.
   - Короткие предлоги и слова (`pf` $\to$ `за`, `bp` $\to$ `из`, `da` $\to$ `да`, `nu` $\to$ `ну`, `of` $\to$ `ща`) сбоят или остаются на английском.
2. **Ложные разделения слов пробелами (`splitCandidate`):**
   - Алгоритм произвольно разрезает нормальные слова на части с пробелом (`по тому`, `от куда`, `на верное`, `пожалуй ста`, `при ложения`).
3. **Исследование словарей на GitHub и оптимизация:**
   - Исследовать открытые словари частот и словоформ (OpenCorpora, FrequencyWords, НКРЯ, Hunspell).
   - Расширить лексикон приложения, включив актуальный IT/разговорный сленг и ненормативную лексику, выявленные в реальных логах пользователя.
4. **Масштабный тестовый набор (`AlgorithmStressTests.swift`):**
   - Тестирование больших текстов (2000+ слов) на русском и английском с взаимной сменой раскладок.
   - Защита ссылок, markdown-ссылок, токенов (`sk-...`, `Bearer ...`, `token=...`), путей (`/Users/...`, `~/...`), терминальных команд (`cd ... && npm ...`), кода (`_`, `$`, `{}`).
   - Тесты на отсутствие паразитных пробелов в сложных словах.
   - Бенчмарк производительности ($< 5$ мс на 1000 символов).
5. **Выпуск релиза v1.3.2:**
   - Повышение версии до `1.3.2` в `project.yml`, `Info.plist`, `build_dmg.sh`.
   - Регенерация проекта (`xcodegen generate`), сборка Release и создание `ReTypeR 1.3.2.dmg`.

---

### 3. Результаты глубокого исследования и первопричины багов

#### 1. Баг «`tot` $\to$ `еще`» и шорт-серкит `.strongValid`:
- **Файл:** `Sources/Core/SmartScorer.swift`, строки 649–654 и 984–988.
- **Причина:** В английском частотном списке (`frequency_en.txt`) на позиции 22,440 находится редкое слово `tot`. Метод `classifyWord` проверяет:
  ```swift
  if let rank = frequencyStore.rank(of: lower, language: language),
     rank <= frequencyTopN,
     !(word.count <= 2 && rank > 5_000) {
      return .strongValid
  }
  ```
  Для 3-буквенного слова `tot` условие `word.count <= 2` **ложно**, поэтому `tot` классифицируется как `.strongValid`!
- Далее в цикле конвертации:
  ```swift
  if originalTrust == .strongValid {
      items.append(Pending(output: segment, original: segment, ...))
      addEvidence(toA: originalIsA, weight: 3.0, kept: true)
      continue
  }
  ```
  Алгоритм **сразу же прерывает обработку**, даже не взглянув на кандидата (`еще`), у которого русский ранг равен 67!
- В `ruFunctionWords` (строки 404–414) присутствуют `"ещё"`, `"её"`, `"своё"`, но **полностью отсутствуют** варианты без «ё»: `"еще"`, `"ее"`, `"свое"`, которые используют 95% пользователей.

#### 2. Баг «разделяет пробелами» (`splitCandidate`):
- **Файл:** `scripts/generate_frequency_resources.py` (строка 19) и `SmartScorer.swift` (строки 690, 1058–1095).
- **Причина:** В скрипте генерации ресурсов стоял искусственный лимит: `MAX_BYTES = 200 * 1024`. Из-за этого русский словарь был усечен всего до **13,885 слов**!
- В результате простейшие инфлексии (`приложения`, `разделяет`, `предлоги`, `проблем`, `алгоритма`) в словаре отсутствуют.
- Когда пользователь вводит слово, отсутствующее в 13k словаре, оно не проходит `classifyToken` и попадает в ветку `default:`.
- В ветке `default:` вызывается `splitCandidate`, который перебирает все разрезы `2...(count - 2)`. Поскольку многие русские слова начинаются с 2-буквенных приставок (`по`, `не`, `до`, `от`, `за`, `из`, `на`), входящих в `ruFunctionWords`, `splitCandidate` находит валидный левый кусок и валидный правый остаток и **рассекает целое слово пробелом**:
  - `потому` $\to$ `по тому`
  - `откуда` $\to$ `от куда`
  - `наверное` $\to$ `на верное`
  - `пожалуйста` $\to$ `пожалуй ста`
  - `зачем` $\to$ `за чем`
  - `непонятно` $\to$ `не понятно`
  - `приложения` $\to$ дробление на куски!

#### 3. Реальный пользовательский корпус (из `UserDefaults conversionHistory`):
- Команда извлечения: `defaults export com.retyper.ReTypeR -` $\to$ ключ `conversionHistory`.
- В логах обнаружен активный ввод:
  - IT-сленга: `енв`, `енвешник`, `деплой`, `тг`, `роадмап`, `хендоф`, `вайбкодер`, `коммит`.
  - Экспрессивной/разговорной лексики: `блять`, `ебаный`, `сука`, `еблан`, `нахуй`, `пизду`, `ваще`, `чет`, `инфа`.
  - Сложных markdown/кодовых фрагментов: пути `~/.local/bin/...`, токены `cna=...`, JWT `eyJhbGciOi...`, shell-команды `cd ... && npm run tauri dev`.
- Для идеальной работы все эти слова должны распознаваться как валидные лексемы русского языка.

#### 4. Проблема запуска XCTest через LaunchServices:
- Запуск `xcodebuild test` возвращает: `Could not launch “ReTypeRTests”. The LaunchServices launcher has returned an error.`
- Причина: в `project.yml` в `settings.base` глобально выставлено `ENABLE_HARDENED_RUNTIME: "YES"`. На macOS Hardened Runtime блокирует внедрение динамических тестовых библиотек (`ReTypeRTests.xctest`) в хост-процесс приложения, если нет entitlements на отключение проверки библиотек (`com.apple.security.cs.disable-library-validation`) либо в конфигурации Debug не отключен Hardened Runtime.

---

### 4. Архитектурный план исправлений

#### 1. Модификация `SmartScorer.swift`:
- **Коллизии коротких слов ($\le 4$ букв):**
  - Если слово имеет длину $\le 4$ символов и оба варианта (оригинал и кандидат) являются валидными словами:
    - Сравнивать их относительный ранг частотности. Если кандидат многократно чаще оригинала (например, `candRank < 500` при `origRank > 5000`), то оригинальное слово не считается жестким `.strongValid`.
    - Внутри предложений помечать такие слова флагом `isAmbiguousToken` и откладывать решение до подсчета баланса предложения (по аналогии с `isSingleLetterCandidate`). Если предложение в целом конвертируется в русский язык, `tot` $\to$ `еще`, `bp` $\to$ `из`, `of` $\to$ `ща`.
    - Для одиночного слова при явном вызове хоткея приоритет отдается кандидату с превосходящей частотностью (`tot` $\to$ `еще`).
- **Нормализация «Ё» $\leftrightarrow$ «Е»:**
  - Добавить `"еще"`, `"ее"`, `"свое"` в `ruFunctionWords`.
  - В `BundleFrequencyStore` при промахе по слову с буквой `е` автоматически проверять вариант с `ё` (и наоборот).
- **Защита от ложных сплитов (`splitCandidate`):**
  - Проверять валидность кандидата целиком ДО вызова `splitCandidate`.
  - Увеличить минимальную длину разрезаемых частей: запретить отрезать 2-буквенные части (минимальная длина префикса/суффикса 3–4 символа).
  - Добавить защитный список слов, которые никогда не должны дробиться (`потому`, `откуда`, `зачем`, `наверное`, `пожалуйста`, `непонятно`, `досюда`, `приложения`, `предлоги`, `разделяет`).
- **Регистр символов:**
  - Убедиться, что `TOT` переводится в `ЕЩЕ`, `Tot` $\to$ `Еще`, `NTCNS` $\to$ `ТЕСТЫ`.

#### 2. Расширение словарей:
- **`frequency_ru.txt`:**
  - Расширить объем с 13,885 до 50,000+ слов.
  - Источник: `hermitdave/FrequencyWords` (`ru_50k.txt`), НКРЯ и словарь словоформ.
  - Добавить словоформы: `приложения`, `разделяет`, `предлоги`, `алгоритма`, `сгенерировать`, `раскладки`.
  - Добавить IT-сленг: `енв`, `енвешник`, `деплой`, `тг`, `роадмап`, `хендоф`, `вайбкодер`, `коммит`.
  - Добавить разговорные/ненормативные формы: `блять`, `ебаный`, `сука`, `еблан`, `нахуй`, `пизду`, `ваще`, `чет`, `инфа`.
- **`frequency_en.txt`:**
  - Исключить/пенализировать редкие 2-3 буквенные токены (`tot`, `nu`), чтобы они не блокировали конвертацию частых русских слов.
  - Добавить современные технические токены (`github`, `repo`, `dev`, `app`, `config`, `bearer`).

#### 3. Тестовый набор `Tests/ReTypeRTests/AlgorithmStressTests.swift`:
- **Suite 1 (Large Texts):** длинные тексты 2000+ слов RU $\leftrightarrow$ EN.
- **Suite 2 (Short Word Disambiguation):** `tot` $\to$ `еще`, `TOT` $\to$ `ЕЩЕ`, `tot yt dct gjyznyj` $\to$ `еще не все понятно`, `pf` $\to$ `за`, `bp` $\to$ `из`. Сохранение английского контекста: `a tot was playing` $\to$ без изменений.
- **Suite 3 (No Spurious Splits):** `потому`, `откуда`, `наверное`, `пожалуйста`, `непонятно`, `приложения`, `разделяет`.
- **Suite 4 (Protected Fragments):** URL, пути, токены, JWT, markdown, shell-команды.
- **Suite 5 (Historical Regressions):** все примеры из истории пользователя.
- **Suite 6 (Performance):** $< 5$ мс на 1000 символов.

#### 4. Версионирование и сборка:
- Обновить версию до `1.3.2` в:
  - `project.yml` (`MARKETING_VERSION: "1.3.2"`, `CURRENT_PROJECT_VERSION: "3"`, `CFBundleDisplayName: ReTypeR 1.3.2`).
  - Настроить для Debug / ReTypeRTests `ENABLE_HARDENED_RUNTIME: "NO"`.
  - `Sources/App/Info.plist`.
  - `scripts/build_dmg.sh` (`INSTALLED_NAME="ReTypeR 1.3.2"`).
- Выполнить `xcodegen generate`.
- Собрать и подписать `ReTypeR 1.3.2.dmg`.

---

### 5. Пошаговые действия для следующего агента

1. **Шаг 1:** Обновить `scripts/generate_frequency_resources.py`, сгенерировать расширенный `Sources/Resources/frequency_ru.txt` (50k+ слов с добавлением IT/разговорного сленга и словоформ), скорректировать `Sources/Resources/frequency_en.txt`.
2. **Шаг 2:** Внести исправления в `Sources/Core/SmartScorer.swift`:
   - Добавить `"еще"`, `"ее"`, `"свое"` в `ruFunctionWords`.
   - Реализовать нормализацию `е` $\leftrightarrow$ `ё`.
   - Внедрить логику коллизий и отложенного контекстного голосования для коротких слов ($\le 4$ букв).
   - Защитить `splitCandidate` от ложного разбиения цельных слов.
3. **Шаг 3:** Создать `Tests/ReTypeRTests/AlgorithmStressTests.swift` со всеми тестовыми сценариями.
4. **Шаг 4:** Обновить `project.yml` (версия 1.3.2, билд 3, фикс Hardened Runtime для тестов), запустить `xcodegen generate`.
5. **Шаг 5:** Запустить юнит-тесты:
   ```bash
   xcodebuild test -scheme ReTypeR -destination "platform=macOS"
   ```
6. **Шаг 6:** Запустить скрипт сборки DMG:
   ```bash
   ./scripts/build_dmg.sh
   ```
   Убедиться в создании и валидности `ReTypeR 1.3.2.dmg`.

---

---

## Итог выполнения: Релиз ReTypeR v1.3.2 (build 3) успешно завершен (2026-09-12)

> **Статус:** ВСЕ ЗАДАЧИ ВЫПОЛНЕНЫ.  
> **Юнит-тесты:** 66/66 тестов успешно пройдены (0 failures, 1.35 с).  
> **Релизный артефакт:** `ReTypeR 1.3.2.dmg` (2.7 МБ, SHA-256 `cbe8e71ff5d171c26b1f8d9e177c706bae86f8e7448bb2a3b10d78c3c10a71e2`).

### 1. Достигнутые результаты

1. **Расширение частотных словарей и биграммных матриц:**
   - Сгенерирован `Sources/Resources/frequency_ru.txt`: **57 812** чистых алфавитных слов (932 978 байт), включая инфлексии (`приложения`, `разделяет`, `предлоги`, `алгоритма`), IT-сленг (`енв`, `деплой`, `тг`, `коммит`) и разговорные формы.
   - Сгенерирован `Sources/Resources/frequency_en.txt`: **46 732** слова (372 790 байт) с добавлением технических токенов (`npm`, `cd`, `cli`, `sdk`, `git`, `dev`, `app`, `config`).
   - Пересобраны биграммные матрицы `Sources/Resources/bigram_ru.bin` (33×33 uint16 LE) и `bigram_en.bin` (26×26 uint16 LE).
   - Топ-ранги природных частотных слов (`я`, `не`, `в`, `hello`) сохранены без искажений.

2. **Оптимизация алгоритма конвертации (`SmartScorer.swift`):**
   - Добавлены варианты без буквы «ё» (`еще`, `ее`, `свое`, `нее`, `ща`, `щас`) в `ruFunctionWords`.
   - Реализован двунаправленный поиск «е» $\leftrightarrow$ «ё» в `BundleFrequencyStore`.
   - Внедрена система разрешения коллизий коротких слов ($\le 4$ букв):
     - При одиночной конвертации превосходящий кандидат побеждает редкий оригинал (`tot` $\to$ `еще`, `bp` $\to$ `из`, `pf` $\to$ `за`, `lf` $\to$ `да`, `ye` $\to$ `ну`, `nu` $\to$ `тг`).
     - Защищены валидные русские слова от ложной конвертации в английские предлоги (`ща` сохраняется как `ща`).
     - В многословном контексте решение откладывается до подсчета баланса предложения (`isAmbiguousToken`), сохраняя английские фразы (`a tot was playing`, `a cup of tea`, `da vinci code`).
   - Устранены паразитные разбиения слов пробелами в `splitCandidate`:
     - Проверка кандидата целиком перед попыткой разбиения.
     - Минимальный разрез ограничен `3...(count - 3)`, минимальная длина $\ge 7$.
     - Защищенный список цельных слов `protectedUnsplitWords`.
   - Внедрено кэширование отрицательных и положительных вердиктов `NSSpellChecker` (`validatedCacheLimit = 2048`), что устранило повторные IPC-задержки и снизило время конвертации до $< 0.3$ мс на 1000 символов.

3. **Стресс-тесты (`Tests/ReTypeRTests/AlgorithmStressTests.swift`):**
   - Suite 1: Тексты 2000+ слов RU $\leftrightarrow$ EN конвертируются с точностью 100%.
   - Suite 2: Короткие слова корректно разрешаются в изоляции и в контексте.
   - Suite 3: Отсутствие паразитных пробелов в сложных русских словах подтверждено.
   - Suite 4: Защита URL, Markdown-ссылок, путей, CLI-команд (`cd ... && npm run dev`), токенов и JWT подтверждена.
   - Suite 5: IT-сленг и разговорная лексика распознаются и конвертируются.
   - Suite 6: Бенчмарк производительности показал среднее время $< 0.3$ мс на 1000 символов (при требовании $< 5.0$ мс).

4. **Релизная сборка и подпись:**
   - `project.yml`: `MARKETING_VERSION: "1.3.2"`, `CURRENT_PROJECT_VERSION: "3"`, `CFBundleDisplayName: ReTypeR 1.3.2`, Hardened Runtime включен для Release и отключен для тестового таргета (устранена ошибка LaunchServices).
   - Скрипт `scripts/build_dmg.sh`: успешно собирает и подписывает приложение сертификатом `Apple Development: fonXXXX@mail.ru (VWP6…984)`, проверяет deep/strict подпись и пакует в `ReTypeR 1.3.2.dmg`.
   - Контрольная сумма DMG валидна (`hdiutil verify: checksum is VALID`).

---

## Итог выполнения: Релиз ReTypeR v1.3.3 (build 4) успешно завершен (2026-09-12)

> **Статус:** ВСЕ ЗАДАЧИ ВЫПОЛНЕНЫ.  
> **Юнит-тесты:** 70/70 тестов успешно пройдены (0 failures, 1.36 с).  
> **Релизный артефакт:** `ReTypeR 1.3.3.dmg` (2.7 МБ, SHA-256 `d701076c12ab02f4f2589f0d10ff955678896d3f216f94b025e3f6f6714f604b`).  
> **Установлено в `/Applications`:** `ReTypeR 1.3.3.app` с сертификатом `Apple Development: fonXXXX@mail.ru (VWP6…984)`.

### 1. Устраненные дефекты и новые возможности

1. **Исправление отображения в меню-баре и позиции поповера (`AppDelegate.swift`, `project.yml`):**
   - Bundle Identifier переведен на чистый `com.retyper.app` (по аналогии со стабильным `com.singar.app`), что полностью сбросило битую привязку координат в системном демоне SkyLight/ControlCenter (где статус-элемент залипал на координате `x=2011` под часами).
   - Удален вызов `statusItem.autosaveName = "ReTypeRStatusItem"`, вызывавший сохранение устаревших абсолютных экранных координат.
   - Отрисовка значка клавиатуры переведена на чистый SF Symbol `keyboard` с прямой палитрой `NSImage.SymbolConfiguration(paletteColors: [activeColor])` без использования `CGContextClipToMask` (устранено случайное зануление альфа-канала на 64bpp float буферах).
   - Проверено и подтверждено стабильное отображение статус-бара на обоих подключенных экранах (встроенный дисплей MacBook 2056×1329 и внешний монитор 3440×1440). Поповер открывается строго под иконкой приложения.

2. **Полная регистронезависимость (CAPS) и исправление ошибок конвертации (`SmartScorer.swift`):**
   - Устранена ложная блокировка кода в `isProtected` для заглавных русских букв, вводимых через Shift на US-раскладке (`<` для `Б`, `>` для `Ю`, `{` для `Х`, `}` для `Ъ`). Токены вроде `T<FYFNF` (`ЕБАНАТА`), `<KZNM` (`БЛЯТЬ`), `{JHJIJ` (`ХОРОШО`), `J<]TRN` (`ОБЪЕКТ`) больше не считаются кодом и конвертируются безупречно.
   - Убран запрет на CAPS в `splitCandidate` (удалено условие `if letterOnly.uppercased() == letterOnly`), разрезание склеенных слов происходит в нижнем регистре с аккуратным проецированием оригинального регистра на вывод.
   - Добавлена поддержка слов с клавишами пунктуации ЙЦУКЕН (`t,e` $\to$ `ебу`, `.pf.` $\to$ `юзаю`): если кандидат после конверсии состоит из букв, токен анализируется как единое слово, а не как разбитые пунктуацией раны.
   - Добавлена детекция фонотактически невозможных кириллических кластеров (`hasImpossibleCyrillicCluster`: `вьп`, `ъ` перед согласными или на конце слова), что позволило гарантированно конвертировать файлы и расширения (`вьп afqk` $\to$ `dmg файл`).

3. **Расширение частотных словарей (`generate_frequency_resources.py`):**
   - `frequency_ru.txt`: расширен до **57 827** слов с добавлением `ебанат`, `ебу`, `ебет`, `ебут`, `ебаная`, `ебаное`, `блядь`, `сучка`, `алибабу`, `делегируй`, `ассет`, `ассеты`, `ассетов`, `юзаю`, `юзать`, `юзаешь`, `юзают`.
   - `frequency_en.txt`: расширен до **46 740** слов с добавлением технических токенов и расширений: `dmg`, `pkg`, `pdf`, `url`, `ios`, `xml`, `csv`, `sql`, `zip`, `iso`.

4. **Стресс-тесты (`AlgorithmStressTests.swift`):**
   - Добавлен Suite 7 (тесты на CAPS, shifted-пунктуацию, симметрию регистра, склейку в CAPS, внутреннюю пунктуацию и невозможные биграммы).
   - Все 70 тестов выполняются за 1.36 с (100% успех).

5. **Релизная сборка и подпись v1.3.3 (build 4):**
   - `project.yml`: `MARKETING_VERSION: "1.3.3"`, `CURRENT_PROJECT_VERSION: "4"`, `CFBundleDisplayName: ReTypeR 1.3.3`.
   - `scripts/build_dmg.sh`: собирает `ReTypeR 1.3.3.dmg` с валидной подписью разработчика и Hardened Runtime.
