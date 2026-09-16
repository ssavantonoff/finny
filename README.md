# Finny

Offline-first Android-приложение CodexTeam для хакатона «Лидеры цифровой
трансформации 2026». Через заботу о виртуальном питомце дети 7–11 лет учатся
планировать бюджет, отличать нужное от желаемого и копить на цели.

Сейчас в репозитории находится технический foundation MVP: Flutter-каркас,
маршрутизация, базовые модели, SQLite repositories, JSON content и публичные
контракты игровых сервисов. Полноценные механики и финальный UI ещё не
реализованы.

## Стек

- Flutter / Dart
- Riverpod
- GoRouter
- SQLite (`sqflite`)
- JSON assets

## Запуск

Требуется актуальный stable Flutter SDK и настроенный Android toolchain.

```bash
flutter pub get
flutter run
```

Проверки:

```bash
flutter analyze
flutter test
```

## Документация

- [Архитектура](docs/ARCHITECTURE.md)
- [Core Game Loop](docs/CORE_GAME_LOOP.md)
- [Краткая продуктовая спецификация](docs/PRODUCT_SPEC.md)
- [Правила для Codex-агентов](AGENTS.md)
