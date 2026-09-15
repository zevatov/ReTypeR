# ReTypeR — дорожная карта v1.3.4

> ✅ **АКТУАЛЬНОЕ СОСТОЯНИЕ НА 2026-09-15 (v1.3.4 / build 5):**
> Продуктовый OCR-режим **удалён из прод-кода 2026-09-14** (решение владельца):
> захват экрана, Vision OCR, Screen Recording, UI-тумблер и хоткей убраны;
> онбординг/настройки требуют только Accessibility. Scoring-класс C и
> `ConversionSource.ocr` сохранены как внутренний scoring-флаг. 
> `xcodebuild test`: 61 test / 0 failures (1.38 с).
> Репозиторий `zevatov/ReTypeR` (private) полностью наполнен: проставлен официальный Git-тег `v1.3.4`,
> опубликован GitHub Release с прикреплённым релизным образом `ReTypeR.dmg` (4.0 МБ),
> активированы GitHub Discussions, настроены лейблы и руководства сообщества.
> Создано подробное [`docs/SETTINGS_GUIDE.md`](SETTINGS_GUIDE.md).

---

## Текущее состояние компонентов (v1.3.4)

| Компонент | Статус | Доказательство |
|---|---|---|
| Классы A–H алгоритма конвертации | ✅ реализованы | A–G: `WordTrust`, `classifyWord`, `splitCandidate`; H: `ConversionEngine.swift` |
| Расширенные частотные словари | ✅ 57.8k RU / 46.7k EN | `Sources/Resources/frequency_ru.txt`, `frequency_en.txt`, матрицы `bigram_ru.bin`, `bigram_en.bin` |
| Регистронезависимость (CAPS) и Shift-пунктуация | ✅ реализованы | Поддержка `<`, `>`, `{`, `}` как соответствий русским буквам ЙЦУКЕН; снятие ограничений на CAPS |
| Внутренняя пунктуация и фонотактика | ✅ реализованы | `.pf.` $\to$ `юзаю`; `hasImpossibleCyrillicCluster` (`вьп` $\to$ `dmg`) |
| Мультимониторный статус-бар | ✅ исправлен | Чистый `com.retyper.app`, отказ от `autosaveName`, прямое рисование SF Symbol с динамической палитрой |
| OCR / Approach S | ⛔ **Удалён из прода (2026-09-14)** | Удалён из рантайма; `NSScreenCaptureUsageDescription` отсутствует; сохраняется только scoring-флаг |
| Юнит-тесты | ✅ 61/61 passed | 61 тест / 0 failures (1.38 с): `AlgorithmStressTests`, `FrequencyAndCaptureTests`, `LayoutMapperTests`, `LogRegressionTests`, `SyntheticKeyRegressionTests` |
| Сборка и релиз | ✅ Релиз v1.3.4 опубликован | `ReTypeR.dmg` (4.0 МБ), Apple Development подпись, Hardened Runtime; тег `v1.3.4`, GitHub Release |
| Минималистичный апдейтер | ✅ реализован | Сервис `UpdateChecker` с ненавязчивым индикатором в окне настроек |
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
