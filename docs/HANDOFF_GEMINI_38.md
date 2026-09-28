# ReTypeR — Операционный Handoff для Gemini 3.8 (следующая сессия)

> **Статус документа:** исторический снимок плана сессии 2026-09-15; тело не
> актуализировалось. Актуальный статус — [`docs/ROADMAP.md`](ROADMAP.md)
> (локально 1.3.5 / build 6, GitHub Release 1.3.5 не опубликован, репо private).
> Исторические handoff'ы — [`docs/HANDOFF.md`](HANDOFF.md).
>
> **Железные правила для исполнителя:**
> 1. Runtime-код не трогать, пока не выполнены задачи B–D (исключение — задача E, и только после успешного push).
> 2. Версию не bump: остаёмся **1.3.4 / build 5** ([`project.yml`](../project.yml)).
> 3. OCR не возвращать: продуктовый OCR удалён из прода 2026-09-14, scoring-класс C и
>    [`ConversionSource.ocr`](../Sources/Core/SmartScorer.swift:8) остаются как есть.
> 4. Не вставлять PII (e-mail владельца, телефон и т.п.) ни в код, ни в docs, ни в README.
> 5. Notarization и публичные Releases не обещать как факт — это решения владельца (OD).
> 6. `gh repo create` и `gh repo delete` выполняются **только после явного «да» владельца**
>    (две предыдущие попытки создания репо были отклонены владельцем в UI — не повторять молча).

---

## A. Контекст

| Параметр | Значение | Доказательство |
|---|---|---|
| Версия | **1.3.4 / build 5** | [`MARKETING_VERSION`](../project.yml:16), [`CURRENT_PROJECT_VERSION`](../project.yml:17) |
| Канон сборки | XcodeGen: `xcodegen generate` | [`project.yml`](../project.yml); `ReTypeR.xcodeproj` сгенерирован и в git не входит ([`.gitignore`](../.gitignore)) |
| Ветка / remote | `main`, **remote нет** | локальный git; репо `zevatov/ReTypeR` **ещё не существует** |
| OCR | **Удалён из прода** | [`CHANGELOG.md`](../CHANGELOG.md) блок [1.3.4]; [`ConversionSource.ocr`](../Sources/Core/SmartScorer.swift:8) сохранён только как scoring-флаг |
| Тесты | **61 / 61 passed** | `xcodebuild test -project ReTypeR.xcodeproj -scheme ReTypeR -destination 'platform=macOS'` |
| DMG | `ReTypeR 1.3.4.dmg` локально | SHA-256 `4fdaeeb2667b56d4350bae87efe30065668fe5adb92ec2c88e2b271f4749d8d1`; Team `3ZMM724J2P`; Hardened Runtime; `*.dmg` в [`.gitignore`](../.gitignore:27) — **в git не коммитить** |
| GitHub-аккаунт | **`zevatov`** | `gh` установлен (`/opt/homebrew/bin/gh`), `gh auth status` = not logged in; HTTPS-токен лежит в osxkeychain (как у SingAR) |
| Telegram | invite-ссылка `https://t.me/+rchqdp7ARSw2Njdi` | владелец, 2026-09-14; **не публичный** `@retyper_app` |
| Кнопки в UI | Telegram = устаревший `https://t.me/retyper_app`; GitHub = `https://github.com/zevatov/ReTypeR` (URL верный, репо нет) | [`SettingsView.swift:43`](../Sources/Views/SettingsView.swift:43), [`SettingsView.swift:58`](../Sources/Views/SettingsView.swift:58). **В этой сессии код кнопок не менять** — задача E |
| Auto-update | **Отсутствует** | нет Sparkle, нет `SUFeedURL` |
| Ручные тесты | T-C-02 / T-C-03 **PENDING**; T-O и T-C-01 = N/A | [`docs/ref-audit-handoffs.md`](ref-audit-handoffs.md) |

---

## B. Задача 1 — private GitHub repo

**Цель:** создать **private** репозиторий `zevatov/ReTypeR` и запушить `main`.

**Предусловие (блокирующее):** явное подтверждение владельца. Две предыдущие попытки
`gh repo create --private --push` были отклонены владельцем в UI — **не выполнять без свежего «да»**.

**Шаги:**

1. Авторизация (токен уже в osxkeychain):
   ```bash
   gh auth status          # ожидание: not logged in → потребуется gh auth login
   gh auth login           # выбрать HTTPS + keychain-токен (как у SingAR)
   ```
2. Создание и push (одной командой, из корня проекта):
   ```bash
   gh repo create zevatov/ReTypeR --private --source . --remote origin --push
   ```
3. Верификация:
   ```bash
   gh repo view zevatov/ReTypeR --json isPrivate,url
   ```
   Ожидание: `isPrivate=true`.

**Что НЕ должно попасть в git (проверить перед push через `git status`):**
`*.dmg` (включая локальные `ReTypeR 1.3.1–1.3.4.dmg`), `*.app`, `ReTypeR.xcodeproj`,
`build/`, `dist/`, секреты, `.env`.

**README:** в репо **private**; README не обещает публичный Releases-URL, пока владелец
не решит иначе (см. задачу F).

**Acceptance:**
- `gh repo view zevatov/ReTypeR --json isPrivate,url` → `isPrivate=true`.
- `git remote -v` показывает `origin`; `git push` без ошибок; `git status` чистый.

**Rollback:** удаление репо — **только владельцем** (`gh repo delete zevatov/ReTypeR --yes`).
Локально remote можно снять безвредно: `git remote remove origin`.

---

## C. Задача 2 — почистить gitignore и подготовка к репо

**Цель:** репозиторий готов к push — в индексе только исходники и docs.

**Текущее состояние** ([`.gitignore`](../.gitignore)): уже покрывает `*.xcodeproj`,
`*.dmg`, `*.app`, `build/`, `dist/`, `.build/`, `DerivedData/`, `.vscode/`, `.qoder/`,
`.gemini/`, `.agents/`, `xcuserdata/`, `roo_task_*.md`.

**Шаги:**

1. Сохранить ignore артефактов (ничего из перечисленного не удалять): `*.dmg`, `*.app`,
   `*.xcodeproj`, `build/`, `dist/`, `DerivedData/`.
2. Добавить типичные секреты, **если отсутствуют**: `.env`, `*.pem`, `*.p12`.
3. Локальные DMG 1.3.1–1.3.4 не трекать — они уже под `*.dmg`, проверить `git status`.
4. [`Package.resolved`](../Package.resolved) уже в git — **оставить** (фиксация версии
   `KeyboardShortcuts` 2.4.0).
5. Сгенерированный `ReTypeR.xcodeproj` не коммитить: канон — `xcodegen generate`
   из [`project.yml`](../project.yml).

**Acceptance:** после правки `.gitignore`:
```bash
git status
```
В индексе — только исходники/docs (`Sources/`, `Tests/`, `docs/`, `*.md`, `project.yml`,
`Package.swift`, `Package.resolved`, `.gitignore`, `LICENSE`, `NOTICE.md`, `SECURITY.md`,
`scripts/`). Ни одного `*.dmg` / `*.app` / `*.xcodeproj` / секрета.

**Rollback:** `git checkout -- .gitignore`.

---

## D. Задача 3 — synthetic verification

**Цель:** убедиться, что каноническая сборка и тесты зелёные на текущем HEAD.

**Каноническая команда:**
```bash
xcodegen generate && xcodebuild test -project ReTypeR.xcodeproj -scheme ReTypeR -destination 'platform=macOS'
```

**Ожидание:** **61 test, 0 failures**.

**Предусловие:** если запущен `/Applications/ReTypeR*.app` — остановить его перед тестами
(в бандле [`LSMultipleInstancesProhibited`](../Sources/App/Info.plist) — второй инстанс не стартует,
что ломает тест-раннер).

**Покрытие синтетикой (уже есть, ничего дописывать не нужно):**
[`LayoutMapperTests`](../Tests/ReTypeRTests/LayoutMapperTests.swift),
[`AlgorithmStressTests`](../Tests/ReTypeRTests/AlgorithmStressTests.swift),
[`LogRegressionTests`](../Tests/ReTypeRTests/LogRegressionTests.swift),
[`FrequencyAndCaptureTests`](../Tests/ReTypeRTests/FrequencyAndCaptureTests.swift)
(только frequency-часть).

**Запреты:**
- **Не** гонять T-O (OCR-сценарии) — OCR удалён из прода.
- T-C-02 (`plan b`) и T-C-03 (одинаковые раскладки) — ручные; **не отмечать зелёным без факта**.
- Не возвращать OCR ни в каком виде.

**Acceptance:** вывод `xcodebuild test` содержит `Executed 61 tests, with 0 failures`.

**Rollback:** тесты ничего не меняют в коде; при сбое — `git status` / `git checkout -- .`
и разбор ошибки, а не правка тестов под результат.

---

## E. Задача 4 — кнопки Telegram/GitHub (ТОЛЬКО после успешного push репо)

**Цель:** актуализировать ссылки в UI после того, как репозиторий фактически существует.

**Предусловие (жёсткое):** задача B выполнена — `gh repo view zevatov/ReTypeR` отвечает
`isPrivate=true`. До этого код кнопок **не менять**.

**Шаги:**

1. Telegram: в [`SettingsView.swift:43`](../Sources/Views/SettingsView.swift:43) заменить
   `https://t.me/retyper_app` → **`https://t.me/+rchqdp7ARSw2Njdi`**.
2. Проверить, нет ли второй кнопки Telegram/GitHub в
   [`MenuBarView.swift`](../Sources/Views/MenuBarView.swift) — по состоянию на 2026-09-14
   поиск по `Sources/` находит ссылки только в [`SettingsView.swift`](../Sources/Views/SettingsView.swift).
3. GitHub: оставить/подтвердить `https://github.com/zevatov/ReTypeR`
   ([`SettingsView.swift:58`](../Sources/Views/SettingsView.swift:58)) — URL станет валидным
   после создания репо.

**Риск:** invite-ссылка Telegram может устареть. Если она отдаёт 404 — **спросить владельца**,
не выдумывать `@username`.

**Acceptance:** `xcodegen generate && xcodebuild test` → 61/61; в запущенном приложении
кнопка Telegram открывает invite, кнопка GitHub открывает репо (проверка владельцем вручную).

**Rollback:** `git checkout -- Sources/Views/SettingsView.swift`.

---

## F. Задача 5 — кнопка автообновления (latest GitHub Release)

**Текущий факт:** auto-update в коде нет — ни Sparkle, ни `SUFeedURL`. Пункт
**blocked на решение владельца (OD)** — писать код до OD запрещено.

**Критический конфликт:** репо **private** + «тянуть latest release с GitHub» требуют
одного из вариантов:

| Вариант | Суть | Оценка |
|---|---|---|
| 1 | Публичные Releases / публичный репо | работает «из коробки», но исходники становятся публичными — нужно OD |
| 2 | GitHub-токен в клиенте | **неприемлемо**: токен попал бы в дистрибуцию каждому пользователю |
| 3 | Отдельный **public** releases-репо / appcast | исходники остаются private, обновления публичные; дополнительный репо в обслуживании |

**Зафиксировать как needs-user-decision** (private source vs public updates) до любого кода.

**Если владелец принял public Releases:** реализовать либо Sparkle, либо минимальный
GitHub Releases checker + кнопку «Проверить обновления» в
[`SettingsView.swift`](../Sources/Views/SettingsView.swift). Feed/URL **не выдумывать**
до фактического создания первого release.

**Блокер дистрибуции (не игнорировать):** подпись сейчас Apple Development, не Developer ID;
notarization отсутствует и по-прежнему **не обещается**. Gatekeeper будет ругаться на
автообновления, скачанные из интернета. Автообновление без Developer ID + notarization
работать честно не будет.

**Acceptance (для фазы OD):** решение владельца зафиксировано словами владельца в чате/таск-трекере;
после него — дизайн-заметка с выбранным вариантом и только затем код.

**Rollback:** `git revert` коммита автообновления; кнопка не попадает в релиз.

---

## G. Оставшиеся blockers / gaps (честный список на 2026-09-15)

1. **Нет git remote / GitHub repo** — создание было denied ×2 владельцем (задача B).
2. **`gh auth login` не выполнен** — токен в keychain есть, статус not logged in.
3. **Telegram-кнопка** в приложении ведёт на несуществующий `https://t.me/retyper_app`
   ([`SettingsView.swift:43`](../Sources/Views/SettingsView.swift:43)).
4. **GitHub-кнопка** ведёт на ещё не созданный репо
   ([`SettingsView.swift:58`](../Sources/Views/SettingsView.swift:58)).
5. **Нет auto-update**; конфликт private repo ↔ GitHub Releases не решён (задача F, OD).
6. **T-C-02, T-C-03, GUI smoke — PENDING** (ручные, факта выполнения нет).
7. **Notarization / Developer ID отсутствуют** — блокер для честной дистрибуции и автообновлений.
8. **Obsidian:** frontmatter `unit_tests` в карточке проекта всё ещё `"70 passed"` vs факт 61;
   в теле карточки жив устаревший буллет Approach S и тег `tech/vision-ocr` (не критично,
   правка — отдельной сессией, чтобы не ломать карточку).
9. **UserDefaults-сироты** `isOCRModeEnabled` / `hasRequestedScreenRecording` у части
   пользователей не вычищены (OCR удалён, ключи могли остаться в plist).
10. [`Sources/Models/`](../Sources/Models) — пустой каталог.
11. [`Package.swift`](../Package.swift) — без resources, каноном сборки не является
    (канон — XcodeGen [`project.yml`](../project.yml)); случайно запущенный `swift build` даст неполный бандл.
12. **Q-09 в ref-audit:** README не обещает Releases — автообновление (задача F) это изменит,
    нужно явное OD и обновление README/SECURITY в момент реализации.

---

## Порядок исполнения (рекомендация)

```
C (gitignore) → D (synthetic) → [OD владельца] → B (gh auth + repo create + push)
→ E (кнопки) → [OD владельца] → F (auto-update)
```

Задача C безопасна и не требует OD. Задача D — это только верификация. Задачи B и F —
каждая требует отдельного явного «да» владельца. Задача E — строго после B.
