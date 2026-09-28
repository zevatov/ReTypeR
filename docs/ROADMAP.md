# ReTypeR — дорожная карта v1.3.5

> ✅ **АКТУАЛЬНОЕ СОСТОЯНИЕ НА 2026-09-28 (v1.3.5 / build 6):**
> Локально подготовлен релиз **1.3.5 / build 6** ([`project.yml`](../project.yml)):
> fallback-карта US↔Mac Russian, если TIS не отдал layout data (headless CI);
> `updateStatusIcon` выполняется в `@MainActor Task`; алгоритм конвертации
> не менялся. **DMG собран локально, GitHub Release 1.3.5 ещё НЕ опубликован**;
> репозиторий `zevatov/ReTypeR` остаётся **private** до команды владельца.
> Юнит-тесты на момент последней проверки: **61/61 passed** (новый прогон не выполнялся).
> Релиз v1.3.4 был опубликован на GitHub ранее (тег `v1.3.4`, DMG 4.0 МБ,
> Discussions, лейблы, руководства сообщества). Продуктовый OCR-режим удалён
> из прод-кода 2026-09-14 (история — [`CHANGELOG.md`](../CHANGELOG.md)).
> Создано подробное [`docs/SETTINGS_GUIDE.md`](SETTINGS_GUIDE.md).

---

## Текущее состояние компонентов (v1.3.5)

| Компонент | Статус | Доказательство |
|---|---|---|
| Классы A–H алгоритма конвертации | ✅ реализованы | A–G: `WordTrust`, `classifyWord`, `splitCandidate`; H: `ConversionEngine.swift` |
| Расширенные частотные словари | ✅ 57.8k RU / 46.7k EN | `Sources/Resources/frequency_ru.txt`, `frequency_en.txt`, матрицы `bigram_ru.bin`, `bigram_en.bin` |
| Регистронезависимость (CAPS) и Shift-пунктуация | ✅ реализованы | Поддержка `<`, `>`, `{`, `}` как соответствий русским буквам ЙЦУКЕН; снятие ограничений на CAPS |
| Внутренняя пунктуация и фонотактика | ✅ реализованы | `.pf.` $\to$ `юзаю`; `hasImpossibleCyrillicCluster` (`вьп` $\to$ `dmg`) |
| Мультимониторный статус-бар | ✅ исправлен | Чистый `com.retyper.app`, отказ от `autosaveName`, прямое рисование SF Symbol с динамической палитрой |
| OCR / Approach S | ⛔ **Удалён из прода (2026-09-14)** | Удалён из рантайма; `NSScreenCaptureUsageDescription` отсутствует; сохраняется только scoring-флаг |
| Юнит-тесты | ✅ 61/61 passed (на момент последней проверки) | 61 тест / 0 failures: `AlgorithmStressTests`, `FrequencyAndCaptureTests`, `LayoutMapperTests`, `LogRegressionTests`, `SyntheticKeyRegressionTests` |
| Сборка и релиз | 🟡 Локально 1.3.5 / build 6, GitHub Release не опубликован | DMG собран локально; Apple Development (Team ID `3ZMM724J2P`), Hardened Runtime, без notarization; репо private, публикация — по команде владельца |
| Минималистичный апдейтер | ✅ реализован | [`UpdateChecker.swift`](../Sources/Services/UpdateChecker.swift): один GET-запрос `releases/latest` при открытии настроек, бейдж «Доступна X», тихий «актуально» при отсутствии релиза/сети |
| Privacy opt-in | ✅ | История opt-in (`isHistoryEnabled`); журнал opt-in (`isConversionLogEnabled`) |
| Документация | ✅ синхронизирована | [`docs/SETTINGS_GUIDE.md`](SETTINGS_GUIDE.md), [`docs/AGENT_PIPELINE.md`](AGENT_PIPELINE.md), [`docs/ARCHITECTURE_V13.md`](ARCHITECTURE_V13.md), [`README.md`](../README.md) со скриншотами |

---

## 🗺️ Дорожная карта и Экосистема (The Native macOS Suite)

### 🍏 Концепция экосистемы
ReTypeR развивается в рамках серии нативных, бесплатных, приватных и сверхбыстрых утилит для macOS от Stanislav Zevatov:
- **[SingAR](https://github.com/zevatov/SingAR)** — нативный голосовой ввод, ассистент диктовки и vibe-кодинга для macOS (локальный Whisper + Metal, буфер обмена).
- **[ReTypeR](https://github.com/zevatov/ReTypeR)** — мгновенная умная автоконвертация раскладки клавиатуры без сети и задержек.

### 🎯 Ближайшие этапы развития ReTypeR:
- [ ] **v1.4.0 — Редизайн и поднастройка меню настроек (Следующий релиз):**
  - Обновление внешнего вида окна параметров под современные визуальные гайдлайны macOS 15 Sequoia.
  - Повышение наглядности управления горячими клавишами и раскладками.
  - Улучшение группировки системных чекбоксов и индикаторов статуса.
- [ ] **Интеграция в экосистему:**
  - Общие шорткаты и стандарты взаимодействия с родственными утилитами экосистемы.
