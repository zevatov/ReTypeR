# ReTypeR

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)](https://swift.org)
[![Tests](https://img.shields.io/badge/Tests-61%20passing-brightgreen?style=flat-square)](Tests/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.3.4%20(build%205)-purple?style=flat-square)](project.yml)

**ReTypeR** — нативная утилита для macOS, которая исправляет текст, набранный в неправильной
раскладке клавиатуры: `ghbdtn` → `привет`, `руддщ` → `hello`. Работает с любой парой
раскладок через умный анализ текста (v1.3). Вся обработка выполняется локально, без сети.

> Историческая справка: продуктовый OCR-режим (распознавание текста с выделенной
> области экрана) **удалён из прод-кода 2026-09-14**. Исторические упоминания OCR —
> [`CHANGELOG.md`](CHANGELOG.md) (блок [1.3.0]),
> [`docs/ARCHITECTURE_V13.md`](docs/ARCHITECTURE_V13.md), [`docs/HANDOFF.md`](docs/HANDOFF.md).

## Возможности v1.3.4

### Умная конвертация раскладок (классы A–H)

- **Трёхуровневая валидация слов**: белые списки → частотные словари → орфографический
  словарь macOS (только для слов длиной ≥ 4 — короткие аббревиатуры `kb`, `gb`, `bp`
  не считаются доказательством языка).
- **Расширенный частотный слой**: более 57 800 русских и 46 700 английских слов (OpenSubtitles 2018 +
  современные инфлексии, IT-терминология `git`, `npm`, `cli`, `sdk`, `деплой`, разговорная лексика);
  частотные словари встроены в приложение и дают надежное свидетельство при выборе
  направления конвертации.
- **Char-bigram модель**: компактные профили биграмм букв (33×33 RU / 26×26 EN,
  ~2 КБ) разрешают несловарные случаи (например, `[bhjcvc` → `хиросмс`).
- **Полная регистронезависимость (CAPS) и Shift-пунктуация**:
  - `GHBDTN` → `ПРИВЕТ`, `PFGECNB KJRFK[JCN` → `ЗАПУСТИ ЛОКАЛХОСТ`.
  - Поддержка символов `<` (`Б`), `>` (`Ю`), `{` (`Х`), `}` (`Ъ`): фразы вроде
    `T<FYFNF LTKTUBHEQ PFLFXB <KZNM` корректно конвертируются в `ЕБАНАТА ДЕЛЕГИРУЙ ЗАДАЧИ БЛЯТЬ`.
- **Внутренняя пунктуация раскладки**: токены вроде `t,e` преобразуются в `ебу`, а `.pf.` — в `юзаю`.
- **Фонотактический фильтр невозможных кластеров**: сочетания вроде `вьп` отсеиваются в пользу английских
  расширений и терминов (`вьп afqk` → `dmg файл`).
- **Разрешение коллизий коротких слов**: `tot` → `еще`, `bp` → `из`, `pf` → `за`, `lf` → `да`, `ye` → `ну`
  с контекстным голосованием для сохранения английских фраз (`a tot was playing`, `a cup of tea`).
- **Слипшиеся слова**: разделение двух известных слов, когда разрез однозначен.
- **Гистерезис направления и безопасный дефолт**: исключает осцилляции, не трогает URL, e-mail, пути и код.
- **Стабильный статус-бар на всех мониторах**: нативное отображение SF Symbol в темной и светлой теме,
  корректное позиционирование без перекрытия системными часами.

## Хоткеи

| Комбинация | Действие |
|---|---|
| ⌃⇧Space | Конвертировать выделенный текст |

(Настраиваются в настройках ReTypeR: меню-бар → Настройки.)

## Требования

- macOS 15.0+
- Разрешение **Accessibility** (чтение выделенного текста и эмуляция клавиш)

## Установка

1. Откройте DMG-образ приложения (соберите его локально через `scripts/build_dmg.sh`
   или используйте готовый релизный образ `ReTypeR.dmg`).
   Исходники размещены в GitHub-репозитории [`zevatov/ReTypeR`](https://github.com/zevatov/ReTypeR).
2. Перетащите **ReTypeR** в папку **Applications**.
3. Запустите приложение из **Applications**. При первом запуске:
   - Выдайте разрешение **Accessibility** в окне онбординга — оно обязательно для
     хоткей-конвертации.
   - Приложение подписано персональным сертификатом Apple Development; notarization
     не выполнялся, поэтому Gatekeeper может показать предупреждение при первом запуске.
   - Выданные разрешения сохраняются между обновлениями и перезагрузками благодаря
     стабильному Team ID подписи.

## Обновления

ReTypeR включает минималистичную проверку обновлений:
- Приложение периодически проверяет наличие новых версий на GitHub Releases или в канале разработки [`t.me/vostr_dev`](https://t.me/vostr_dev).
- При обнаружении новой версии в окне «Настройки» отображается ненавязчивый индикатор со ссылкой на релиз.
- Никакие персональные данные или телеметрия при этом не передаются.

## Приватность

ReTypeR обрабатывает все данные локально: ничего не отправляется на серверы.

При этом приложение ведёт локальные журналы в `~/Library/Application Support/ReTypeR/`:

- `conversion_log.jsonl` — журнал конвертаций (исходный и сконвертированный текст);
- история последних 50 конвертаций — доступна в интерфейсе приложения.

**Отключение истории**: тумблер **«Сохранять историю конвертаций»** в настройках
ReTypeR (меню-бар → Настройки). Вести журнал можно включить в настройках (по умолчанию он выключен); там же — кнопка очистки журнала.

Полная модель угроз и границы доверия — [`SECURITY.md`](SECURITY.md); текущий
план доработок документации и UX — [`docs/ref-audit-handoffs.md`](docs/ref-audit-handoffs.md).

## Сборка

Проект использует [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate          # генерирует ReTypeR.xcodeproj из project.yml
xcodebuild build -project ReTypeR.xcodeproj -scheme ReTypeR -configuration Release
```

Или брендированная сборка DMG одной командой:

```bash
scripts/build_dmg.sh       # → ReTypeR.dmg в корне проекта
```

Тесты:

```bash
xcodebuild test -project ReTypeR.xcodeproj -scheme ReTypeR -destination 'platform=macOS'
```

## Данные частотности

Файлы `frequency_ru.txt`, `frequency_en.txt`, `bigram_ru.bin`, `bigram_en.bin`
производны от проекта [FrequencyWords](https://github.com/hermitdave/FrequencyWords)
(корпус OpenSubtitles 2018) и распространяются по лицензии **CC-BY-SA-4.0**.
Подробности и регенерация: [`FREQUENCY_DATA_LICENSE.md`](Sources/Resources/FREQUENCY_DATA_LICENSE.md),
[`generate_frequency_resources.py`](scripts/generate_frequency_resources.py).

## Лицензия

Код ReTypeR распространяется под лицензией **MIT** — см. [`LICENSE`](LICENSE).

Данные частотности (частотные словари и bigram-модели) распространяются по лицензии
**CC-BY-SA-4.0** — см. [`FREQUENCY_DATA_LICENSE.md`](Sources/Resources/FREQUENCY_DATA_LICENSE.md)
и [`NOTICE.md`](NOTICE.md).

## Архитектура

Спецификация алгоритма v1.3: [`docs/ARCHITECTURE_V13.md`](docs/ARCHITECTURE_V13.md).

Ключевые компоненты:
- [`SmartScorer.swift`](Sources/Core/SmartScorer.swift) — принятие решений по токенам
  (валидация, голосование, гистерезис, bigram tie-breaker);
- [`LayoutMapper.swift`](Sources/Core/LayoutMapper.swift) — карты раскладок и адаптер;
- [`ConversionEngine.swift`](Sources/Core/ConversionEngine.swift) — оркестрация хоткея.
