# Finny — Presentation Outline

Это outline для презентации, а не готовый PPTX/PDF. Он рассчитан примерно на
9 слайдов и использует только подтверждённые возможности текущего `main`
(`a22335cc86c6a3fbb177a08721e9b78deb98bffe`).

Формулировки описывают Finny как инструмент тренировки базовых финансовых
навыков. Они не обещают гарантированного результата обучения и не называют
приложение финансовым советником.

### Slide 1 — Проблема и аудитория

**Основные тезисы**

- Finny рассчитан на детей 7–11 лет.
- Ребёнку трудно увидеть последствия выбора между необходимым, желаемым и
  накоплением.
- Приложение переводит эти решения в короткие игровые ситуации с виртуальными
  монетами.
- Ошибка объясняется и исправляется, а не превращается в наказание.

**Визуал**

- Один чистый кадр Finny на Home.
- Небольшая схема «выбор → последствие → новый выбор».

**Что сказать устно**

Finny не заменяет обучение в семье или школе. Он даёт ребёнку безопасную
игровую среду, где можно потренироваться планировать ограниченный ресурс и
увидеть связь решения с результатом.

**Evidence**

`README.md`, `docs/PRODUCT_SPEC.md`, `lib/features/home/home_screen.dart`.

### Slide 2 — Идея Finny и core loop

**Основные тезисы**

- Финансовые решения встроены в заботу о виртуальном питомце.
- В каждом периоде есть доход, план бюджета, покупки/накопления, задание и
  последствия.
- Plan/fact сохраняет разницу между намерением и реальным действием.
- Время периода виртуальное: приложение не требует ждать календарный день.

**Визуал**

```text
игровой доход
      ↓
план бюджета
      ↓
решение: купить / отложить / накопить
      ↓
последствия для кошелька, цели и Финни
      ↓
plan / fact и следующий период
```

**Что сказать устно**

Питомец делает финансовый выбор эмоционально понятным, но экономика остаётся
игровой: здесь нет банковского счёта, реальных платежей или облачного аккаунта.

**Evidence**

`docs/CORE_GAME_LOOP.md`, `lib/services/period_service.dart`,
`lib/services/day_lifecycle_service.dart`.

### Slide 3 — Бюджет: нужное, желаемое и накопления

**Основные тезисы**

- Бюджет делится на «Нужно», «Хочется» и «Копилка».
- До подтверждения виден остаток.
- После подтверждения plan становится неизменяемым снимком.
- Факт формируется из реальных игровых операций и сравнивается с plan.

**Визуал**

- Screenshot `BudgetScreen` с ненулевыми тремя категориями и visible remainder.
- Простая диаграмма `plan → purchase/save → fact`.

**Что сказать устно**

Важно показать не пустой редактор, а осмысленный пример: например, часть
ресурса отложена на цель, часть оставлена для обязательных покупок, а остаток
виден до подтверждения.

**Evidence**

`lib/features/budget/budget_screen.dart`, `lib/services/budget_service.dart`,
`test/home_budget_planning_test.dart`, `test/features/period_summary_screen_test.dart`.

### Slide 4 — Финансовые задания: фактические mechanics

**Основные тезисы**

- Day 1 — `categorization`: 6 карточек распределяются между «Нужно» и
  «Хочу»; доступны drag-and-drop и tap fallback.
- Ошибочные карточки получают точечный feedback; ответ можно исправить без
  штрафа.
- Day 2 — `budget_priority`: отдельный лимит 150 монет, покупки «сейчас» или
  «на потом».
- В Day 2 показываются корм за 90, шампунь за 60 и бантик за 80; превышение
  лимита блокируется с сообщением о дефиците.
- Day 3–5 сейчас используют более простой тип `choice`.

**Визуал**

- Hero task frame Day 1 с карточками и двумя зонами.
- Второй кадр Day 2 с бюджетом 150 и сообщением «Не хватает 20 монет».

**Что сказать устно**

Главный интерактивный пример лучше строить вокруг Day 2: эксперт сразу видит
ограниченный ресурс, компромисс и feedback. Не следует описывать Day 3–5 как
самостоятельные drag/minigame-механики — в текущем `main` это `choice`.

**Evidence**

`assets/content/tasks.json`, `lib/features/tasks/tasks_screen.dart`,
`lib/features/tasks/budget_priority_task_screen.dart`,
`test/features/tasks/day1_categorization_task_test.dart`,
`test/features/tasks/day2_budget_priority_task_test.dart`.

### Slide 5 — Накопления и финансовые цели

**Основные тезисы**

- Одновременно активна одна цель.
- В текущем контенте есть ночник за 400, самокат за 600 и игровой домик за 900
  монет.
- Кошелёк и копилка хранятся раздельно.
- На экране видны накопленная сумма, цена и оставшаяся сумма.
- После достижения цели есть отдельное подтверждение получения.

**Визуал**

- Screenshot `SavingsScreen` с выбранной целью, progress bar и заметным
  `Осталось`.
- Маленькая схема `wallet → savings goal → claim`.

**Что сказать устно**

Накопление здесь не декоративная полоска: оно конкурирует за тот же игровой
ресурс с покупками, но не смешивается с обычным кошельком.

**Evidence**

`assets/content/goals.json`, `lib/features/savings/savings_screen.dart`,
`lib/services/savings_service.dart`, `test/features/savings/savings_core_test.dart`.

### Slide 6 — Состояние и развитие Финни

**Основные тезисы**

- Home показывает сытость, уход и настроение.
- Статы изменяются детерминированными Core rules и действиями игрока.
- В приложении есть 3 стадии развития питомца.
- Текущая последовательность переводит Финни к Stage 2 после Day 2 и к Stage 3
  после Day 5.
- Объяснение связи качества финансовых решений с формулой роста остаётся
  вопросом product/customer clarification.

**Визуал**

- Home с тремя подписанными показателями.
- Progress screenshot со стадией 2 или 3 из заранее подготовленного состояния.

**Что сказать устно**

Можно честно показать, что действия имеют последствия для состояния Финни.
Нельзя обещать, что текущая стадия уже вычисляется по сложной оценке качества
plan/fact или накоплений: такой scoring formula ещё не зафиксирован.

**Evidence**

`lib/models/pet_state_rules.dart`, `lib/features/home/home_screen.dart`,
`lib/features/progress/progress_screen.dart`,
`test/services/day_lifecycle_test.dart`,
`test/services/final_campaign_integration_test.dart`.

### Slide 7 — Adult section и общий прогресс

**Основные тезисы**

- Adult открывается через long-press barrier из Settings.
- После unlock видны цель приложения, темы обучения, дни из 5, стадия Финни и
  накопления.
- В актуальном `main` Adult также содержит управление данными NORMAL.
- Reset удаляет игровой runtime progress, сохраняя профиль, имя и внешний вид
  Finny.
- Delete удаляет локальный NORMAL-профиль после отдельного подтверждения.

**Визуал**

- Loaded Adult overview после barrier.
- При необходимости второй кадр — confirmation dialog reset/delete; действие
  в live-demo не нажимать.

**Что сказать устно**

Раздел взрослого — это место для обзора и безопасных локальных операций. Важно
объяснить, что отдельного пользовательского DEMO mode с готовым reseed-flow в
текущем приложении нет.

**Evidence**

`lib/features/adult/adult_screen.dart`, `lib/features/adult/adult_controller.dart`,
`lib/repositories/profile_data_management_repository.dart`,
`test/features/adult/adult_screen_test.dart`,
`test/repositories/profile_data_management_test.dart`.

### Slide 8 — Offline-first архитектура и безопасность

**Основные тезисы**

- Flutter/Dart UI организован через Riverpod controllers.
- GoRouter задаёт маршруты и nested navigation.
- Domain services и repositories отделены от UI.
- SQLite хранит локальный профиль, game state, transactions, inventory и
  progress.
- Образовательный контент загружается из JSON assets.
- Нет обязательного аккаунта, реальных денег, рекламы, подписок, публичного
  детского чата или облачной синхронизации.

**Визуал**

```text
Flutter UI
   ↓
Riverpod / GoRouter
   ↓
services + narrow mutation ports
   ↓
SQLite + JSON assets
```

**Что сказать устно**

Offline-first здесь означает, что основной Core не зависит от сети и не требует
передачи ребёнком реальных финансовых или контактных данных.

**Evidence**

`docs/ARCHITECTURE.md`, `lib/app/providers.dart`,
`lib/core/database/app_database.dart`, `lib/repositories/content_repository.dart`,
`android/app/src/main/AndroidManifest.xml`.

### Slide 9 — Технологии, соответствие и честные ограничения

**Основные тезисы**

- Stack: Flutter/Dart, Riverpod, GoRouter, SQLite/sqflite, JSON content,
  Material 3.
- Current main содержит MVP Core, тесты и Requirements Matrix.
- Day 1 и Day 2 имеют отдельные mechanics; Day 3–5 — `choice`.
- Физический Android 8+ smoke, portrait, performance measurements, release APK,
  RuStore package, final screenshots, presentation и backup video требуют
  отдельного verification/final package.
- Outline, shotlist и checklist сами по себе не являются готовой сдачей.

**Визуал**

- Один слайд-таблица «реализовано в коде / требуется проверить на устройстве /
  внешний final artifact».
- Ссылка на репозиторий и Requirements Matrix после появления проверенных
  внешних artifact links.

**Что сказать устно**

Сильная сторона проекта — работающий offline MVP и прозрачный Core. Риски не
нужно скрывать: финальная упаковка, физическое устройство и часть UX-доказательств
являются отдельным этапом сдачи.

**Evidence**

`docs/REQUIREMENTS_MATRIX.md` на актуальном `origin/main`,
`pubspec.yaml`, `android/app/build.gradle.kts`.

## Перед передачей outline дизайнеру/спикеру

- Сделать реальные screenshots по `docs/SCREENSHOT_SHOTLIST.md`.
- Выбрать основной live-demo route по `docs/DEMO_SCRIPT.md`.
- Заменить placeholders ссылками на фактический repository/APK/video только
  после проверки доступа.
- Не называть outline готовой презентацией и не обещать final artifacts.
