# Руководство по внесению изменений (Contributing)

Мы рады вкладу в развитие **ReTypeR**! Перед тем как отправить Pull Request или открыть Issue, ознакомьтесь с основными правилами проекта.

## 🎯 Принципы разработки

1. **Строгое следование канону сборки**:
   - Единственный источник правды для структуры проекта — [`project.yml`](project.yml).
   - Файл `ReTypeR.xcodeproj` генерируется через XcodeGen (`xcodegen generate`) и **не коммитится в git**.

2. **Сохранение архитектуры**:
   - Вся конвертация происходит строго локально, без сетевых запросов и телеметрии.
   - Продуктовый OCR-режим полностью удален и не должен возвращаться в кодовую базу.
   - Любые изменения в логике конвертации раскладок должны покрываться модульными и стресс-тестами в `Tests/ReTypeRTests`.

3. **Конфиденциальность и безопасность**:
   - Запрещено коммитить персональные данные (PII), токены, пароли, приватные сертификаты или ключи.
   - См. [`SECURITY.md`](SECURITY.md).

## 🛠️ Локальная разработка

### Требования
- macOS 15.0+ (Sequoia)
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Python 3.10+ с установленным `dmgbuild` (для сборки DMG-образов)

### Команды
```bash
# Генерация Xcode проекта
xcodegen generate

# Запуск полного набора юнит-тестов
xcodebuild test -project ReTypeR.xcodeproj -scheme ReTypeR -destination 'platform=macOS'

# Сборка приложения в Release
xcodebuild build -project ReTypeR.xcodeproj -scheme ReTypeR -configuration Release

# Сборка подписанного релизного DMG-пакета
scripts/build_dmg.sh
```

## 📋 Открытие Issues и Pull Requests

- **Баг-репорты**: указывайте версию macOS, используемую раскладку и конкретные примеры входного и ожидаемого текста.
- **Pull Requests**: убедитесь, что все 61/61 тестов успешно проходят (`TEST SUCCEEDED`) и код отформатирован.
