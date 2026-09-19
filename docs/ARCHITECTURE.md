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
существующие balances и progress без изменений. В той же bootstrap boundary
profile-isolated и идемпотентно выдаётся starter `care_toothbrush`, без списания
wallet и fake transaction.

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
настроение. Новый Финни начинает Day 1 с `55/80/80`; отдельная прежняя база `40`
сохраняется для формулы утра Day 2–5.

`game_periods.day_progress` хранит виртуальный progress `0..100`; фазы
`morning/daytime/evening` выводятся по порогам `35/70`, а bedtime открывается с
`76`. UI не может передать произвольный progress или effect. Узкие internal
ports связывают canonical plan/task/savings/item/petting mutation с изменением
progress, cumulative natural decay (`60/20/12` к концу дня), effect, usage и
idempotency proof в одной SQLite transaction. Реальное foreground/background
время Pet не меняет; прежний tracker и публичный elapsed-time mutation удалены.

Таблица `pet_daily_usage` является period-bound источником лимитов item/free
actions и time-bearing кормлений/ухода. `ItemUseService` перечитывает canonical
item по ID, а repository одной SQLite transaction обновляет Pet, progress,
quantity расходника и usage. Постоянные предметы не расходуются; их лимиты и
morning/evening slots зубной щётки переживают restart и автоматически отделены
новым period ID. `pet_action_operations` хранит durable proof для безопасного
replay по `operationId`. Расчёт значений следующего утра детерминирован и не
привязан к реальному календарному времени.

Завершение дня проходит через
`DayLifecycleService` и приватный `DayLifecyclePort`: Core проверяет checkpoints,
порог progress `76`, зелёную зону или точную достижимость ухода из canonical
inventory/shop с учётом virtual decay и затем одной transaction фиксирует ending
wallet, период и стадию питомца. Следующее
утро применяется атомарно со стартом Day 2–5 через `PetStateRules.nextMorningPet`.
Стадии не зависят от XP: новый Финни начинает с Stage 1, Day 2 переводит его в
Stage 2, Day 5 — в Stage 3.

## Shop и специальные покупки

`PurchaseService` принимает только `itemId` и разрешает его через canonical
`shop_items.json`; внутренний `PurchasePort` атомарно обновляет wallet,
transaction и inventory. Runtime-объект `gameRepositoryProvider` не реализует
`PurchasePort`. Покупка не применяет эффекты к Pet: использование предмета
остаётся отдельной операцией `ItemUseService`. В каталоге display section
отделена от финансовой категории NEED/WANT; аксессуары сохраняются в inventory,
но не имеют эффектов использования.

Day 3 story purchase и Day 4 promotion загружаются из отдельных JSON assets.
Их сервисы принимают только IDs и `operationId`, а внутренний
`SpecialPurchasePort` атомарно связывает финансовую операцию (или skip),
`period_special_actions` proof и соответствующий checkpoint. Generic
`resolveCheckpoint` не закрывает `changed_circumstance` и
`discount_decision`. Повтор успешной операции проверяет durable proof до
отказа по статусу периода.

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
или Home. Постоянная нижняя навигация: `Финни | Вещи | Магазин | Задания |
Накопления`. Home укладывает готового Финни спать и ведёт на нейтральный Period
Summary; после Day 2 и Day 5 используется `/progress`, а следующий период
запускается только отдельным действием на Home.
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

Текущая schema version — 9. Миграция v1 → v2 добавляет period definition identity,
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
usage или Pet. Миграция v6 → v7 добавляет только `period_special_actions` с
уникальными action/operation identities на профиль и период; существующие
runtime-данные не переписываются. Миграция v7 → v8 удаляет legacy
`mandatory_need` из period snapshots с сохранением порядка остальных
checkpoints, корректирует полностью решённый active period в `readyToFinish` и
нормализует Stage 0 в Stage 1 без сброса runtime-данных. Миграция v8 → v9
добавляет `day_progress`, безопасно отображает planning/ready/completed и legacy
active elapsed-time в `0/76/100/0..69`, не пересчитывает существующие Pet stats и
идемпотентно выдаёт каждому профилю starter toothbrush. Следующие
изменения схемы должны добавлять последовательные миграции; нельзя пересоздавать
базу с потерей NORMAL-профиля.
