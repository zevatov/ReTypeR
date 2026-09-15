# ReTypeR — дорожная карта v1.3.4

> ✅ **АКТУАЛЬНОЕ СОСТОЯНИЕ НА 2026-09-14 (v1.3.4 / build 5):**
> Продуктовый OCR-режим **удалён из прод-кода 2026-09-14** (решение владельца):
> захват экрана, Vision OCR, Screen Recording, UI-тумблер и хоткей ⌃⇧O убраны;
> онбординг/настройки требуют только Accessibility. Scoring-класс C и
> [`ConversionSource.ocr`](../Sources/Core/SmartScorer.swift:8) сохранены как
> внутренний scoring-флаг. `xcodebuild test`: 61 test / 0 failures.
> Релиз v1.3.4 — патч после вырезки OCR (build 5). Предыдущий верифицированный
> релиз v1.3.3 (2026-09-12): CAPS/Shift-символы, внутренняя пунктуация,
> фонотактический фильтр, мультимониторный статус-бар. Артефакт
> `ReTypeR 1.3.4.dmg` собирается [`scripts/build_dmg.sh`](../scripts/build_dmg.sh)
> с персональным сертификатом Apple Development (`fonXXXX@mail.ru`,
> Team `3ZMM…J2P`, Hardened Runtime); notarization не выполнялся.
> Текущий план: [`docs/ref-audit-handoffs.md`](ref-audit-handoffs.md).
> **Следующая сессия: [`docs/HANDOFF_GEMINI_38.md`](HANDOFF_GEMINI_38.md)** —
> private GitHub `zevatov/ReTypeR`, чистка [.gitignore](../.gitignore),
> synthetic verification (61 тест), кнопки Telegram/GitHub post-deploy,
> решение OD по auto-update (private source vs public Releases).

## Текущее состояние (evidence на 2026-09-14)

| Компонент | Статус | Доказательство |
|---|---|---|
| Классы A–H алгоритма конвертации | ✅ реализованы | A–G: [`WordTrust`](../Sources/Core/SmartScorer.swift:19), [`classifyWord`](../Sources/Core/SmartScorer.swift:555), [`splitCandidate`](../Sources/Core/SmartScorer.swift:629); H: [`ConversionEngine.swift`](../Sources/Core/ConversionEngine.swift) |
| Расширенные частотные словари | ✅ 57.8k RU / 46.7k EN | `Sources/Resources/frequency_ru.txt`, `frequency_en.txt`, матрицы `bigram_ru.bin`, `bigram_en.bin` |
| Регистронезависимость (CAPS) и Shift-пунктуация | ✅ реализованы | Поддержка `<`, `>`, `{`, `}` как соответствий русским буквам ЙЦУКЕН; снятие ограничений на CAPS в `splitCandidate` |
| Внутренняя пунктуация и фонотактика | ✅ реализованы | `t,e` $\to$ `ебу`, `.pf.` $\to$ `юзаю`; `hasImpossibleCyrillicCluster` (`вьп` $\to$ `dmg`) |
| Мультимониторный статус-бар | ✅ исправлен | Чистый `com.retyper.app`, отказ от `autosaveName`, прямое рисование SF Symbol с динамической палитрой |
| OCR / Approach S | ⛔ **removed from prod (2026-09-14)** | [`Sources/Core/OCRService.swift`](../Sources/Core/OCRService.swift) удалён; `NSScreenCaptureUsageDescription` отсутствует в [`Info.plist`](../Sources/App/Info.plist) и [`project.yml`](../project.yml); [`PermissionsManager.swift`](../Sources/Services/PermissionsManager.swift) без Screen Recording; хоткей `ocrCapture` и pref `isOCRModeEnabled` удалены. Scoring-флаг [`ConversionSource.ocr`](../Sources/Core/SmartScorer.swift:8) сохранён |
| Тесты | ✅ 61/61 | `xcodebuild test` — 61 тест / 0 failures: `AlgorithmStressTests`, `FrequencyAndCaptureTests`, `LayoutMapperTests`, `LogRegressionTests` (включая живые OCR-scoring-тесты `testOCRBasicModeMatchesHotkeyBasicMode`, `testLog07HyphenatedOcrJunkUntouched`) |
| Build / release | ✅ DMG 1.3.4 собран и подписан | `ReTypeR 1.3.4.dmg` (2.5 MB), SHA-256 `4fdaeeb2667b56d4350bae87efe30065668fe5adb92ec2c88e2b271f4749d8d1`, Apple Development, Team `3ZMM…J2P`, Hardened Runtime; `hdiutil verify` VALID; в бандле `CFBundleShortVersionString=1.3.4`, `CFBundleVersion=5`, без `NSScreenCaptureUsageDescription` |
| Privacy opt-in | ✅ | история opt-in: [`isHistoryEnabled`](../Sources/Services/PreferencesManager.swift:12); лог opt-in: [`ConversionLogger.log`](../Sources/Services/ConversionLogger.swift:23) |
| Robustness | ✅ | AX timeout [`TextService.applyMessagingTimeout`](../Sources/Core/TextService.swift:59); single-instance via [`LSMultipleInstancesProhibited`](../Sources/App/Info.plist:25) — это plist-настройка LaunchServices, а не runtime-инвариант: сам факт НЕ гарантирует отсутствие дублей во всех сценариях запуска |
| Разрешения (TCC) | ✅ только Accessibility | онбординг/настройки запрашивают только Accessibility; Screen Recording не запрашивается (OCR removed from prod) |

> **Историческая заметка (решено).** На снапшоте 2026-08-25 критическим gap считалось
> отсутствие исходников `TextService`, `StatisticsManager`, `LaunchManager`,
> `OnboardingView`, точки входа `ReTypeRApp`, `Color+Brand` при живых ссылках на них.
> Все исходники восстановлены, проект компилируется и тестируется. Детали —
> [HANDOFF](HANDOFF.md).

---

## Исторический план (снапшот 2026-08-25)

> Подробные этапы P0–P4 ниже сохранены как исторический контекст и **не являются
> текущим backlog**: все этапы реализованы (см. «Текущее состояние»). Пункты,
> относящиеся к OCR/Approach S, — **historical / removed from prod (2026-09-14)**.

---

## P0 — завершить класс H: переключение раскладки по output-доминанте (historical, выполнено)

**Что делать** (спека §[1.8](ARCHITECTURE_V13.md)):
1. [`performConversion()`](../Sources/Core/ConversionEngine.swift:22) переходит на
   [`convertDetailed(_:smart:source:)`](../Sources/Core/LayoutMapper.swift:120)
   вместо [`convert(text)`](../Sources/Core/LayoutMapper.swift:104).
2. Удалить локальный подсчёт `countA/countB` по входу
   ([строки 31–32](../Sources/Core/ConversionEngine.swift:31)).
3. Целевая раскладка = противоположная [`dominantSourceScript`](../Sources/Core/SmartScorer.swift:43);
   no-switch правила: `changed == false` или mixed (обе доли > 35%) → не переключать.
4. Единый tie-breaker остаётся в [`tieBreakPrefersAToB()`](../Sources/Core/LayoutMapper.swift:184).

**Критерий готовности:** hotkey-конвертация RU→EN переключает раскладку по output;
mixed >35%/35% и `changed == false` не переключают; локальный подсчёт по input удалён.

---

## P1 — Approach S в OCRService (historical / removed from prod — этап выполнен в 1.3, затем OCR удалён 2026-09-14)

**Исторический текст сохранён дословно** (спека §[2.3–2.4](ARCHITECTURE_V13.md)):
Approach S (системный `screencapture` CLI как основной провайдер кадра,
`SystemCaptureProvider` + fallback `ScreenKitProvider`, tmp-файл `retyper-<UUID>.png`,
детект серого кадра, хоткей `ocrCapture`) был реализован в 1.3.x. **Актуальный статус:
removed from prod** — [`Sources/Core/OCRService.swift`](../Sources/Core/OCRService.swift)
удалён 2026-09-14 вместе с хоткеем `ocrCapture`; возвращать этот этап в backlog
не нужно.

---

## P2 — регрессионные тесты T-C-A1…T-C-H3 + ручные T-O-01…T-O-08 (historical, выполнено)

**Что делать** (спека §[3.1–3.3](ARCHITECTURE_V13.md)):
1. Добавить 15 unit-тестов T-C-A1…T-C-H3 в
   [`Tests/ReTypeRTests/LayoutMapperTests.swift`](../Tests/ReTypeRTests/LayoutMapperTests.swift).
2. Расширить mock-словарь `testWords` fixture-минимумами; частотные списки подменять
   через injection-точку [`frequencyStore`](../Sources/Core/SmartScorer.swift:65)
   (протокол [`FrequencyStore`](../Sources/Core/SmartScorer.swift:28)).
3. Для T-C-H1…H3 нужен test-seam на переключение раскладки (сейчас
   [`switchToLayout(id:)`](../Sources/Core/LayoutMapper.swift:192) вызывает Carbon напрямую).
4. Ручные сценарии T-O-01…T-O-08 оформить чек-листом (после P1).

**Критерий готовности:** все существующие + новые T-C-* зелёные в
`xcodebuild test`; ручной прогон [`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md) — 10/10 блоков.

**Примечание 2026-09-14:** ручные T-O-01…T-O-08 — historical / N/A (OCR removed
from prod); см. [`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md).

---

## P3 — восстановить сборочную обвязку (historical, выполнено)

**Что делать:**
1. Восстановить **недостающие исходники** (блокер сборки): `TextService`,
   `StatisticsManager`, `LaunchManager`, `OnboardingView`, `ReTypeRApp`, `Color+Brand`.
2. `project.yml` (XcodeGen): target ReTypeR (macOS app, bundle id, entitlements),
   target ReTypeRTests, зависимость KeyboardShortcuts (SPM), `MARKETING_VERSION 1.3.0`.
3. `README.md` — актуализировать под v1.3 (умная конвертация A–H; требования
   macOS 15+ и разрешение Accessibility; исторически упоминались
   Accessibility/Screen Recording — SR убран 2026-09-14).
4. `scripts/build_dmg.sh` — Release-сборка + `hdiutil create` DMG.
5. Регенерация: `xcodegen generate` → `ReTypeR.xcodeproj`.

**Критерий готовности:** `xcodegen generate` создаёт проект; Release-сборка и
`xcodebuild test` проходят без ошибок компиляции.

---

## P4 — релиз v1.3.0 (historical, выполнено 2026-09-05)

**Что делать:**
1. Release-сборка через восстановленный [`scripts/build_dmg.sh`](../scripts).
2. Ручной прогон [`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md) — 10/10 блоков.
3. Ручной T-O-02 на актуальном Telegram macOS (historical / removed from prod —
   сценарий относился к OCR-режиму, удалённому 2026-09-14).
4. Проверка лога `conversion_log.jsonl`: доля `changed=false` на эталонном корпусе не выросла.
5. Синхронизация документации: заметка Obsidian
   `4_Spaces/Projects/ReTypeR/Project_ReTypeR.md` обновляется **владельцем** через
   obsidian-knowledge-sync (targeted search/get до записи, marker ZOO_PIPELINE_,
   read-back). Прямые записи в vault запрещены; агент Obsidian не трогает.

**Критерий готовности:** `ReTypeR.dmg` собран и устанавливается; все критерии приёмки
§3.3 спеки выполнены; документация синхронизирована.

---

## Зависимости между этапами

P0 → P2 (тесты H требуют завершённого движка) · P1 → P2 (ручные T-O-* требуют Approach S) ·
P3 блокирует всё выполнение (`xcodebuild` недоступен без проекта) → P4 последний.
Рекомендуемый порядок исполнения: **P3(исходники) → P0 → P1 → P2 → P3(project.yml/скрипты) → P4**.
Все этапы выполнены (historical).

---

## Post-P4: remaining release gates

Актуальный чеклист релизных шагов (обновлён 2026-09-14):

- [x] ✅ ~~Удалить `Tests/ReTypeRTests/DiagTests.swift`~~ — **неактуально**:
      файла `DiagTests.swift` в репозитории больше нет (проверено перечнем
      `Tests/ReTypeRTests/`); пересчитывать итог `xcodebuild test` не требуется —
      актуальный прогон 61/61 (2026-09-14) уже без него.
- [x] ✅ Старый [`ReTypeR.dmg`](../ReTypeR.dmg) больше не в корне — там только
      пересобранный [`ReTypeR 1.3 Бета.dmg`](../ReTypeR%201.3%20Бета.dmg).
- [x] ✅ Пересборка DMG через [`scripts/build_dmg.sh`](../scripts/build_dmg.sh) —
      выполнена 2026-09-07 17:19:10 +0300: [`ReTypeR 1.3 Бета.dmg`](../ReTypeR%201.3%20Бета.dmg),
      2 222 253 B, SHA-256 `03eb4e12978b8074cc3f6527dcdda08bbfc91cdc4911fd6314fae947b5563050`;
      это пересборка 1.3.0 (build 1), НЕ 1.3.1; hdiutil verify VALID; codesign
      deep/strict PASS (Apple Development, TeamIdentifier `3ZMM…J2P`, hardened
      runtime); Universal x86_64+arm64, UUID совпадают с Release-продуктом.
      Developer ID/notarization отсутствуют, spctl rejected — локальный beta-артефакт
      для ручной проверки, не публичный релиз. ⚠️ Скрипт удаляет предыдущий DMG
      перед созданием нового ([строки 72–73](../scripts/build_dmg.sh:72)) — считать
      «старый DMG сохранён» нельзя.
- [ ] ⬜ Проверить установку/запуск из DMG и выполнить GUI smoke-test хоткеев —
      **PENDING**: тестовый прогон 16:41 — Debug/Xcode (не GUI smoke), установленная
      версия не менялась, приложение из DMG не запускалось; перед ручной заменой
      сохранить копию установленного приложения.
- [ ] ⬜ Выполнить ручные сценарии T-C-02 / T-C-03 из
      [`docs/MANUAL_TEST_TEXT.md`](MANUAL_TEST_TEXT.md) (раздел «v1.3 release
      checklist»; PENDING). T-O-01…T-O-08 и T-C-01 — **N/A (OCR removed from prod)**.
- [ ] ⬜ ~~Внешне проверить [`NSScreenCaptureUsageDescription`](../Sources/App/Info.plist:31)
      в собранном `ReTypeR.app/Contents/Info.plist`~~ — **N/A (OCR removed from
      prod)**: ключа нет в исходниках ([`Info.plist`](../Sources/App/Info.plist),
      [`project.yml`](../project.yml)); пункт останется неприменимым для любых
      сборок после 2026-09-14.
- [ ] ⬜ Obsidian sync заметки `4_Spaces/Projects/ReTypeR/Project_ReTypeR.md` — выполняет
      **владелец операции** через MCP `obsidian-knowledge-sync` (агент MCP для этого
      не запускает).
