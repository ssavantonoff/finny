# Finny — Requirements Matrix

## Область и метод проверки

**Дата проверки:** 21 сентября 2026 года

**Base commit SHA:** `0d445edfe95ae7ea07508b2dfa9ee29b4a4b8937`

Официальные требования определяют критерии проверки. Актуальный `origin/main`
является источником истины для статуса реализации. Матрица построена по
production-коду, persisted/content data, автоматизированным тестам и явным
артефактам; архитектурная документация и README используются как вспомогательные
источники.

Статусы:

- ✅ Реализовано — требование подтверждено кодом/контентом и, где существенно,
  тестом;
- 🟡 Частично — есть рабочая часть, но требование закрыто не полностью или нет
  обязательного доказательства на целевой среде;
- ❌ Не реализовано — требуемого пользовательского сценария или артефакта нет;
- ➖ Не требуется / вне scope — условное требование неприменимо к выбранной
  архитектуре без backend.

README сам по себе не считается доказательством реализации. Наличие внутреннего
метода также не считается готовым пользовательским сценарием. Эмулятор и widget
tests не заменяют физическое устройство; сборка с debug signing не считается
подписанным release APK; прохождение периодов без реального ожидания не считается
сбрасываемым DEMO-режимом.

Номер официального раздела указан в заголовке тематической таблицы и относится
ко всем строкам этой таблицы; внутри технических разделов номер также повторён в
тексте требования.

## Реестр доказательств

Чтобы не повторять длинные пути в каждой строке, названия экранов, сервисов и
моделей в колонке «Реализация / доказательство» раскрываются по этому реестру.
Для каждого функционального блока указаны наиболее сильные доказательства из
production-кода, данных и тестов; более узкая ссылка в конкретной строке имеет
приоритет.

| Блок / сокращение в строках | Production и persisted/content data | Основные проверки |
|---|---|---|
| Bootstrap / onboarding / профиль | `lib/app/bootstrap.dart`, `lib/features/onboarding/onboarding_screen.dart`, `lib/repositories/profile_repository.dart` | `test/app/bootstrap_test.dart`, `test/app/active_profile_provider_test.dart` |
| Pet Creation / preview | `lib/features/pet_creation/pet_creation_screen.dart`, `lib/features/pet_creation/pet_creation_draft.dart`, `lib/features/pet_creation/finny_preview.dart` | `test/pet_creation_screen_test.dart`, `test/pet_creation_draft_test.dart`, `test/pet_creation_persistence_test.dart` |
| Home / navigation | `lib/features/home/home_screen.dart`, `lib/app/router.dart`, `lib/app/scaffold_with_nested_navigation.dart` | `test/features/home/home_screen_atmosphere_test.dart`, `test/features/navigation_test.dart`, `test/home_budget_planning_test.dart` |
| Budget / plan-fact | `lib/features/budget/budget_screen.dart`, `lib/services/budget_service.dart`, `lib/repositories/game_repository.dart` | `test/home_budget_planning_test.dart`, `test/services/core_game_loop_test.dart`, `test/features/period_summary_screen_test.dart` |
| Shop / inventory / item effects | `lib/features/shop/shop_screen.dart`, `lib/services/purchase_service.dart`, `lib/services/item_use_service.dart` | `test/features/shop/shop_screen_test.dart`, `test/services/shop_catalog_purchase_test.dart`, `test/services/item_use_test.dart` |
| Savings / goals | `lib/features/savings/savings_screen.dart`, `lib/services/savings_service.dart`, `assets/content/goals.json` | `test/features/savings/savings_core_test.dart`, `test/features/savings/savings_screen_test.dart`, `test/features/savings/savings_controller_test.dart` |
| Tasks / rewards | `lib/features/tasks/tasks_screen.dart`, `lib/features/tasks/budget_priority_task_screen.dart`, `lib/services/task_service.dart` и `assets/content/tasks.json` | `test/features/tasks/day2_budget_priority_task_test.dart`, `test/services/task_categorization_test.dart`, `test/services/task_completion_test.dart` |
| Period / day lifecycle / Pet state | `lib/services/period_service.dart`, `lib/services/day_lifecycle_service.dart`, `lib/models/pet_state_rules.dart` | `test/services/day_lifecycle_test.dart`, `test/services/pet_state_test.dart`, `test/services/final_campaign_integration_test.dart` |
| Summary / progress / Adult | `lib/features/period_summary/period_summary_screen.dart`, `lib/features/progress/progress_screen.dart`, `lib/features/adult/adult_screen.dart` | `test/features/period_summary_screen_test.dart`, `test/features/adult/adult_screen_test.dart` |
| Persistence / migrations | `lib/core/database/app_database.dart`, `lib/repositories/game_repository.dart`, `lib/repositories/profile_repository.dart` | `test/repositories/game_repository_test.dart`, `test/core/database_migration_test.dart`, `test/core/database_v9_migration_test.dart` |
| Android / release configuration | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml` | Статическая проверка конфигурации; физический install/smoke отмечен отдельно и не подменяется тестами. |

## Сводка

| Статус | Количество |
|---|---:|
| ✅ | 191 |
| 🟡 | 63 |
| ❌ | 58 |
| ➖ | 6 |
| **Всего требований** | **318** |

## 1. Аудитория и образовательная цель

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Целевая аудитория 7–11 лет | ✅ Реализовано | Возраст зафиксирован в `pubspec.yaml`, `README.md` и `docs/PRODUCT_SPEC.md`; тексты и сценарии адресованы ребёнку. | — |
| Обучение через действия и последствия | ✅ Реализовано | Цикл budget → task/purchase/savings → period summary реализован в `lib/services/`, `lib/features/period_summary/`; проверяется `test/services/final_campaign_integration_test.dart`. | — |
| Ограниченные ресурсы и выбор приоритетов | ✅ Реализовано | Wallet не уходит ниже нуля; Day 2 использует отдельный лимит 150; магазин проверяет доступный баланс. | — |
| Различение нужного и желаемого | ✅ Реализовано | Категории NEED/WANT в `shop_items.json`; Day 1 — typed `categorization` с 6 карточками и объяснениями. | — |
| Накопления и финансовая цель | ✅ Реализовано | Отдельный saved balance, 3 цели, deposits и claim в `SavingsService` и Savings UI. | — |
| План и факт | ✅ Реализовано | Неизменяемый подтверждённый plan и fact из persisted transactions показываются в Period Summary. | — |
| Отсутствие персональных советов о реальных финансах | ✅ Реализовано | Контент ограничен игровыми монетами, питомцем и учебными ситуациями; банковских/инвестиционных рекомендаций в assets и UI нет. | — |

## 2. Первый запуск и локальный профиль — 2.5.1

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Короткое введение в цель игры | ✅ Реализовано | Трёхшаговый onboarding в `lib/features/onboarding/onboarding_screen.dart` объясняет заботу, монеты и накопления. | — |
| Объяснение «Нужно / Хочется / Копилка» | ✅ Реализовано | Термины объясняются на втором шаге onboarding. | — |
| Гостевой локальный режим без регистрации | ✅ Реализовано | Bootstrap создаёт единственный NORMAL-профиль в SQLite; аккаунтов и backend нет. | — |
| Не запрашивать реальное имя, телефон или email | ✅ Реализовано | Единственный ввод — игровое имя; полей телефона/email и сетевой регистрации нет. | — |
| Игровое имя | ✅ Реализовано | `ProfileName` валидирует имя; onboarding сохраняет его локально. | — |
| Выбор персонажа | ✅ Реализовано | После onboarding обязательна Pet Creation; bootstrap направляет профиль без питомца на `/pet-creation`. | — |
| Возможность вернуться к первоначальной подсказке | ❌ Не реализовано | Settings открывает глоссарий, но повторного просмотра трёх шагов onboarding или эквивалентной полной подсказки нет. | Добавить доступный из Settings повтор onboarding/«Как играть» с исходными правилами. |
| Ошибка сохранения не теряет введённое имя | ✅ Реализовано | Retry сохраняет текст; покрыто `test/app/bootstrap_test.dart`. | — |

## 3. Создание питомца — 2.5.2

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Имя питомца | ✅ Реализовано | Pet Creation требует имя длиной 1–20 символов. | — |
| Настройка внешности | ✅ Реализовано | Выбираются цвет и узор, preview обновляется до сохранения. | — |
| Не менее 9 визуально различимых комбинаций | ✅ Реализовано | 3 цвета × 3 узора в `PetCreationDraft`; `FinnyPreview` визуально различает их; тест проверяет списки вариантов. | — |
| Сохранение питомца и внешности после перезапуска | ✅ Реализовано | Pet хранится в SQLite; `test/pet_creation_persistence_test.dart` проверяет восстановление. | — |
| Повторная настройка внешности после создания | ❌ Не реализовано | Production-маршрута редактирования питомца после создания нет. | Добавить безопасный экран повторной настройки, если это ожидается заказчиком. |

## 4. Главный экран — 2.5.3

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Питомец виден на Home | ✅ Реализовано | `HomeScreen` отображает `FinnyPreview` и имя питомца. | — |
| Доступный баланс виден на Home | ✅ Реализовано | `home-wallet` показывает persisted `walletBalance`. | — |
| Накопления и текущая цель видны на Home | ✅ Реализовано | Карточка `home-savings-goal` показывает имя цели и saved/price. | — |
| Показатели питомца видны и понятны | ✅ Реализовано | Сытость, уход и настроение имеют подписи, progress bars и semantic values. | — |
| Активное финансовое задание | 🟡 Частично | Home показывает checkpoint «Задание» и его выполнение, но не название/содержание текущего задания и не прямую CTA на него. | Показать конкретное активное задание и действие «Открыть задание». |
| Все обязательные Home-данные видны одновременно без сложной навигации | 🟡 Частично | `HomeScreen` одновременно показывает Pet, wallet, stats и при active goal — savings/goal; task представлен только общим checkpoint, а не конкретным активным заданием. | Показать название/состояние активного задания и проверить полный Home state на 360dp. |
| Доступ к бюджету | ✅ Реализовано | Планирование и просмотр plan доступны с Home через `/budget`. | — |
| Доступ к задачам, магазину и накоплениям | ✅ Реализовано | Постоянная нижняя навигация содержит «Магазин», «Задания», «Накопления». | — |
| Доступ к прогрессу и разделу взрослого | 🟡 Частично | Adult доступен через Settings; Progress открывается только после Day 2/5 и не имеет постоянной точки входа. | Добавить постоянный экран/пункт истории и прогресса из основного интерфейса. |
| Главная показывает следующий понятный шаг | ✅ Реализовано | Состояния planning/active/ready показывают CTA и карточку статуса дня; блокирующие диалоги предлагают вернуться, открыть вещи/магазин или завершить допустимым fallback. | — |

## 5. Игровая валюта и доход — 2.5.4

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Только игровая валюта | ✅ Реализовано | Экономика использует целые игровые монеты; платежных SDK и реальных валют нет. | — |
| Базовый доход в каждом периоде | ✅ Реализовано | Все 5 definitions имеют `baseIncome: 500`; старт периода атомарно начисляет доход. | — |
| Награды за задания | ✅ Реализовано | 6 заданий имеют rewards; Task completion атомарно пишет reward transaction. | — |
| Пользователь видит сумму начисления | 🟡 Частично | Task success показывает `+N монет`, а Day 1 явно показывает базовый доход; при старте Day 2–5 сумма нового базового дохода отдельно не объясняется. | Показывать сумму базового дохода при старте каждого периода. |
| Пользователь видит источник каждого начисления | 🟡 Частично | Источник хранится в transactions, а task/day UI объясняет текущие начисления; общей доступной пользователю истории операций с источниками нет. | Добавить журнал операций или иной доступный просмотр всех начислений и источников. |
| Каждое изменение wallet имеет persisted transaction/source | ✅ Реализовано | SQLite transactions и service boundaries покрыты repository/service tests; plan не меняет деньги. | — |
| Нет необъяснимого изменения баланса | ✅ Реализовано | Денежные mutations атомарны, canonical и идемпотентны; `test/services/core_game_loop_test.dart` и purchase/savings tests проверяют журнал. | — |

## 6. Планирование бюджета — 2.5.5

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Категории «Нужно / Хочется / Накопления» | ✅ Реализовано | Три отдельных редактора в `BudgetScreen`. | — |
| Сумма распределения не превышает бюджет | ✅ Реализовано | UI ограничивает maximum; Core отклоняет отрицательные значения и превышение. | — |
| Остаток показан до подтверждения | ✅ Реализовано | `budget-remainder` пересчитывается от `startingBudget`. | — |
| План можно менять до подтверждения | ✅ Реализовано | Draft сохраняется и редактируется в planning. | — |
| Подтверждение плана требует явного действия | ✅ Реализовано | Перед confirm показывается bottom sheet с тремя суммами и остатком. | — |
| Подтверждённый plan неизменяем | ✅ Реализовано | После перехода в active UI read-only, repository запрещает изменение; есть Core test. | — |
| Факт не переписывает план | ✅ Реализовано | Actual fields/transactions отделены от planned fields. | — |
| Дополнительный доход не переписывает plan | ✅ Реализовано | Проверено `additional income changes Home wallet but not confirmed plan` в `test/home_budget_planning_test.dart`. | — |
| Plan/fact и отклонения показываются после периода | ✅ Реализовано | `PeriodSummaryScreen` показывает строки plan/fact/deviation и остаток. | — |

## 7. Покупки и инвентарь — 2.5.6

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Цена видна до покупки | ✅ Реализовано | Карточка и details показывают цену. | — |
| Категория NEED/WANT видна до покупки | ✅ Реализовано | Details выводит цену и `shopCategory(item)`. | — |
| Ожидаемый эффект на питомца виден до покупки | 🟡 Частично | Для предметов с effect details показывает «Ожидаемый эффект»; аксессуары без эффекта не объясняют, что это только внешний/коллекционный предмет. | Явно объяснить отсутствие stat-effect и назначение аксессуаров/игрушек. |
| Явное подтверждение покупки | ✅ Реализовано | Двухшаговый details flow показывает «Купить … за N монет?»; cancel не создаёт operation. | — |
| Wallet уменьшается на canonical цену | ✅ Реализовано | `PurchaseService` разрешает item по ID; atomically меняются wallet и transaction. | — |
| Покупка фиксируется в истории | ✅ Реализовано | Создаётся typed NEED/WANT transaction с source `purchase_<id>`. | — |
| Предмет появляется в inventory | ✅ Реализовано | Purchase atomically обновляет inventory; Shop/Things sync покрыт tests. | — |
| Отрицательный баланс невозможен | ✅ Реализовано | Core проверка и SQLite `CHECK >= 0`; insufficient purchase не мутирует состояние. | — |
| Недостаточно средств: покупка заблокирована | ✅ Реализовано | Authoritative Core возвращает typed error; UI не завершает покупку. | — |
| Сообщение показывает цену, баланс и дефицит | ✅ Реализовано | UI: «Цена / У тебя / Не хватает»; widget test проверяет canonical amounts. | — |
| Сообщение предлагает следующий вариант действия | 🟡 Частично | Дефицит посчитан, но сообщение не предлагает заработать, выбрать дешевле или отложить покупку. | Добавить понятный recovery CTA/совет без давления. |
| Покупка и использование разделены | ✅ Реализовано | Purchase кладёт в inventory; `ItemUseService` отдельно применяет effect. | — |

## 8. Накопления и цели — 2.5.7

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Не менее 3 целей | ✅ Реализовано | `goals.json`: ночник, самокат, игровой домик. | — |
| Выбор цели | ✅ Реализовано | Карточки целей и dialog подтверждения. | — |
| Цена цели видна | ✅ Реализовано | Цена видна в карточке/dialog/active goal. | — |
| Накоплено и осталось видны | ✅ Реализовано | Отдельные balances, progress и `missingAmount`. | — |
| Можно регулярно пополнять накопления | ✅ Реализовано | Deposit доступен в каждом active/ready period и имеет amount controls. | — |
| Накопления сохраняются между периодами и рестартом | ✅ Реализовано | `GameState.savedAmount` отделён от period; reopen tests для savings. | — |
| Накопления отделены от wallet | ✅ Реализовано | UI показывает «Кошелёк» и «Копилка» отдельно; SQLite хранит разные balances. | — |
| Claim достигнутой цели | ✅ Реализовано | Claim списывает canonical цену из savings, пишет completed goal и reward inventory. | — |
| После claim можно выбрать следующую цель | ✅ Реализовано | Completed goal исключается из available; остаются другие цели; all-completed state предусмотрен. | — |
| Подтверждение списания из копилки | ✅ Реализовано | Dialog показывает цель, цену и остаток после получения. | — |
| Прогноз срока достижения цели | ➖ Не требуется / вне scope | В продукте нет календарных сроков и deadline; периоды виртуальные. | — |

## 9. Финансовые задания — 2.5.8 и 2.6

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Не менее 6 заданий | ✅ Реализовано | `tasks.json` содержит 6 уникальных заданий. | — |
| Не менее 3 образовательных тем | ✅ Реализовано | Темы: needs/wants, priorities, adapting plan, discounts, planning, reserve. | — |
| Смысловое покрытие планирования бюджета | ✅ Реализовано | Day 2 `budget_priority` и Day 5 `planning` в `assets/content/tasks.json`. | — |
| Смысловое покрытие сбережений | ✅ Реализовано | Day 5 bonus `reserve`; обязательный savings decision встроен в каждый period. | — |
| Смысловое покрытие платежей/покупок | ✅ Реализовано | Day 1 needs/wants, Day 2 purchases, Day 3 unexpected NEED и Day 4 discount. | — |
| Day 1 — categorization | ✅ Реализовано | Typed `categorization`, 6 карточек, drag и tap fallback, исправление и item feedback. | — |
| Day 2 — budget_priority | ✅ Реализовано | Typed budget 150, buy now/later, over-budget feedback и canonical validation. | — |
| Day 3–5 — разнообразные интерактивные механики | 🟡 Частично | Day 3, Day 4 и два задания Day 5 используют один простой тип `choice`; специальные Day 3/4 покупки добавляют ситуации, но не заменяют разнообразие task mechanics. | Перевести Day 3–5 в самостоятельные интерактивные механики, сохранив Core guarantees. |
| Возрастная понятность | ✅ Реализовано | Короткие формулировки о корме, уходе, скидке, резерве и цели; реальные финансовые продукты не используются. | — |
| Правильный ответ и успешный flow | ✅ Реализовано | Все типы имеют canonical correct answer/state и success explanation. | — |
| Ошибка с объясняющим feedback | ✅ Реализовано | Day 1/2 показывают feedback по ошибочным item; choice показывает explanation. | — |
| Безопасная повторная попытка | ✅ Реализовано | Ошибка не награждает и не меняет progress; ответы можно исправить. | — |
| Игровая награда | ✅ Реализовано | Reward виден в UI и начисляется через transaction. | — |
| Награда идемпотентна | ✅ Реализовано | Durable `task_progress`; retry/concurrency/reopen tests исключают повторное начисление. | — |
| Завершение задания сохраняется | ✅ Реализовано | `task_progress` keyed by profile/task; UI перечитывает completed IDs. | — |
| Нет ожидания реального календарного времени | ✅ Реализовано | Периоды и day progress двигаются только игровыми действиями. | — |
| Перемешивание Day 1 | 🟡 Частично | Day 2 явно shuffle-ит карточки; Day 1 отображает canonical порядок из JSON, backlog признаёт отсутствие shuffle. | Перемешивать Day 1 без изменения identities и проверки ответа. |

Фактические task types на проверенном commit:

| Период | Task ID | Type | Topic |
|---:|---|---|---|
| Day 1 | `task_need_or_want_01` | `categorization` | `needs_and_wants` |
| Day 2 | `task_priority_02` | `budget_priority` | `priorities` |
| Day 3 | `task_changed_plan_03` | `choice` | `adapting_plan` |
| Day 4 | `task_discount_04` | `choice` | `discounts` |
| Day 5 | `task_final_choice_05` | `choice` | `planning` |
| Day 5 bonus | `task_bonus_reserve_05` | `choice` | `reserve` |

## 10. Последствия и обратная связь — 2.5.9

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Объяснять изменение баланса | 🟡 Частично | Текущая покупка/награда/доход объяснены, но пользовательской истории всех операций нет. | Добавить доступный журнал с source и amount. |
| Объяснять изменение накоплений | ✅ Реализовано | Deposit/claim UI показывает суммы, отдельные balances и остаток. | — |
| Объяснять состояние питомца | 🟡 Частично | Подписанные показатели, expected item effects и bedtime blockers есть; нет единой текстовой причины текущего эмоционального состояния. | Добавить краткое «почему Финни так себя чувствует» по canonical причинам. |
| Показывать причинно-следственную связь решения | ✅ Реализовано | Task explanations, item effects, plan/fact и специальные события связывают выбор с результатом. | — |
| Ошибка не уничтожает прогресс | ✅ Реализовано | Mutations transactional; UI ошибки имеют retry; неправильные task answers inert. | — |
| Путь восстановления из нехватки/ошибки | 🟡 Частично | Есть retry, переход к вещам/магазину и fallback bedtime; insufficient shop не даёт конкретной CTA. | Добавить единый recovery action для недостатка денег и проверить отсутствие dead ends вручную. |
| Нет необратимого наказания | ✅ Реализовано | Нет смерти/болезни/потери профиля; период можно завершить fallback только после расчёта недостижимости зелёной зоны. | — |

## 11. Развитие питомца — 2.5.10

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Не менее 3 стадий | ✅ Реализовано | `developmentStage` нормализован 1..3; preview визуально меняет scale/badge. | — |
| Переход Stage 1 → 2 → 3 | ✅ Реализовано | Day 2 completion переводит в Stage 2, Day 5 — Stage 3; integration test проходит 5 периодов. | — |
| Стадия сохраняется | ✅ Реализовано | Pet хранится в SQLite; migrations и persistence tests. | — |
| Развитие происходит по нескольким периодам | ✅ Реализовано | Пороговые переходы после 2-го и 5-го завершённого периода. | — |
| Развитие зависит от совокупности финансовых решений | 🟡 Частично | Для завершения дня обязательны task/savings checkpoints и уход, но сама стадия привязана к номеру завершённого дня и не оценивает качество plan/fact, регулярность накоплений или структуру трат. | Согласовать scoring/правила и связать развитие с агрегированными финансовыми решениями. |
| Пользователь понимает причину роста | 🟡 Частично | Progress screen сообщает «Финни вырос», но не объясняет, какие решения привели к росту. | Добавить evidence-based explanation роста. |
| Эмоциональное состояние имеет объяснимую причину | 🟡 Частично | Stats детерминированы действиями/decay, но UI не выводит причинный текст. | Добавить текстовую причину на Home/summary. |

## 12. История и прогресс — 2.5.11

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Список выполненных заданий | ❌ Не реализовано | Completion хранится, но отдельного пользовательского списка истории нет. | Добавить экран истории заданий. |
| Текущая цель накоплений | ✅ Реализовано | Видна на Home и Savings. | — |
| Результат последнего периода | 🟡 Частично | Summary показывается сразу после сна, но постоянного пути открыть последний завершённый период нет. | Сохранить доступ к последнему и предыдущим summaries. |
| История plan/fact по периодам | ❌ Не реализовано | Данные periods сохранены, но normal user flow списка периодов отсутствует. | Добавить список периодов и открытие каждого plan/fact. |
| Общий прогресс кампании | 🟡 Частично | Adult показывает completed days; milestone Progress показывается после Day 2/5, но детского постоянного overview нет. | Добавить доступный ребёнку экран общего прогресса. |
| Глоссарий и термины | ✅ Реализовано | 9 JSON entries, Settings → «Финансовые термины», 360dp widget test. | — |
| История доступна обычным пользовательским путём | ❌ Не реализовано | Нет постоянного History/Progress route в навигации. | Добавить точку входа и end-to-end smoke. |

## 13. Раздел «Для взрослого» — 2.5.12 и Appendix A

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Защитный барьер | ✅ Реализовано | Раздел начинается с отдельного barrier; данные до unlock не читаются. | — |
| Обычный tap не обходит barrier | ✅ Реализовано | `onTap` пустой; long press required; widget test проверяет tap. | — |
| Цель приложения | ✅ Реализовано | Карточка «О проекте». | — |
| Темы обучения | ✅ Реализовано | Список из 6 тем. | — |
| Общий прогресс | ✅ Реализовано | Completed days 0..5 и progress indicator. | — |
| Прогресс питомца и накоплений | ✅ Реализовано | Stage и saved amount читаются по active profile. | — |
| Нейтральная, неосуждающая подача | ✅ Реализовано | Экран показывает факты без оценок ребёнка; negative labels отсутствуют. | — |
| Read-only до destructive actions | ✅ Реализовано | Текущий Adult не выполняет mutations. | — |
| Reset тестового/demo-профиля | ❌ Не реализовано | Core имеет `clearDemoRuntimeData`, но DEMO-профиль не создаётся/не выбирается в UI, кнопки reset нет. | Реализовать пользовательский DEMO flow и reset только DEMO с confirmation. |
| Удаление локального NORMAL-профиля | ❌ Не реализовано | Profile delete action и UI отсутствуют. | Добавить удаление локальных данных с защитным подтверждением. |
| Подтверждение destructive actions | ❌ Не реализовано | Самих reset/delete actions в UI нет. | Добавить отдельные явные confirmations и тесты изоляции. |
| Возврат назад | ✅ Реализовано | AppBar Back возвращает pop либо Settings; widget tests покрывают reopen/barrier. | — |

## 14. Сохранение и демонстрационный режим — 2.5.13

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Профиль сохраняется локально | ✅ Реализовано | SQLite `profiles`, bootstrap восстанавливает NORMAL. | — |
| Wallet и transactions сохраняются | ✅ Реализовано | SQLite state/transactions, atomic/reopen tests. | — |
| Inventory сохраняется | ✅ Реализовано | SQLite inventory; purchase/use/restart tests. | — |
| Savings, active и completed goals сохраняются | ✅ Реализовано | `game_states` + `completed_goals`; reopen test. | — |
| Задания сохраняются | ✅ Реализовано | `task_progress`; retry after SQLite reopen test. | — |
| Периоды и plan/fact сохраняются | ✅ Реализовано | `game_periods` snapshots и transactions; migration tests v1–v9. | — |
| Питомец и стадия сохраняются | ✅ Реализовано | SQLite pets; persistence/migration tests. | — |
| Периоды последовательны и не зависят от календаря | ✅ Реализовано | `PeriodService` выбирает следующий definition; virtual progress меняется только actions. | — |
| Техническая изоляция NORMAL/DEMO | ✅ Реализовано | Все runtime rows keyed by profile; tests проверяют isolation; reset Core запрещён для NORMAL. | — |
| Готовый тестовый/demo-профиль в приложении | ❌ Не реализовано | Bootstrap намеренно выбирает только NORMAL; UI для DEMO отсутствует. | Добавить создание/выбор преднастроенного DEMO-профиля. |
| Resettable demo без влияния на NORMAL | 🟡 Частично | Безопасная repository-операция и tests есть, но нет UI и полного re-seed сценария. | Подключить reset в Adult, заново заполнить demo state и проверить NORMAL end-to-end. |
| Последовательный экспертный demo-сценарий | 🟡 Частично | Core integration проходит Day 1–5 без ожидания; README описывает 13 шагов, но готового resettable demo и ручного полного прогона нет. | Реализовать demo entry/reset и зафиксировать ручной прогон Appendix A. |

## 15. Управление контентом — 2.5.14

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Задания отделены от UI | ✅ Реализовано | `assets/content/tasks.json` загружается `AssetContentRepository`. | — |
| Товары, цели, периоды и словарь отделены от UI | ✅ Реализовано | Отдельные JSON assets и typed models. | — |
| Typed parsing и validation | ✅ Реализовано | Models отклоняют malformed/duplicate content; `content_repository_test.dart`. | — |
| Новый экземпляр поддержанного типа без переписывания Core | ✅ Реализовано | Repository загружает list, screens рендерят supported `choice/categorization/budget_priority`. | — |
| Новый тип механики без изменения Core | 🟡 Частично | Новые данные поддержанных schemas добавляются без Core rewrite; новый task type требует model/service/UI code. | Уточнить, требует ли ТЗ плагинную механику; при необходимости ввести registry/handler contract. |
| Ошибка контента имеет безопасное состояние | ✅ Реализовано | Content errors отделены от empty/runtime states; UI предлагает retry и Core не мутирует данные. | — |

## 16. Минимальный демонстрационный контент — 2.6

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| ≥9 комбинаций питомца | ✅ Реализовано | 3 цвета × 3 узора = 9. | — |
| ≥5 периодов | ✅ Реализовано | `periods.json` содержит 5 последовательных definitions. | — |
| ≥6 заданий | ✅ Реализовано | Фактически 6. | — |
| ≥3 темы заданий | ✅ Реализовано | Фактически 6 topic IDs. | — |
| ≥8 товаров | ✅ Реализовано | Фактически 12. | — |
| Товары типов needs и wants | ✅ Реализовано | Фактически 5 NEED и 7 WANT. | — |
| ≥3 целей | ✅ Реализовано | Фактически 3. | — |
| ≥3 стадий питомца | ✅ Реализовано | Фактически 3. | — |

## 17. Технические и аппаратные требования — 3.1–3.4

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 3.1 — Android 8.0+ compatibility | 🟡 Частично | `android/app/build.gradle.kts`: `minSdk = flutter.minSdkVersion`; resolved API level и установка на Android 8 не подтверждены. | Зафиксировать resolved minSdk и проверить final APK на Android 8+. |
| 3.1 — Портретная ориентация | ❌ Не реализовано | `android/app/src/main/AndroidManifest.xml` не задаёт `screenOrientation`; в `lib/main.dart` нет orientation lock. | Заблокировать portrait и проверить rotation на устройстве. |
| 3.1 — Корректность от 360dp | 🟡 Частично | 360×800 tests есть для Home/Budget, Pet Creation, Shop, Day 1/2, Glossary и Adult; полного прогона всех состояний нет. | Провести полный 360dp smoke, включая dialogs, errors, keyboard и scaling. |
| 3.1 — Проверка на физическом Android-устройстве | ❌ Не реализовано | Нет подтверждения в текущем репозитории; emulator/widget evidence не заменяет physical device. | Предоставить протокол final APK с явной пометкой physical device. |
| 3.1 — RAM физического устройства ≥3GB | ❌ Не реализовано | Нет подтверждения модели устройства и объёма RAM в текущем репозитории. | Зафиксировать модель, Android version и RAM в отчёте. |
| 3.1 — Камера не требуется | ✅ Реализовано | Main manifest не содержит CAMERA; camera package/API отсутствуют в `pubspec.yaml` и `lib/`. | — |
| 3.1 — Микрофон не требуется | ✅ Реализовано | Main manifest не содержит RECORD_AUDIO; audio-record API отсутствует. | — |
| 3.1 — Геолокация не требуется | ✅ Реализовано | Main manifest не содержит location permissions; location package/API отсутствуют. | — |
| 3.1 — Контакты не требуются | ✅ Реализовано | Main manifest не содержит READ/WRITE_CONTACTS; contacts API отсутствует. | — |
| 3.1 — Bluetooth не требуется | ✅ Реализовано | Main manifest не содержит Bluetooth permissions; Bluetooth package/API отсутствует. | — |
| 3.2 — Offline Core | ✅ Реализовано | `lib/core/database/app_database.dart`; `assets/content/`; production manifest без INTERNET. | — |
| 3.2 — Корректное поведение без сети | ✅ Реализовано | Production state/content читаются из SQLite/assets; `pubspec.yaml` не содержит HTTP/cloud SDK. | — |
| 3.2 — Flutter допускается | ✅ Реализовано | `pubspec.yaml`; Flutter Android project. | — |
| 3.2 — SQLite/local storage | ✅ Реализовано | `sqflite`; `AppDatabase` schema version 9 и migration tests. | — |
| 3.2 — Educational content отделён от UI | ✅ Реализовано | `assets/content/*.json`; `AssetContentRepository` в `lib/repositories/content_repository.dart`. | — |
| 3.2 — Server не требуется | ➖ Не требуется / вне scope | Выбран offline-only Core без backend; серверный API в архитектуре отсутствует. | — |
| 3.2 — AI не требуется | ➖ Не требуется / вне scope | AI не является частью обязательного Core и в приложении отсутствует. | — |

## 18. Сборка и готовность к RuStore — 3.3

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 3.3 — Release APK | ❌ Не реализовано | Нет подтверждения final APK в текущем репозитории; documentation-only аудит build не выполняет. | Предоставить release APK, hash, размер и воспроизводимую команду сборки. |
| 3.3 — APK подписан release key | ❌ Не реализовано | `android/app/build.gradle.kts`: release использует `signingConfigs.getByName("debug")` и содержит signing TODO. | Настроить внешний release keystore и проверить сертификат APK. |
| 3.3 — APK устанавливается без IDE | ❌ Не реализовано | Нет подтверждения clean install final APK в текущем репозитории. | Установить через системный installer/adb на чистое физическое устройство и приложить результат. |
| 3.3 — Unique package name | 🟡 Частично | `applicationId = "ru.codexteam.finny"`, но template TODO остаётся и доступность ID в RuStore не подтверждена. | Подтвердить окончательный package ID у капитана и в RuStore. |
| 3.3 — App version | ✅ Реализовано | `pubspec.yaml`: version name `1.0.0`. | — |
| 3.3 — Build number | ✅ Реализовано | `pubspec.yaml`: build number `1`; Android использует `flutter.versionCode`. | — |
| 3.3 — Возможность публикации в RuStore | ❌ Не реализовано | Debug signing и отсутствие подтверждённого APK не позволяют считать публикацию готовой. | Выполнить release signing, validation, install и проверку кабинета. |
| 3.3 — Draft card: название | 🟡 Частично | App label `Finny` есть в manifest, но нет подтверждения черновика карточки RuStore. | Предоставить/создать фактический draft app card. |
| 3.3 — Draft card: категория | ❌ Не реализовано | Нет подтверждения в текущем репозитории. | Выбрать и зафиксировать категорию в RuStore. |
| 3.3 — Draft card: краткое описание | ❌ Не реализовано | Нет подтверждения RuStore-ready short description. | Подготовить текст в лимитах площадки. |
| 3.3 — Draft card: полное описание | ❌ Не реализовано | README не является подтверждением заполненной store card. | Подготовить и согласовать полное описание. |
| 3.3 — Иконка 512×512 | ❌ Не реализовано | В текущем репозитории есть Android launcher mipmaps, но нет подтверждения фактического store icon 512×512; внешний артефакт мог быть подготовлен отдельно. | Предоставить фактический 512×512 artifact и проверить права. |
| 3.3 — Не менее 3 screenshots | ❌ Не реализовано | Нет подтверждения submission screenshots в текущем репозитории. | Сделать минимум 3 скриншота final APK на целевом устройстве. |
| 3.3 — Age-rating rationale | ❌ Не реализовано | Нет подтверждения анкеты/обоснования в текущем репозитории. | Заполнить анкету и сохранить rationale. |
| 3.3 — Права на изображения | ❌ Не реализовано | В текущем репозитории нет подтверждения происхождения launcher/visual assets; требуется фактическое ownership/license evidence, включая внешние материалы. | Предоставить ownership/license evidence. |
| 3.3 — Права на шрифты | ➖ Не требуется / вне scope | Custom font assets не подключены; используются системные Material fonts. | — |
| 3.3 — Права на звуки | ➖ Не требуется / вне scope | Sound assets и audio playback в текущем приложении отсутствуют. | — |
| 3.3 — Third-party libraries/licenses | ❌ Не реализовано | Dependencies перечислены в `pubspec.yaml`, но в текущем репозитории нет подтверждения submission-ready LICENSE/NOTICE/атрибуций. | Предоставить фактический dependency license inventory и notices. |

## 19. Надёжность, архитектура и производительность — 3.4

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 3.4 — Разделение UI / controllers / services / repositories / storage | ✅ Реализовано | `lib/features/`; `lib/services/`; `lib/repositories/`; `lib/core/database/`; `test/services/service_boundary_test.dart`. | — |
| 3.4 — Фактический код соответствует архитектурной документации | ✅ Реализовано | `docs/ARCHITECTURE.md`; providers связывают UI → services → narrow ports → SQLite/content. | — |
| 3.4 — Код и документация находятся в repository | ✅ Реализовано | Versioned production, tests, `README.md` и `docs/`. | — |
| 3.4 — Воспроизводимая сборка | 🟡 Частично | `README.md` даёт debug run/check commands, но не фиксирует tested toolchain и release signing/build procedure. | Зафиксировать Flutter/Java/Android versions и пошаговую release build. |
| 3.4 — Нет secrets/tokens/private signing keys | ✅ Реализовано | Tracked API keys/keystores/private-key files не обнаружены; release key пока не настроен. | — |
| 3.4 — Только необходимые Android permissions | ✅ Реализовано | Main manifest не содержит runtime permissions; INTERNET находится только в debug manifest. | — |
| 3.4 — Каждое permission обосновано | 🟡 Частично | Опасных permissions нет, но отдельной таблицы manifest/query/debug INTERNET rationale нет. | Добавить permissions rationale в release documentation. |
| 3.4 — Startup ≤5 секунд на physical device | ❌ Не реализовано | Нет подтверждения measurement/report в текущем репозитории. | Измерить cold start несколькими повторами на указанном physical device. |
| 3.4 — Visual response local action ≤1 секунды | ❌ Не реализовано | Нет подтверждения device measurements для budget/task/purchase/savings/navigation. | Замерить и приложить методику, значения и устройство. |
| 3.4 — Mandatory demo без crash/blocker/progress loss/dead end | 🟡 Частично | `test/services/final_campaign_integration_test.dart` проходит Core Day 1–5 по структуре, но reset/delete и physical final-APK smoke не подтверждены. | Пройти Appendix A на final APK и сохранить протокол. |
| 3.4 — Automated coverage Core logic | ✅ Реализовано | `test/services/`, `test/repositories/`, migration tests покрывают economy, periods, persistence и idempotency. | — |
| 3.4 — Миграции сохраняют runtime data | ✅ Реализовано | `test/core/database_migration_test.dart` и v3–v9 migration tests. | — |

## 20. Безопасность и приватность ребёнка — 3.5 и product constraints

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 3.5 — Нет обязательного аккаунта | ✅ Реализовано | `BootstrapController`; `ProfileType.normal`; backend/auth dependencies отсутствуют. | — |
| 3.5 — Нет персональных данных ребёнка | ✅ Реализовано | Onboarding принимает только игровое имя; phone/email/real-name fields отсутствуют. | — |
| 3.5 — Нет персональных данных родителя | ✅ Реализовано | Adult section не принимает и не отправляет данные взрослого. | — |
| 3.5 — Нет реальных платежей | ✅ Реализовано | Billing SDK/payment flow отсутствуют в `pubspec.yaml` и `lib/`. | — |
| 3.5 — Нет подписок | ✅ Реализовано | Subscription SDK/state/UI отсутствуют. | — |
| 3.5 — Нет рекламы | ✅ Реализовано | Ads SDK/placements отсутствуют. | — |
| 3.5 — Нет наград реальной стоимости | ✅ Реализовано | Rewards — только local coins/inventory в `GameState`/SQLite. | — |
| 3.5 — Нет публичного детского чата | ✅ Реализовано | Chat/messages/network identity features отсутствуют. | — |
| 3.5 — Нет социальной сети | ✅ Реализовано | Friends/feed/sharing/social graph отсутствуют. | — |
| 3.5 — Нет рейтинга детей с персональными данными | ✅ Реализовано | Leaderboard/ranking/profile publication отсутствуют. | — |
| 3.5 — Нет реальной банковской интеграции | ✅ Реализовано | Banking SDK/API и реальные счета отсутствуют. | — |
| 3.5 — Нет manipulative FOMO | ✅ Реализовано | Нет real-time deadlines/push/streaks; Day 4 discount ограничен виртуальным периодом без таймера. | — |
| 3.5 — Нет shame/fear | ✅ Реализовано | `docs/PRODUCT_SPEC.md`; task/UI feedback нейтрален и допускает retry. | — |
| 3.5 — Нет смерти/тяжёлой болезни как наказания | ✅ Реализовано | Pet stats clamp 0..100; death/illness state отсутствует; bedtime имеет recovery/fallback. | — |
| 3.5 — Данные локальны | ✅ Реализовано | `AppDatabase`; bundled assets; production INTERNET permission отсутствует. | — |
| 3.5 — Минимальные Android permissions | ✅ Реализовано | `android/app/src/main/AndroidManifest.xml` не содержит dangerous permissions. | — |
| 3.5 — Нет secrets в repository | ✅ Реализовано | Tracked secret/key patterns и private signing files не обнаружены. | — |
| 3.5 — Нет индивидуальных рекомендаций по реальным обстоятельствам | ✅ Реализовано | `assets/content/tasks.json` использует только вымышленные игровые ситуации и монеты. | — |
| 3.5 — Пользовательское удаление локальных данных | ❌ Не реализовано | Delete NORMAL action отсутствует в `AdultScreen`, Settings и `ProfileRepository`. | Добавить deletion procedure, confirmation и проверку полного удаления. |

## 21. Доступность и UX — official UX/accessibility criteria

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Portrait UX | 🟡 Частично | Layouts ориентированы на узкий экран, но ориентация не заблокирована. | Зафиксировать portrait и выполнить device QA. |
| Работа на 360dp | 🟡 Частично | Есть существенное widget coverage 360dp, но не все состояния/экраны. | Закрыть ручной матрицей все routes, dialogs и errors. |
| Короткие понятные тексты | ✅ Реализовано | Основные CTA и child-facing explanations короткие и конкретные. | — |
| Термины объяснены | ✅ Реализовано | Onboarding + 9-entry glossary. | — |
| Следующее действие понятно | 🟡 Частично | Home и errors обычно дают CTA; insufficient shop и постоянная history/progress navigation неполны. | Добавить recovery CTA и постоянные точки входа. |
| Touch targets около 48dp | 🟡 Частично | Filled buttons имеют min 48; Adult unlock 48; Material defaults помогают остальным, но системной проверки всех custom/tap targets нет. | Провести accessibility audit размеров всех интерактивных элементов. |
| Основной текст около 16sp | 🟡 Частично | Ряд child-facing текстов явно 16/18sp, но глобальный `bodyMedium` размер не задан и зависит от Material defaults. | Зафиксировать типографическую шкалу и проверить все экраны. |
| Поддержка font scaling | 🟡 Частично | Home/Budget тестируются с reasonable text scaling; нет полной проверки всех экранов и больших масштабов. | Прогнать 1.3–2.0× на целевых экранах и устранить overflow. |
| Цвет не единственный сигнал | 🟡 Частично | Checkpoints используют icon+label, stats имеют labels/semantics; системного аудита всех success/error/status элементов нет. | Проверить весь flow без различения цветов и добавить non-color cues. |
| Ошибки, успех, категории и состояния имеют non-color cues | 🟡 Частично | Task feedback использует текст, checkpoints — icon+label, но нет полного аудита Shop/Savings/Pet status и TalkBack. | Проверить каждый status/error/success/category элемент и документировать результат. |
| Semantics для ключевых элементов | 🟡 Частично | Finny image, stats, task zones и adult unlock имеют Semantics; coverage не полный. | Проверить TalkBack и добавить labels/hints для custom controls. |
| Назад работает предсказуемо | ✅ Реализовано | Router/AppBars/PopScope обрабатывают back; Adult fallback ведёт в Settings. | — |
| Destructive actions подтверждаются | ❌ Не реализовано | Reset/delete отсутствуют, поэтому подтвердить UX невозможно. | Реализовать actions с отдельным confirmation и безопасным default. |
| Scroll/overflow | 🟡 Частично | Основные длинные экраны scrollable; 360dp tests существуют, но полного набора состояний нет. | Ручной QA всех dialogs/error/keyboard/text-scale states. |

## 22. Testing evidence

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Budget logic tests | ✅ Реализовано | `test/services/core_game_loop_test.dart`; `test/home_budget_planning_test.dart`. | — |
| Purchase и insufficient-funds tests | ✅ Реализовано | `test/services/purchase_business_errors_test.dart`; `test/features/shop/shop_screen_test.dart`. | — |
| Savings tests | ✅ Реализовано | `test/features/savings/`; `test/services/core_game_loop_test.dart` savings cases. | — |
| Transactions tests | ✅ Реализовано | `test/repositories/game_repository_test.dart`: traceable wallet transaction; Core tests. | — |
| Period transitions tests | ✅ Реализовано | `test/services/day_lifecycle_test.dart`; `test/services/day_one_virtual_day_integration_test.dart`. | — |
| Task retry/idempotency tests | ✅ Реализовано | `test/services/task_completion_test.dart`; `test/services/idempotent_retry_after_completion_test.dart`. | — |
| Profile isolation tests | ✅ Реализовано | NORMAL/DEMO cases in Core, repository, task, item-use and special-purchase tests. | — |
| Persistence tests | ✅ Реализовано | SQLite reopen tests для Pet, Shop, Savings, Tasks и Core state. | — |
| Pet progression tests | ✅ Реализовано | `test/services/pet_state_test.dart`; `test/services/day_lifecycle_test.dart`. | — |
| Day 1 interactive widget/core tests | ✅ Реализовано | `test/features/tasks/day1_categorization_task_test.dart`; `test/services/task_categorization_test.dart`. | — |
| Day 2 interactive widget/core tests | ✅ Реализовано | `test/features/tasks/day2_budget_priority_task_test.dart`; `test/services/task_budget_priority_test.dart`. | — |
| Day 3–5 current choice tests | ✅ Реализовано | Choice validation/completion in `task_completion_test.dart`; full sequence in `final_campaign_integration_test.dart`. | — |
| Adult tests | ✅ Реализовано | `test/features/adult/adult_screen_test.dart`: barrier, tap, long press, progress, stale reads, 360dp. | — |
| Glossary tests | ✅ Реализовано | `test/repositories/glossary_content_test.dart`; `test/features/help/help_screen_test.dart`. | — |
| Navigation tests | ✅ Реализовано | `test/features/navigation_test.dart`; route behavior also exercised by feature widget tests. | — |
| 5-period campaign integration test | ✅ Реализовано | `test/services/final_campaign_integration_test.dart` reaches five completed periods and Stage 3. | — |
| 360dp regression tests | 🟡 Частично | Several key screens set 360×800, but not every route/dialog/error state in Appendix A. | Add a complete UI matrix or manual 360dp report. |
| Full automated suite result on audited SHA | 🟡 Частично | Tests exist, but the task explicitly excludes running full `flutter test`; no current CI status is attached to the audited commit. | Run the full suite in CI/release validation and link the result. |
| Physical-device verification | ❌ Не реализовано | No confirmation in the current repository. | Execute Appendix A on the final signed APK and provide the device report. |

## 23. Appendix A — обязательный демонстрационный сценарий

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 1. Установка и запуск с intro | 🟡 Частично | Первый запуск и intro покрыты widget test; установка final APK не подтверждена. | Проверить на чистом физическом устройстве. |
| 2. Создание локального профиля | ✅ Реализовано | Onboarding создаёт NORMAL без регистрации. | — |
| 3. Настройка питомца | ✅ Реализовано | Имя + 9 appearance combinations. | — |
| 4. Стартовый бюджет, цель и задания | ✅ Реализовано | Day start, Savings goal selection и task list доступны. | — |
| 5. Составление бюджета | ✅ Реализовано | Draft/confirm flow. | — |
| 6. Задание, награда и explanation | ✅ Реализовано | Day 1/2 и choice tasks показывают result/reward. | — |
| 7. Покупка need и want | ✅ Реализовано | Каталог содержит оба типа; purchase flow общий и проверен. | — |
| 8. Сценарий недостатка средств | 🟡 Частично | Ошибка показывает цену/баланс/дефицит, но не предлагает следующий шаг. | Добавить recovery CTA и включить в ручной smoke. |
| 9. Выбор цели и deposit | ✅ Реализовано | Полный Savings flow реализован. | — |
| 10. Feedback о последствиях | 🟡 Частично | Task, plan/fact и stat feedback есть; причинное объяснение эмоции/роста неполно. | Улучшить explanation и проверить понятность с ребёнком/экспертом. |
| 11. Следующий период и новая стадия | ✅ Реализовано | Sequential Day 1–5, Stage 2/3; integration test. | — |
| 12. Перезапуск и сохранение | ✅ Реализовано | Reopen/persistence tests для ключевых domains. | — |
| 13. Раздел взрослого | ✅ Реализовано | Long-press barrier и read-only overview. | — |
| 14. Reset/delete test profile | ❌ Не реализовано | UI reset/delete и готовый DEMO отсутствуют. | Реализовать и показать изоляцию NORMAL. |

## 24. Submission documentation

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| README: purpose | ✅ Реализовано | `README.md` описывает Finny, аудиторию, offline scope и core loop. | — |
| README: repository structure | ✅ Реализовано | `README.md` содержит mapping `assets/docs/lib/test`. | — |
| README: quick start | ✅ Реализовано | `README.md`: `flutter pub get`, `flutter run`, device selection. | — |
| Environment/tool versions | ❌ Не реализовано | Dart constraint есть в `pubspec.yaml`, но tested Flutter/Java/Gradle/Android SDK versions не зафиксированы. | Добавить воспроизводимую toolchain table. |
| Step-by-step release APK build | ❌ Не реализовано | Production signing/build/install procedure не документирована. | Описать release build без публикации keystore/secrets. |
| Functional architecture | ✅ Реализовано | `docs/ARCHITECTURE.md`; `docs/CORE_GAME_LOOP.md`. | — |
| Component architecture | ✅ Реализовано | `docs/ARCHITECTURE.md` описывает UI → controllers → services → repositories → SQLite/JSON. | — |
| Profile data structure | 🟡 Частично | `Profile`, profile-scoped SQLite schema и NORMAL/DEMO описаны, но отдельной сдаваемой data dictionary нет. | Добавить fields, ownership, lifecycle и deletion behavior. |
| Economy data structure | 🟡 Частично | Wallet/savings/transactions/period aggregates описаны в Core docs и schema, но нет единой data dictionary. | Добавить entities, fields, invariants и source taxonomy. |
| Tasks data structure | 🟡 Частично | Typed models и JSON schemas подтверждены кодом/tests; формальная таблица всех task fields/types отсутствует. | Добавить schema и supported-type boundaries. |
| Progress data structure | 🟡 Частично | Period/Pet/task progress описаны в Core docs; единой submission-схемы нет. | Добавить relation map periods/checkpoints/tasks/Pet stages. |
| Requirement matrix | ✅ Реализовано | `docs/REQUIREMENTS_MATRIX.md`. | — |
| Balance/reward/pet-growth formulas and rules | ✅ Реализовано | `docs/CORE_GAME_LOOP.md`; `PetStateRules`; `VirtualDayRules`. | — |
| Educational content map: theme | 🟡 Частично | `tasks.json` содержит `topic`, но нет полной human-readable карты. | Добавить строку на каждое задание. |
| Educational content map: expected skill | ❌ Не реализовано | Skills можно вывести из текста, но в текущем репозитории нет подтверждения фактической submission map. | Зафиксировать ожидаемый навык по каждому сценарию. |
| Educational content map: scenario | 🟡 Частично | Prompt/scenarioData есть в `tasks.json`; сводного документа нет. | Добавить компактную content map. |
| Educational content map: correct logic | 🟡 Частично | Canonical answers находятся в JSON/Core; сводного объяснения для экспертов нет. | Описать correct logic без раскрытия лишнего в child UI. |
| Educational content map: child explanation | 🟡 Частично | Feedback/successExplanation есть в JSON; submission map отсутствует. | Собрать explanations в content map. |
| UX/UI rationale | ❌ Не реализовано | Нет подтверждения отдельного rationale document в текущем репозитории. | Подготовить обоснование Home/navigation/task/pet feedback решений. |
| Accessibility settings/rationale | ❌ Не реализовано | Код содержит отдельные Semantics/360dp tests, но в текущем репозитории нет подтверждения фактического accessibility document. | Предоставить документ с targets, scaling, non-color cues и TalkBack checks. |
| Android permissions description | ❌ Не реализовано | Manifest можно проверить, но в текущем репозитории нет подтверждения submission-ready permission table. | Предоставить описание main/debug permissions и queries rationale. |
| Data collected description | ❌ Не реализовано | Local data видны из schema, но в текущем репозитории нет подтверждения фактического privacy/data inventory artifact. | Предоставить описание game name, local state, отсутствия network collection и retention. |
| Profile deletion procedure | ❌ Не реализовано | Delete UI/operation отсутствует, поэтому procedure документировать пока нельзя. | Реализовать delete и описать путь/последствия. |
| Test cases | 🟡 Частично | Automated tests присутствуют, но в текущем репозитории нет подтверждения фактического expert checklist с expected results. | Предоставить acceptance test cases, включая Appendix A. |
| Physical-device report | ❌ Не реализовано | Нет подтверждения в текущем репозитории. | Предоставить device/OS/RAM/build/timing/result report. |
| Known limitations | ✅ Реализовано | `README.md` backlog и Known gaps этой матрицы. | — |
| Future plan | ✅ Реализовано | `README.md` backlog и P1/P2 этой матрицы. | — |
| Third-party libraries/licenses | ❌ Не реализовано | Dependency list есть, но в текущем репозитории нет подтверждения фактического license inventory/NOTICE. | Предоставить license report. |
| Fonts/images/sounds licenses | ❌ Не реализовано | Custom fonts/sounds отсутствуют, но provenance launcher/visual assets и consolidated rights statement не подтверждены. | Подготовить rights statement с N/A для отсутствующих типов. |

## 25. Presentation and demo materials

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Final presentation artifact | ❌ Не реализовано | Нет подтверждения готового PPTX/PDF/deck в текущем репозитории; template сам по себе не считался бы готовым. | Предоставить финальный deck. |
| Problem + target audience | 🟡 Частично | Материал есть в `README.md` и `docs/PRODUCT_SPEC.md`, но presentation artifact не подтверждён. | Перенести в финальный deck. |
| Educational outcomes | 🟡 Частично | Outcomes видны в tasks/Adult/Product Spec, но не собраны в презентацию. | Добавить измеримые learning outcomes. |
| Product idea | 🟡 Частично | Core idea описана в README, но presentation slide не подтверждён. | Оформить короткий value proposition. |
| Why pet mechanic teaches skills | 🟡 Частично | Product docs связывают заботу и решения, но текущий stage rule не зависит от качества финансовых решений полностью. | Честно показать механику и ограничение. |
| User flow | 🟡 Частично | README demo flow и Appendix A matrix существуют; визуальная схема в deck не подтверждена. | Добавить последовательный user-flow slide. |
| Economy diagram | ❌ Не реализовано | Нет подтверждения готовой диаграммы для presentation. | Визуализировать income → budget → spend/save → plan/fact. |
| Required functionality + MVP boundaries | 🟡 Частично | Boundaries есть в Product Spec/README/matrix; presentation artifact отсутствует. | Добавить scope slide. |
| UX/UI | ❌ Не реализовано | Нет подтверждения presentation screens/UX rationale. | Добавить ключевые screenshots после final device QA. |
| Architecture/stack/storage/content updates | 🟡 Частично | `docs/ARCHITECTURE.md` готов, но presentation slide не подтверждён. | Сделать 1–2 слайда без лишней внутренней детализации. |
| Testing results | ❌ Не реализовано | Tests существуют, но presentation-ready results и physical evidence не подтверждены. | Добавить автоматизированные и device results с датой/SHA. |
| Limitations | 🟡 Частично | Ограничения зафиксированы в README и matrix, но не в deck. | Добавить честный limitations slide. |
| Next steps | 🟡 Частично | P0/P1/P2 сформированы, presentation roadmap не подтверждён. | Добавить приоритетный next-steps slide. |
| Links to repo/build/docs | ❌ Не реализовано | В текущем репозитории нет подтверждения фактической presentation с проверенными ссылками; deck мог быть подготовлен отдельно. | Добавить ссылки/QR в финальный deck и предоставить доступ. |
| Backup demo video ≤3 min | ❌ Не реализовано | Нет подтверждения video/link в текущем репозитории. | Записать final APK flow, уложиться в 3 минуты и проверить доступ. |

## 26. Final submission artifacts

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Expert-accessible repository | 🟡 Частично | GitHub repository/PR доступны текущему подключению, но доступ экспертов не подтверждён. | Проверить public/invite permissions внешней учётной записью. |
| Final release tag | ❌ Не реализовано | Нет подтверждения final tag/release для audited state. | Создать только после принятия release candidate. |
| Complete unobfuscated source | ✅ Реализовано | Repository содержит Flutter/Dart source, content, tests и docs; source-obfuscation artifact не используется. | — |
| Signed release APK | ❌ Не реализовано | Нет подтверждения artifact; release config использует debug key. | Собрать, подписать release key, проверить certificate/hash/install. |
| Install/run instructions | 🟡 Частично | Debug quick start есть в README; final APK install steps отсутствуют. | Добавить final artifact URL/hash и пошаговую установку. |
| Demo-mode instructions | ❌ Не реализовано | Полноценного UI DEMO mode нет. | Реализовать demo flow и документировать вход/прохождение. |
| Profile/test-data reset instructions | ❌ Не реализовано | UI reset/delete отсутствуют. | Реализовать и документировать безопасный reset/delete. |
| Complete submission documentation | 🟡 Частично | Architecture/Core/Product Spec/matrix есть; обязательные release/privacy/accessibility/license/device документы неполны. | Закрыть строки раздела 24. |
| Final presentation | ❌ Не реализовано | Нет подтверждения artifact в текущем репозитории. | Предоставить проверенный PPTX/PDF/link. |
| Backup video ≤3 min | ❌ Не реализовано | Нет подтверждения artifact/link. | Записать final APK и проверить доступ экспертов. |
| RuStore draft materials | ❌ Не реализовано | Нет подтверждения полного draft card package. | Подготовить metadata, icon, screenshots и rating rationale. |
| At least 3 screenshots | ❌ Не реализовано | Нет подтверждения submission screenshots. | Предоставить минимум 3 изображения final UI. |
| Icon 512×512 | ❌ Не реализовано | Отдельный store icon 512×512 не подтверждён. | Подготовить и проверить права/качество. |
| Age-rating rationale | ❌ Не реализовано | Нет подтверждения анкеты/rationale. | Заполнить и приложить. |
| Licenses and rights package | ❌ Не реализовано | LICENSE/NOTICE/dependency inventory/asset provenance не подтверждены. | Предоставить consolidated package. |
| Backend/OpenAPI | ➖ Не требуется / вне scope | Backend отсутствует и для offline Core не требуется. | — |

## Known gaps

1. Day 3–5 используют `choice`; только Day 1 (`categorization`) и Day 2
   (`budget_priority`) имеют отдельные интерактивные task-механики.
2. В Adult нет reset/delete, а технический `clearDemoRuntimeData` недоступен
   пользователю.
3. DEMO type и изоляция существуют в Core, но нет готового demo-профиля,
   входа, reset/re-seed и полного экспертного сценария в UI.
4. Карточки Day 1 не перемешиваются.
5. Игрушки применяют прямой stat-effect при отдельном use; самостоятельных
   игровых взаимодействий/minigames нет.
6. Нет постоянной истории заданий и периодов; последний Period Summary нельзя
   штатно открыть позднее.
7. Рост Stage 2/3 привязан к Day 2/5, а не к оценке совокупных финансовых
   решений.
8. Нет пользовательской истории transactions и полного объяснения причин
   эмоционального состояния/роста питомца.
9. Portrait lock и явное подтверждение Android 8+ отсутствуют.
10. Release подписывается debug key; в текущем репозитории не подтверждены
    signed APK, install evidence, RuStore metadata/screenshots/rating, лицензии,
    финальный deck и demo-video.
11. В текущем репозитории не подтверждены измерения cold start/response time и
    полный ручной прогон на физическом Android-устройстве.

## Remaining blockers before submission

### P0 — обязательно до сдачи

1. Закрыть буквальное требование Home: показать конкретное активное задание и
   обеспечить понятный постоянный доступ к progress/adult flow.
2. Доработать обязательную feedback-механику: объяснить pet impact до покупки,
   дать следующий шаг при insufficient funds и причину изменения состояния Pet.
3. Связать развитие Stage 1→2→3 с совокупностью финансовых решений —
   обязательными расходами, plan/fact и регулярностью накоплений — либо получить
   документированное решение заказчика о допустимой трактовке.
4. Реализовать доступный из Adult reset DEMO и delete NORMAL с отдельными
   подтверждениями; гарантировать и проверить изоляцию NORMAL.
5. Добавить готовый resettable DEMO-профиль и пройти все 14 шагов Appendix A.
6. Зафиксировать portrait и проверить совместимость Android 8+ на реальном
   устройстве.
7. Настроить production release signing, собрать signed APK, проверить чистую
   установку и зафиксировать hash.
8. Провести физический smoke/performance: cold start ≤5 секунд, локальные
   действия ≤1 секунды, без crash/blocker/data loss/dead end.
9. Предоставить обязательный submission package: expert access, final tag,
   release/install/demo/reset documentation, RuStore card, ≥3 screenshots,
   512×512 icon, age-rating rationale, licenses, presentation и backup video.

### P1 — желательно до сдачи

1. Заменить Day 3–5 `choice` на более разнообразные интерактивные механики.
2. Добавить историю заданий/периодов/plan-fact и журнал объяснимых операций.
3. Закрыть accessibility QA: 360dp, font scaling, TalkBack, touch targets,
   non-color cues и все error/dialog states.
4. Довести data dictionaries, educational content map, privacy/permissions и
   formal test cases до submission-ready вида.

### P2 — polish / bonus

1. Перемешивать карточки Day 1.
2. Добавить повторный просмотр первоначального обучения и повторную настройку
   внешности питомца.
3. Заменить прямой эффект игрушек на игровые взаимодействия/minigames.

## Questions requiring captain/customer decision

1. Должен ли NORMAL-профиль удаляться целиком, либо достаточно очищать только
   игровой прогресс? Для DEMO в ТЗ требуется отдельный безопасный reset.
2. Какой конкретно DEMO state нужен после reset: новый профиль до onboarding,
   профиль перед Day 1 или набор контрольных точек для быстрого показа?
3. Какая формула связывает рост Финни с качеством финансовых решений: доля
   обязательных расходов, соблюдение plan/fact, регулярность накоплений, reserve
   или их взвешенная комбинация?
4. Считает ли заказчик текущий Home соответствующим буквальному требованию об
   одновременном отображении active task и доступе к progress, либо нужны новые
   элементы Home?
5. Кто владеет release keystore, package ID `ru.codexteam.finny`, RuStore
   кабинетом, возрастной анкетой и доказательствами прав на контент?
6. Какое физическое устройство является приёмочным (модель, Android, RAM), и
   кто подписывает протокол производительности/стабильности?
7. Существуют ли вне repository уже подготовленные presentation, screenshots,
   APK, video, RuStore draft или license evidence, и где эксперты получат к ним
   доступ?

## Контрольные замечания по трактовке статусов

- Day 1 учтён как `categorization`, Day 2 как `budget_priority`, Day 3–5 как
  `choice`; наличие специальных purchase dialogs не меняет тип задания.
- Core-метод очистки DEMO не означает реализованный reset, пока нет UI,
  подтверждения и повторного заполнения demo state.
- Возможность пройти периоды подряд без ожидания не означает готовый demo mode.
- 360dp widget tests и эмулятор не подтверждают физическое устройство.
- `signingConfig = debug` не является release signing.
- README использован только как указатель на ограничения и инструкции; статусы
  реализации подтверждены кодом, контентом и тестами.
- Каждый частичный или отсутствующий пункт содержит конкретную оставшуюся работу;
  P0 ограничен тем, что действительно блокирует обязательный demo или release.

## Status counts

Считаются только строки основных matrix-таблиц со статусом, без headings,
легенды, task inventory и этого блока.

- ✅ 191
- 🟡 63
- ❌ 58
- ➖ 6
- **Всего:** 318
