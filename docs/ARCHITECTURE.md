# Finny architecture

## Цель foundation

Архитектура рассчитана на offline-first Android MVP и параллельную работу двух
разработчиков. Она намеренно невелика: общие контракты находятся в моделях,
repositories и services, а продуктовые модули развиваются независимо внутри
`lib/features/`.

## Слои и зависимости

```text
UI / Features
    ↓
Riverpod State / Controllers
    ↓
Domain Services
    ↓
Repositories
    ↓
SQLite / JSON assets
```

UI может читать состояние через Riverpod и вызывать сервисы, но не должен
напрямую менять кошелёк, накопления, периоды, задания или развитие питомца.
`lib/app/providers.dart` является composition root и связывает сервисы с
repository-контрактами.

## Runtime state и content

SQLite хранит только состояние конкретного локального профиля: профиль,
питомца, кошелёк, накопления, периоды, транзакции, инвентарь и прогресс заданий.
Все runtime-таблицы связаны с `profiles.id`; foreign keys включены. Денежные
остатки имеют ограничения `CHECK >= 0`, а изменение кошелька и запись
транзакции выполняются в одной SQLite transaction.
`GameRepository.ensureInitialState(profileId)` атомарно создаёт нулевое
состояние только при его отсутствии; повторные вызовы возвращают
существующие balances и progress без изменений.

JSON в `assets/content/` описывает доступный контент: задания, товары, цели,
периоды и словарь. `ContentRepository` скрывает загрузку через `AssetBundle` и
возвращает типизированные модели. Новый контент не должен требовать изменений
виджетов или ядра, если его схема уже поддерживается.

## Core Game Loop

Периоды проходят только через состояния `planning → active → readyToFinish →
completed`. `PeriodService` выбирает следующую definition из content, а
`GameRepository` одной SQLite transaction создаёт runtime snapshot периода,
начисляет базовый доход и обновляет wallet/current period. Незавершённый период
у профиля может быть только один.

Budget draft хранится в `planned_*` полях периода. После подтверждения plan
неизменяем. Fact и additional income вычисляются из persisted transactions
конкретного period instance; `extra_income` и `actual_*` синхронно обновляются в
тех же Core-транзакциях как runtime aggregates, но журнал остаётся источником
Period Summary. Required/resolved checkpoints сохраняются snapshot-списками у
периода. Подробнее: [Core Game Loop](CORE_GAME_LOOP.md).

## Savings goals

`GameState.savedAmount` — глобальная копилка профиля, а `activeGoalId` и
`goalChangeUsed` описывают текущий цикл цели. Canonical identity и цена целей
загружаются из `assets/content/goals.json` через `SavingsService`; UI передаёт
только IDs и суммы. Выданные цели фиксируются отдельно в `completed_goals`, а
их persistent rewards — в `inventory`. Deposit и claim атомарно изменяют все
связанные runtime-записи и имеют durable idempotency proof.

## Pet state core

`pets` хранит три характеристики Финни в диапазоне `0..100`: сытость, уход и
настроение. Для нового Финни canonical начальное значение каждой характеристики
равно 40. UI не вычисляет ухудшение самостоятельно: `PetStateService` передаёт
фактически накопленное foreground active-time в атомарный repository-контракт.

Active-time и уже применённый decay сохраняются в конкретном `game_periods`.
За первые шесть минут активного игрового времени линейно набираются дневные
максимумы `15/10/12`; после этого дальнейшее время состояние не снижает.
`planning` и `completed` не принимают decay. Таблица `pet_daily_usage` является
period-bound источником лимитов item/free actions. `ItemUseService` перечитывает
canonical item по ID, а repository одной SQLite transaction обновляет Pet,
quantity расходника и usage. Постоянные предметы не расходуются; их лимиты,
morning/evening slots зубной щётки и бесплатные взаимодействия переживают
restart и автоматически отделены новым period ID. `pet_action_operations`
хранит durable proof для безопасного replay по `operationId`. Расчёт значений
следующего утра детерминирован и не привязан к реальному календарному времени.

## NORMAL и DEMO

`ProfileType` поддерживает `NORMAL` и `DEMO`. Состояние всегда запрашивается и
изменяется с `profileId`. Операция очистки demo runtime state сначала проверяет
тип профиля и не разрешена для NORMAL. Сами профили при такой очистке
сохраняются.

`activeProfileIdProvider` в `lib/app/providers.dart` — единый shared-контракт
текущего активного профиля. До app-level инициализации его значение равно
`null`: Foundation не создаёт профиль и не выбирает его по неявному правилу.
После выбора уже существующего профиля app-level flow устанавливает его ID через
`ActiveProfileIdController`, а feature-модули читают provider и передают этот ID
в services/repositories. Выбор профиля не является ответственностью feature.

Обычный startup учитывает только `NORMAL`. `ProfileRepository.create` проверяет
отсутствие другого NORMAL внутри SQLite transaction; DEMO не ограничивается.
Если в прежней базе оказалось несколько NORMAL, bootstrap сообщает конфликт и
не выбирает профиль автоматически. `onboardingCompleted` означает подтверждение
игрового имени после трёх шагов, независимо от создания Pet. App-level bootstrap
обеспечивает Core state через `GameRepository.ensureInitialState(profileId)`
до установки active profile и не сбрасывает существующее состояние.

## Навигация и тема

`lib/app/router.dart` содержит GoRouter-маршруты для всех согласованных модулей.
Стартовый `/startup` ожидает bootstrap и направляет на onboarding, Pet Creation
или Home. Home открывает Savings, завершает готовый период и ведёт на минимальный
Period Summary; следующий период запускается только отдельным действием на Home.
Светлая Material 3 тема, базовые отступы и радиусы определены в
`lib/core/theme/app_theme.dart`.

## Как добавлять feature

1. Развивать экран и локальное состояние внутри соответствующей папки
   `lib/features/`.
2. Получать зависимости через Riverpod providers.
3. Читать/изменять runtime state через существующий service/repository contract.
4. Если контракта недостаточно, расширить один общий контракт, обновить его
   реализации и тесты — не создавать второй параллельный state/storage слой.
5. Хранить настраиваемый игровой контент в JSON, а не в UI.

## Миграции

Текущая schema version — 6. Миграция v1 → v2 добавляет period definition identity,
required/resolved checkpoint snapshots и индекс period transactions, не удаляя
существующие профили, balances, планы или историю. Для прежних периодов 1–5
identity/checkpoint snapshot восстанавливается из зафиксированных v2 definitions;
их сохранённый `baseIncome` не переписывается. Миграция v2 → v3 добавляет
`game_states.goal_change_used` и таблицу `completed_goals`, не выводя completion
из inventory и не сбрасывая wallet, savings, periods или историю. Миграция
v3 → v4 гарантирует canonical `task_progress`. Миграция v4 → v5 добавляет care,
persisted active-time/decay и `pet_daily_usage`, сохраняя прежние характеристики
питомца и всё финансовое состояние. Миграция v5 → v6 добавляет только durable
proof операций использования предметов/взаимодействий и не изменяет inventory,
usage или Pet. Следующие
изменения схемы должны добавлять последовательные миграции; нельзя пересоздавать
базу с потерей NORMAL-профиля.
