# ReTypeR — Refactor Audit Handoffs (v1.3.4 / build 5)

> **Версия проекта:** 1.3.4 / build 5 · **Дата:** 2026-09-13 (обновлён 2026-09-14) · **Язык:** русский
> **Источник:** постановка владельца от 2026-09-13. Внешний отчёт аудита в репозитории
> отсутствует; формулировки ID ниже — рабочая реконструкция строго по постановке и коду.
> ID вне известного набора (Q-01/Q-02/Q-07/Q-08/Q-10+, V-04/V-05 и прочие) **не используются**.
> Известный набор: **Q-03/04/05/06/09 · V-01/02/03/06/07 · A-01…A-19 · OD-1…OD-6**.
> **PII-политика документа:** подпись маскируется — `fonXXXX@mail.ru`, `VWP6…984`, `3ZMM…J2P`.
>
> **⚠️ Решение владельца от 2026-09-14:** OCR **вырезан из прод-кода** (не «честный
> TCC-текст»): удалён [`Sources/Core/OCRService.swift`](../Sources/Core/OCRService.swift),
> `NSScreenCaptureUsageDescription`, Screen Recording из
> [`PermissionsManager.swift`](../Sources/Services/PermissionsManager.swift),
> `isOCRModeEnabled` и хоткей `ocrCapture`. Следствие: этапы 1–4 и связанные
> OCR-проверки закрыты как **N/A (OCR removed from prod)**, а не pending.
> `xcodebuild test`: 61 test / 0 failures. Scoring-класс C и
> [`ConversionSource.ocr`](../Sources/Core/SmartScorer.swift:8) сохранены
> (тесты `testOCRBasicModeMatchesHotkeyBasicMode`,
> `testLog07HyphenatedOcrJunkUntouched` живы).

---

## Статус этапов

| Этап | Тема | Статус |
|---|---|---|
| 0 | Documentation + audit-каркас | ✅ **completed (docs)** — исторически; UI-plist-хвост закрыт удалением OCR |
| 1 | Формулировки UI: OCR = видимая область | ⛔ **N/A (OCR removed from prod)** |
| 2 | `NSScreenCaptureUsageDescription` — правдивая формулировка SR | ⛔ **N/A (OCR removed from prod)** — ключ из plist/project.yml удалён |
| 3 | Момент запроса Screen Recording (UX) | ⛔ **N/A (OCR removed from prod)** — SR-запросов больше нет |
| 4 | tmp-гигиена OCR-кадра (права файла) | ⛔ **N/A (OCR removed from prod)** — OCR-кадр не создаётся |
| 5 | Сверка SECURITY после кодовых этапов (noforwards ≠ DRM, AX) | ⛔ **N/A (OCR removed from prod)** — сверка выполнена в docs-синхронизации 2026-09-14 |
| 6 | Финальная верификация (T-O, plist, read-back) | ⛔ **N/A (OCR removed from prod)** — V-06/V-07 отменены, см. Verification |

**Историческая справка Этапа 0** (запись сохранена, актуальность утрачена после
удаления OCR — перечисленные строки больше не существуют в этом виде):
- [`Info.plist:31`](../Sources/App/Info.plist:31) — `NSScreenCaptureUsageDescription` (удалён 2026-09-14);
- [`OnboardingView.swift:59`](../Sources/Views/OnboardingView.swift:59) — подзаголовок про «копирование защищённого текста» (удалён вместе с OCR-блоком онбординга);
- [`SettingsView.swift:272`](../Sources/Views/SettingsView.swift:272) — тумблер «OCR-режим» (удалён).

---

## Open decisions (OD-1…OD-6)

| ID | Решение | Статус |
|---|---|---|
| OD-1 | Момент SR-запроса. Закрыт удалением OCR: SR-запросов в приложении больше нет. | ⛔ **N/A (OCR removed from prod)** |
| OD-2 | Формулировка `NSScreenCaptureUsageDescription`. Закрыт удалением ключа из [`Info.plist`](../Sources/App/Info.plist) / [`project.yml`](../project.yml). | ⛔ **N/A (OCR removed from prod)** |
| **OD-3** | **ПРИНЯТ (исторически):** OCR работал **только с видимой областью, выбранной пользователем жестом**. Поверхность удалена 2026-09-14. | ✅ принят → ⛔ поверхность удалена |
| OD-4 | Коммуникация «клиентские защиты от копирования» (noforwards ≠ DRM). Закрыт удалением OCR как функции; исторические формулировки — [`docs/ARCHITECTURE_V13.md`](ARCHITECTURE_V13.md), Часть 2. | ⛔ **N/A (OCR removed from prod)** |
| OD-5 | tmp-файл OCR-кадра (`retyper-*.png`) без `0600`. Закрыт удалением OCR: файл больше не создаётся. | ⛔ **N/A (OCR removed from prod)** |
| OD-6 | Состав residual-рисков [`SECURITY.md`](../SECURITY.md): обновлён 2026-09-14, OCR-пункты сняты как N/A. | ✅ закрыт (docs-синхронизация) |

---

## Questions (известные: Q-03/04/05/06/09)

| ID | Вопрос | Рабочий ответ (обновлён 2026-09-14) |
|---|---|---|
| Q-03 | OCR по умолчанию выключен? | Исторически — да (default off). Актуально: OCR удалён из прод-кода — настройки/тумблера нет. |
| Q-04 | Когда запрашивать Screen Recording? | ⛔ N/A: SR не запрашивается (OCR removed from prod). |
| Q-05 | Какими словами описывать OCR в UI? | ⛔ N/A: OCR-элементов UI нет (OCR removed from prod). |
| Q-06 | Нужен ли 0600 на tmp-кадр? | ⛔ N/A: tmp-кадр не создаётся (OCR removed from prod). |
| Q-09 | Обещать ли в README GitHub Releases/notarization? | Нет: публичный Releases-URL не гарантируется, notarization не подтверждён — README не обещает ни того, ни другого. |

---

## Verification (известные: V-01/02/03/06/07)

| ID | Что проверяется | Статус |
|---|---|---|
| V-01 | Read-back всех 7 затронутых путей после записи (3 новых + 4 правленых) | ✅ выполнен 2026-09-13 |
| V-02 | Grep полных PII (e-mail/Team ID подписи) в README/SECURITY/NOTICE/handoffs — 0 совпадений; маски форма: `fonXXXX@mail.ru`, `VWP6…984`, `3ZMM…J2P` | ✅ выполнен 2026-09-13; повторно подтверждено в docs-синхронизации 2026-09-14 |
| V-03 | README не обещает обход «защищённых чатов», Releases-URL, notarization | ✅ выполнен 2026-09-13; подтверждено 2026-09-14 |
| V-06 | Ручные OCR-сценарии T-O-01…T-O-08 | ⛔ **N/A (OCR removed from prod)** |
| V-07 | Внешняя проверка `NSScreenCaptureUsageDescription` в собранном `ReTypeR.app/Contents/Info.plist` | ⛔ **N/A (OCR removed from prod)** — ключа нет ни в исходниках, ни (после пересборки) в бандле |

---

## Actions (A-01…A-19)

> A-01…A-08 — по постановке (выполнены/зафиксированы в Этапе 0).
> A-09…A-19 — бывший план; закрыт решением владельца 2026-09-14 как
> N/A (OCR removed from prod) — правки UI/SR/tmp не требуются: функции нет.

| ID | Действие | Этап | Статус |
|---|---|---|---|
| A-01 | Создать [`docs/ref-audit-handoffs.md`](ref-audit-handoffs.md) | 0 | ✅ |
| A-02 | Создать [`SECURITY.md`](../SECURITY.md) (threat model) | 0 | ✅ |
| A-03 | Создать [`NOTICE.md`](../NOTICE.md) (MIT + CC-BY-SA) | 0 | ✅ |
| A-04 | Править [`README.md`](../README.md): OCR = видимая область; Approach S — implementation detail; OCR default off; без Releases-URL/notarization; без PII; ссылки на SECURITY/handoffs | 0 | ✅ (исторически; обновлено 2026-09-14 — OCR убран как функция) |
| A-05 | Править [`FREQUENCY_DATA_LICENSE.md`](../Sources/Resources/FREQUENCY_DATA_LICENSE.md): убрать 200 KB budget; ~57k RU / ~46k EN через [`generate_frequency_resources.py`](../scripts/generate_frequency_resources.py); CC-BY-SA сохранить | 0 | ✅ |
| A-06 | Править [`docs/ROADMAP.md`](ROADMAP.md): убрать PII из актуального статуса; DiagTests-файла нет — не требовать удаление; LS-only ≠ инвариант; ссылка на handoffs; T-O PENDING; историю P0–P4 не переписывать | 0 | ✅ (исторически; обновлено 2026-09-14 — T-O сняты как N/A) |
| A-07 | [`CHANGELOG.md`](../CHANGELOG.md): `## [Unreleased]` Этап 0 docs (не 1.3.4) | 0 | ✅ |
| A-08 | Принцип «не врать о назначении SR»: закрыт радикально — SR удалён вместе с OCR (решение владельца 2026-09-14) | 0→2 | ✅ закрыт удалением |
| A-09 | Правка [`OnboardingView.swift:59`](../Sources/Views/OnboardingView.swift:59) | 1 | ⛔ N/A (OCR removed from prod) |
| A-10 | Правка [`SettingsView.swift:272`](../Sources/Views/SettingsView.swift:272) | 1 | ⛔ N/A (OCR removed from prod) |
| A-11 | Правка [`Info.plist:31`](../Sources/App/Info.plist:31) | 2 | ⛔ N/A — ключ удалён (OCR removed from prod) |
| A-12 | Решение OD-1 (момент SR-запроса) | 3 | ⛔ N/A (OCR removed from prod) |
| A-13 | Кодовая правка UX-запроса SR по OD-1 | 3 | ⛔ N/A (OCR removed from prod) |
| A-14 | Решение OD-5 (tmp 0600) | 4 | ⛔ N/A (OCR removed from prod) |
| A-15 | Код + тест tmp-прав (если OD-5 = да) | 4 | ⛔ N/A (OCR removed from prod) |
| A-16 | Сверка [`SECURITY.md`](../SECURITY.md) с фактическим кодом после этапов 1–4 | 5 | ✅ выполнена в docs-синхронизации 2026-09-14 (OCR-пункты сняты) |
| A-17 | Финальная сверка формулировок noforwards/DRM и «AX зачем» | 5 | ✅ закрыта 2026-09-14 (noforwards/DRM-формулировки исторические, AX актуален) |
| A-18 | Ручные T-O-прогоны (V-06) | 6 | ⛔ N/A (OCR removed from prod) |
| A-19 | Финальный read-back + V-07 | 6 | ⛔ N/A (OCR removed from prod) |

---

## Этап 0 — Documentation + audit-каркас ✅ (исторически completed)

- **Цель:** вся документация соответствует фактическому поведению; без PII, без нереализованных обещаний.
- **Scope:** docs/README/CHANGELOG/FREQUENCY_DATA_LICENSE. Код, plist, UI-строки — не трогались (на момент этапа).
- **Acceptance:** V-01…V-03 зелёные; запрещённые ID отсутствуют; история P0–P4 в ROADMAP не переписана.
- **Rollback:** `rm docs/ref-audit-handoffs.md SECURITY.md NOTICE.md && git checkout -- README.md docs/ROADMAP.md CHANGELOG.md Sources/Resources/FREQUENCY_DATA_LICENSE.md`.
- **Примечание 2026-09-14:** этап остаётся исторически completed; его UI/plist-хвост
  («pending code») закрыт не правками формулировок, а удалением OCR целиком.

## Этапы 1–4 — ⛔ N/A (OCR removed from prod)

Исторические разделы этапов 1–4 (формулировки UI, `NSScreenCaptureUsageDescription`,
момент SR-запроса, tmp-гигиена) сохранены ниже в справочных целях; предлагать
правки UI/SR/tmp больше не нужно — соответствующий код удалён 2026-09-14.

- **Этап 1 (исторически):** UI-строки OCR («видимая область по вашему жесту», OD-3)
  — поверхность удалена.
- **Этап 2 (исторически):** plist-строка SR — ключ удалён из
  [`Info.plist`](../Sources/App/Info.plist) и [`project.yml`](../project.yml).
- **Этап 3 (исторически):** SR-промпт раньше включения OCR — SR-промптов нет.
- **Этап 4 (исторически):** tmp-кадр `retyper-*.png` — файл не создаётся.

## Этап 5 — Сверка SECURITY ✅ (закрыта docs-синхронизацией 2026-09-14)

- [`SECURITY.md`](../SECURITY.md) отражает фактический код: OCR/SR сняты как
  продуктовая поверхность (§3/§5 — N/A), residual-риски обновлены, AX — единственная
  живая TCC-поверхность.

## Этап 6 — Финальная верификация ⛔ N/A (OCR removed from prod)

- V-06 (T-O-01…T-O-08) и V-07 отменены как OCR-проверки; read-back docs-правок
  2026-09-14 выполнен по каждому изменённому файлу (см. [`CHANGELOG.md`](../CHANGELOG.md), Unreleased).

---

## Obsidian

**blocked** — Obsidian не используется в этой синхронизации; обновление заметки
`4_Spaces/Projects/ReTypeR/Project_ReTypeR.md` выполняет владелец операции через
`obsidian-knowledge-sync` по собственному протоколу (targeted search/get до записи,
marker `ZOO_PIPELINE_`, read-back).
