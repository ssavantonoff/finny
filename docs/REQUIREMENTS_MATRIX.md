# Finny — Requirements Matrix

## Область и метод проверки

**Дата проверки:** 22 сентября 2026 года

**Base commit SHA:** `dc2e62981560bccf876b40ff0775f919aa6461ab`

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

### Классификация источника и этапа

Строки этой матрицы — атомизированные audit checks. Они включают буквальные
требования, способы их реализации, внутренние проверки качества и артефакты
сдачи. Для спорных пунктов и remaining work используются компактные метки:

| Метка | Source / origin |
|---|---|
| `[O]` | Official ТЗ / Q&A — прямо следует из официального требования или официального уточнения. |
| `[D]` | Accepted product decision — выбранный командой способ реализации, который не выдаётся за буквальную формулировку ТЗ. |
| `[Q]` | Internal quality / recommendation — QA, UX improvement, engineering recommendation или polish. |
| `[A]` | Final release / submission artifact — артефакт конкретного этапа сдачи или релиза. |

| Метка | Stage remaining work |
|---|---|
| `[I29]` | Interim 29 Sep — блокирует подтверждённый промежуточный пакет 29 сентября 2026 года. |
| `[F]` | Final — относится к финальной сдаче или RuStore. |
| `[Opt]` | Optional / polish — улучшение, не объявленное обязательным требованием. |
| `[Clarify]` | Needs customer clarification — источник, буквальная граница или этап не подтверждены. |

Чтобы не повторять метки во всех 318 строках, действуют defaults: разделы
1–20 и Appendix A используют `[O][I29]`; спорные способы реализации в них имеют
явный override `[D]`, `[Q]` или `[Clarify]`. Разделы 21–22 используют
`[Q][Opt]`, если строка не является прямой проверкой official criterion.
Разделы 24–26 используют `[A][F]`. Эти defaults классифицируют audit work, но
не превращают его в дополнительные официальные требования.

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
| Budget / plan-fact | `lib/features/budget/budget_screen.dart`, `lib/features/budget/budget_controller.dart`, `lib/services/budget_service.dart`, `lib/repositories/game_repository.dart` | `test/home_budget_planning_test.dart`, `test/services/core_game_loop_test.dart`, `test/features/period_summary_screen_test.dart` |
| Shop / inventory / item effects | `lib/features/shop/shop_screen.dart`, `lib/services/purchase_service.dart`, `lib/services/item_use_service.dart` | `test/features/shop/shop_screen_test.dart`, `test/services/shop_catalog_purchase_test.dart`, `test/services/item_use_test.dart` |
| Savings / goals | `lib/features/savings/savings_screen.dart`, `lib/services/savings_service.dart`, `assets/content/goals.json` | `test/features/savings/savings_core_test.dart`, `test/features/savings/savings_screen_test.dart`, `test/features/savings/savings_controller_test.dart` |
| Tasks / rewards | `lib/features/tasks/tasks_screen.dart`, `lib/features/tasks/budget_priority_task_screen.dart`, `lib/features/tasks/plan_adaptation_task_screen.dart`, `lib/services/task_service.dart` и `assets/content/tasks.json` | `test/features/tasks/day1_categorization_task_test.dart`, `test/features/tasks/day2_budget_priority_task_test.dart`, `test/features/tasks/day3_plan_adaptation_task_test.dart`, `test/services/task_categorization_test.dart`, `test/services/task_plan_adaptation_test.dart` |
| Period / day lifecycle / Pet state | `lib/services/period_service.dart`, `lib/services/day_lifecycle_service.dart`, `lib/models/pet_state_rules.dart` | `test/services/day_lifecycle_test.dart`, `test/services/pet_state_test.dart`, `test/services/final_campaign_integration_test.dart` |
| Story events | `assets/content/story_purchases.json`, `lib/features/home/campaign_event_controller.dart`, `lib/services/story_event_service.dart`, `lib/repositories/game_repository.dart` | `test/services/story_event_test.dart`, `test/features/home/campaign_event_controller_test.dart`, `test/features/home/campaign_event_dialog_test.dart` |
| Summary / progress / Adult | `lib/features/period_summary/period_summary_screen.dart`, `lib/features/progress/progress_screen.dart`, `lib/features/adult/adult_screen.dart`, `lib/repositories/profile_data_management_repository.dart` | `test/features/period_summary_screen_test.dart`, `test/features/adult/adult_screen_test.dart`, `test/repositories/profile_data_management_test.dart`, `test/app/adult_data_management_bootstrap_test.dart` |
| Persistence / migrations | `lib/core/database/app_database.dart`, `lib/repositories/game_repository.dart`, `lib/repositories/profile_repository.dart` | `test/repositories/game_repository_test.dart`, `test/core/database_migration_test.dart`, `test/core/database_v9_migration_test.dart` |
| Android / release configuration | `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml` | Статическая проверка конфигурации; физический install/smoke отмечен отдельно и не подменяется тестами. |

## Сводка

| Статус | Количество |
|---|---:|
| ✅ | 197 |
| 🟡 | 66 |
| ❌ | 48 |
| ➖ | 7 |
| **Всего атомизированных audit checks** | **318** |

**Предупреждение:** 318 — это не 318 независимых официальных требований.
Матрица атомизирует составные требования, технические доказательства,
QA-проверки и submission artifacts. Поэтому числа ✅ / 🟡 / ❌ / ➖ нужны для
tracking и не являются процентом выполнения официального ТЗ.

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
| Возврат к справке после первого запуска | 🟡 Частично | Settings открывает глоссарий, но граница официального требования к повторной справке не подтверждена; полного replay onboarding нет. | `[O][Clarify]` Уточнить требуемый объём help. `[Q][Opt]` Replay полного onboarding — один из возможных способов, а не самостоятельное official requirement. |
| Ошибка сохранения не теряет введённое имя | ✅ Реализовано | Retry сохраняет текст; покрыто `test/app/bootstrap_test.dart`. | — |

## 3. Создание питомца — 2.5.2

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Имя питомца | ✅ Реализовано | Pet Creation требует имя длиной 1–20 символов. | — |
| Настройка внешности | ✅ Реализовано | Выбираются цвет и узор, preview обновляется до сохранения. | — |
| Не менее 9 визуально различимых комбинаций | ✅ Реализовано | 3 цвета × 3 узора в `PetCreationDraft`; `FinnyPreview` визуально различает их; тест проверяет списки вариантов. | — |
| Сохранение питомца и внешности после перезапуска | ✅ Реализовано | Pet хранится в SQLite; `test/pet_creation_persistence_test.dart` проверяет восстановление. | — |
| Повторная настройка внешности после создания | ➖ Не требуется / вне scope | Production-маршрута редактирования питомца после создания нет; прямой official source обязательности этой функции не подтверждён. | `[Q][Opt]` Добавить повторную customization только как согласованный polish. |

## 4. Главный экран — 2.5.3

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Питомец виден на Home | ✅ Реализовано | `HomeScreen` отображает `FinnyPreview` и имя питомца. | — |
| Доступный баланс виден на Home | ✅ Реализовано | `home-wallet` показывает persisted `walletBalance`. | — |
| Накопления и текущая цель видны на Home | ✅ Реализовано | Карточка `home-savings-goal` показывает имя цели и saved/price. | — |
| Показатели питомца видны и понятны | ✅ Реализовано | Сытость, уход и настроение имеют подписи, progress bars и semantic values. | — |
| Активное финансовое задание видно на Home | 🟡 Частично | Home показывает checkpoint «Задание» и его выполнение, но не идентифицирует конкретное активное задание. | `[O][I29]` Обеспечить видимость активного задания. `[D][Clarify]` Название и отдельная CTA — предложенный способ закрытия, а не единственно допустимая official implementation. |
| Обязательные Home-данные доступны без сложной навигации | 🟡 Частично | `HomeScreen` одновременно показывает Pet, wallet, stats и при active goal — savings/goal; task представлен только общим checkpoint. | `[O][I29]` Подтвердить буквальный Home outcome. `[Q][Opt]` Проверить полный state на 360dp и улучшить компоновку при необходимости. |
| Доступ к бюджету | ✅ Реализовано | Планирование и просмотр plan доступны с Home через `/budget`. | — |
| Доступ к задачам, магазину и накоплениям | ✅ Реализовано | Постоянная нижняя навигация содержит «Магазин», «Задания», «Накопления». | — |
| Доступ к прогрессу и разделу взрослого | 🟡 Частично | Adult доступен через Settings; Progress открывается после Day 2/5 и не имеет постоянной точки входа. | `[O][I29]` Обеспечить требуемый доступ к progress/Adult. `[D][Clarify]` Постоянный отдельный пункт навигации — выбранный способ, если его подтвердит команда. |
| Главная показывает следующий понятный шаг | ✅ Реализовано | Состояния planning/active/ready показывают CTA и карточку статуса дня; блокирующие диалоги предлагают вернуться, открыть вещи/магазин или завершить допустимым fallback. | — |

## 5. Игровая валюта и доход — 2.5.4

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Только игровая валюта | ✅ Реализовано | Экономика использует целые игровые монеты; платежных SDK и реальных валют нет. | — |
| Базовый доход в каждом периоде | ✅ Реализовано | Все 5 definitions имеют `baseIncome: 500`; старт периода атомарно начисляет доход. | — |
| Награды за задания | ✅ Реализовано | 6 заданий имеют rewards; Task completion атомарно пишет reward transaction. | — |
| Пользователь видит сумму начисления | 🟡 Частично | Task success показывает `+N монет`, а Day 1 явно показывает базовый доход; при старте Day 2–5 сумма нового базового дохода отдельно не объясняется. | Показывать сумму базового дохода при старте каждого периода. |
| Пользователь видит источник каждого начисления | 🟡 Частично | Источник хранится в transactions, а task/day UI объясняет текущие начисления; полнота объяснения всех начислений пользовательским flow не подтверждена. | `[O][I29]` Закрыть буквальный outcome объяснимости источника. `[Q][Opt]` Полный transaction journal — рекомендуемый способ, а не отдельное official requirement. |
| Каждое изменение wallet имеет persisted transaction/source | ✅ Реализовано | SQLite transactions и service boundaries покрыты repository/service tests; plan не меняет деньги. | — |
| Нет необъяснимого изменения баланса | ✅ Реализовано | Денежные mutations атомарны, canonical и идемпотентны; `test/services/core_game_loop_test.dart` и purchase/savings tests проверяют журнал. | — |

## 6. Планирование бюджета — 2.5.5

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Категории «Нужно / Хочется / Накопления» | ✅ Реализовано | Три отдельных редактора в `BudgetScreen`. | — |
| Сумма распределения не превышает бюджет | ✅ Реализовано | UI ограничивает maximum; Core отклоняет отрицательные значения и превышение. | — |
| Остаток показан до подтверждения | ✅ Реализовано | `budget-remainder` пересчитывается от `startingBudget`. | — |
| План можно менять до подтверждения | ✅ Реализовано | Draft сохраняется и редактируется в planning. | — |
| Подтверждение плана требует явного действия | ✅ Реализовано | Перед confirm показывается bottom sheet с тремя суммами и остатком; UI и repository требуют минимум 10 в каждой категории, но допускают положительный remainder. Это `[D]` game-validation rule, а не финансовый совет. | — |
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
| Сообщение предлагает следующий вариант действия | 🟡 Частично | Дефицит посчитан, но сообщение не предлагает вариант восстановления. | `[O][I29]` Дать понятный следующий шаг, если это буквальный feedback outcome. `[Q][Opt]` Конкретная recovery CTA/формулировка — UX-рекомендация. |
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
| Смысловое покрытие планирования бюджета | ✅ Реализовано | Day 2 `budget_priority`, Day 3 `plan_adaptation` и Day 5 `planning` в `assets/content/tasks.json`. | — |
| Смысловое покрытие сбережений | ✅ Реализовано | Day 5 bonus `reserve`; обязательный savings decision встроен в каждый period. | — |
| Смысловое покрытие платежей/покупок | ✅ Реализовано | Day 1 needs/wants, Day 2 purchases, Day 3 unexpected NEED и Day 4 discount. | — |
| Day 1 — categorization | ✅ Реализовано | Typed `categorization`, 6 карточек, drag и tap fallback, исправление и item feedback. | — |
| Day 2 — budget_priority | ✅ Реализовано | Typed budget 150, buy now/later, over-budget feedback и canonical validation. | — |
| Day 3–5 — разнообразные интерактивные механики | 🟡 Частично | Day 3 реализован отдельным `plan_adaptation` с drag/tap assignment и canonical validation; Day 4 и два задания Day 5 остаются `choice`. Day 3 bowl event усиливает changed-circumstance flow, но не заменяет task mechanics Day 4–5. | При необходимости развить Day 4–5 за пределы `choice`, сохранив Core guarantees. |
| Возрастная понятность | ✅ Реализовано | Короткие формулировки о корме, уходе, скидке, резерве и цели; реальные финансовые продукты не используются. | — |
| Правильный ответ и успешный flow | ✅ Реализовано | Все типы, включая Day 3 `plan_adaptation`, имеют canonical correct answer/state и success explanation. | — |
| Ошибка с объясняющим feedback | ✅ Реализовано | Day 1/2 и Day 3 показывают feedback по ошибочным item; `choice` показывает explanation. | — |
| Безопасная повторная попытка | ✅ Реализовано | Ошибка не награждает и не меняет progress; ответы можно исправить. | — |
| Игровая награда | ✅ Реализовано | Reward виден в UI и начисляется через transaction. | — |
| Награда идемпотентна | ✅ Реализовано | Durable `task_progress`; retry/concurrency/reopen tests исключают повторное начисление. | — |
| Завершение задания сохраняется | ✅ Реализовано | `task_progress` keyed by profile/task; UI перечитывает completed IDs. | — |
| Нет ожидания реального календарного времени | ✅ Реализовано | Периоды и day progress двигаются только игровыми действиями. | — |
| Перемешивание Day 1 | ✅ Реализовано | `[Q][Opt]` Каждый новый `CategorizationTaskScreen` создаёт shuffled display order и поворачивает совпавший canonical order; порядок стабилен в instance, а canonical validation использует item identity. | — |

Фактические task types на проверенном commit:

| Период | Task ID | Type | Topic |
|---:|---|---|---|
| Day 1 | `task_need_or_want_01` | `categorization` | `needs_and_wants` |
| Day 2 | `task_priority_02` | `budget_priority` | `priorities` |
| Day 3 | `task_changed_plan_03` | `plan_adaptation` | `adapting_plan` |
| Day 4 | `task_discount_04` | `choice` | `discounts` |
| Day 5 | `task_final_choice_05` | `choice` | `planning` |
| Day 5 bonus | `task_bonus_reserve_05` | `choice` | `reserve` |

## 10. Последствия и обратная связь — 2.5.9

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Объяснять изменение баланса | 🟡 Частично | Текущая покупка/награда/доход объяснены в момент действия; постоянная история всех операций отсутствует. | `[O][I29]` Проверить объяснение каждого обязательного изменения. `[Q][Opt]` Полный журнал с source/amount — улучшение explainability. |
| Объяснять изменение накоплений | ✅ Реализовано | Deposit/claim UI показывает суммы, отдельные balances и остаток. | — |
| Объяснять состояние питомца | 🟡 Частично | Подписанные показатели, expected item effects и bedtime blockers есть; нет единой текстовой причины текущего эмоционального состояния. | Добавить краткое «почему Финни так себя чувствует» по canonical причинам. |
| Показывать причинно-следственную связь решения | ✅ Реализовано | Task explanations, item effects, plan/fact и специальные события связывают выбор с результатом. | — |
| Ошибка не уничтожает прогресс | ✅ Реализовано | Mutations transactional; UI ошибки имеют retry; неправильные task answers inert. | — |
| Путь восстановления из нехватки/ошибки | 🟡 Частично | Есть retry, переход к вещам/магазину и fallback bedtime; insufficient shop объясняет дефицит, но следующий шаг не формализован. | `[O][I29]` Исключить dead end. `[Q][Opt]` Единая recovery CTA — рекомендуемый UX-способ. |
| Нет необратимого наказания | ✅ Реализовано | Нет смерти/болезни/потери профиля; период можно завершить fallback только после расчёта недостижимости зелёной зоны. | — |

## 11. Развитие питомца — 2.5.10

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Не менее 3 стадий | ✅ Реализовано | `developmentStage` нормализован 1..3; preview визуально меняет scale/badge. | — |
| Переход Stage 1 → 2 → 3 | ✅ Реализовано | Day 2 completion переводит в Stage 2, Day 5 — Stage 3; integration test проходит 5 периодов. | — |
| Стадия сохраняется | ✅ Реализовано | Pet хранится в SQLite; migrations и persistence tests. | — |
| Развитие происходит по нескольким периодам | ✅ Реализовано | Пороговые переходы после 2-го и 5-го завершённого периода. | — |
| Развитие связано с финансовыми решениями/прогрессом | 🟡 Частично | Для завершения дня обязательны task/savings checkpoints и уход, но Stage 2/3 непосредственно привязаны к Day 2/5. Буквальная достаточность этой связи не подтверждена. | `[O][Clarify]` Подтвердить требуемую силу связи. `[D][Clarify]` Конкретная формула plan/fact + savings + mandatory expenses является product decision, а не текстом official requirement. |
| Пользователь понимает причину роста | 🟡 Частично | Progress screen сообщает «Финни вырос», но не объясняет, какие решения привели к росту. | Добавить evidence-based explanation роста. |
| Эмоциональное состояние имеет объяснимую причину | 🟡 Частично | Stats детерминированы действиями/decay, но UI не выводит причинный текст. | Добавить текстовую причину на Home/summary. |

## 12. История и прогресс — 2.5.11

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Список выполненных заданий | ❌ Не реализовано | Completion хранится, но отдельного пользовательского списка, если он требуется буквально, нет. | `[O][Clarify]` Подтвердить буквальный объём history; затем реализовать минимально достаточное отображение. |
| Текущая цель накоплений | ✅ Реализовано | Видна на Home и Savings. | — |
| Результат последнего периода | 🟡 Частично | Summary показывается сразу после сна; постоянного пути открыть его позднее нет. | `[O][Clarify]` Уточнить, требуется ли повторный доступ. `[Q][Opt]` Архив всех summaries — расширенная history. |
| История plan/fact по периодам | ❌ Не реализовано | Данные periods сохранены, но normal user flow списка периодов отсутствует. | `[O][Clarify]` Подтвердить буквальную глубину истории. `[Q][Opt]` Полный архив всех plan/fact — расширенный вариант. |
| Общий прогресс кампании | 🟡 Частично | Adult показывает completed days; milestone Progress показывается после Day 2/5, но детского постоянного overview нет. | Добавить доступный ребёнку экран общего прогресса. |
| Глоссарий и термины | ✅ Реализовано | 9 JSON entries, Settings → «Финансовые термины», 360dp widget test. | — |
| История доступна обычным пользовательским путём | ❌ Не реализовано | Нет постоянного History/Progress route в навигации. | `[O][Clarify]` Подтвердить требуемую доступность. `[D][Clarify]` Отдельный постоянный route — один из способов реализации. |

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
| Управление данными доступно только после Adult barrier | ✅ Реализовано | Актуальный `origin/main`: reset/delete находятся внутри разблокированного `AdultScreen`; до barrier mutations недоступны. | — |
| Reset игрового прогресса NORMAL | ✅ Реализовано | `[D]` Принятый командой slice реализован в `SqliteProfileDataManagement.resetNormalProfile`: профиль, имя и внешность Finny сохраняются, runtime progress очищается и восстанавливается canonical start; repository/UI/bootstrap tests это проверяют. | — |
| Полное удаление локального NORMAL-профиля | ✅ Реализовано | `[D]` `deleteNormalProfile` удаляет NORMAL profile с cascade данных; Adult UI очищает active profile и возвращает к startup. | — |
| Подтверждение destructive actions | ✅ Реализовано | `AdultScreen` использует отдельные dialogs: reset перечисляет удаляемые данные и сохраняемую identity/Finny; delete предупреждает о необратимости. | — |
| Возврат назад | ✅ Реализовано | AppBar Back возвращает pop либо Settings; widget tests покрывают reopen/barrier. | — |

## 14. Сохранение и демонстрационный режим — 2.5.13

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Профиль сохраняется локально | ✅ Реализовано | SQLite `profiles`, bootstrap восстанавливает NORMAL. | — |
| Wallet и transactions сохраняются | ✅ Реализовано | SQLite state/transactions, atomic/reopen tests. | — |
| Inventory сохраняется | ✅ Реализовано | SQLite inventory; purchase/use/restart tests. | — |
| Savings, active и completed goals сохраняются | ✅ Реализовано | `game_states` + `completed_goals`; reopen test. | — |
| Задания сохраняются | ✅ Реализовано | `task_progress`; retry after SQLite reopen test. | — |
| Периоды и plan/fact сохраняются | ✅ Реализовано | `game_periods` snapshots и transactions; migration tests v1–v10. | — |
| Питомец и стадия сохраняются | ✅ Реализовано | SQLite pets; persistence/migration tests. | — |
| Периоды последовательны и не зависят от календаря | ✅ Реализовано | `PeriodService` выбирает следующий definition; virtual progress меняется только actions. | — |
| Техническая изоляция NORMAL/DEMO | ✅ Реализовано | Все runtime rows keyed by profile; tests проверяют isolation. Отдельные repositories ограничивают NORMAL data management и DEMO cleanup соответствующим profile type. | — |
| Готовый пользовательский DEMO-профиль | ❌ Не реализовано | Технический `ProfileType.demo` существует, но bootstrap выбирает NORMAL и пользовательского DEMO entry нет. Прямой source обязательности именно такого UI не подтверждён. | `[D][Clarify]` Решить, нужен ли преднастроенный DEMO profile как командный способ показа. Не считать Interim blocker без подтверждения. |
| UI reset/reseed отдельного DEMO | 🟡 Частично | Безопасная DEMO repository-операция и isolation tests есть, но UI/reseed flow отсутствует. | `[D][Clarify]` Подтвердить необходимость конкретного UI/reseed. Это отдельный вопрос от уже реализованного NORMAL reset/delete. |
| Последовательный экспертный demo-сценарий | 🟡 Частично | Core integration проходит Day 1–5 без ожидания; ручной полный прогон на target device не подтверждён. | `[O][I29]` Пройти требуемый сценарий. `[D][Clarify]` Отдельный DEMO entry/reset нужен только после подтверждения выбранного способа. |

## 15. Управление контентом — 2.5.14

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Задания отделены от UI | ✅ Реализовано | `assets/content/tasks.json` загружается `AssetContentRepository`. | — |
| Товары, цели, периоды и словарь отделены от UI | ✅ Реализовано | Отдельные JSON assets и typed models. | — |
| Typed parsing и validation | ✅ Реализовано | Models отклоняют malformed/duplicate content; `content_repository_test.dart`. | — |
| Новый экземпляр поддержанного типа без переписывания Core | ✅ Реализовано | Repository загружает list, screens рендерят supported `choice/categorization/budget_priority/plan_adaptation`. | — |
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

Здесь app behavior остаётся `[O][I29]`; доказательства на final physical build
помечаются `[O][F]` и не считаются blocker промежуточного пакета автоматически.

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 3.1 — Android 8.0+ compatibility | 🟡 Частично | `android/app/build.gradle.kts`: `minSdk = flutter.minSdkVersion`; resolved API level и установка на Android 8 не подтверждены. | `[O][F]` Зафиксировать resolved minSdk и проверить final APK на Android 8+. |
| 3.1 — Портретная ориентация | ❌ Не реализовано | `android/app/src/main/AndroidManifest.xml` не задаёт `screenOrientation`; в `lib/main.dart` нет orientation lock. | Заблокировать portrait и проверить rotation на устройстве. |
| 3.1 — Корректность от 360dp | 🟡 Частично | 360×800 tests есть для Home/Budget, Pet Creation, Shop, Day 1/2, Glossary и Adult; полного прогона всех состояний нет. | Провести полный 360dp smoke, включая dialogs, errors, keyboard и scaling. |
| 3.1 — Проверка на физическом Android-устройстве | ❌ Не реализовано | Нет подтверждения в текущем репозитории; emulator/widget evidence не заменяет physical device. | `[O][F]` Предоставить протокол final APK с явной пометкой physical device. |
| 3.1 — RAM физического устройства ≥3GB | ❌ Не реализовано | Нет подтверждения модели устройства и объёма RAM в текущем репозитории. | `[O][F]` Зафиксировать модель, Android version и RAM в отчёте. |
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

Все незакрытые строки этого раздела имеют classification `[A][F]`. Это
final/RuStore artifacts, а не blockers Interim 29 Sep, если отдельный официальный
interim package прямо не потребует конкретный артефакт.

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

Architecture/code checks относятся к `[O][I29]`; release-build и physical-device
evidence относятся к `[A][F]`.

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 3.4 — Разделение UI / controllers / services / repositories / storage | ✅ Реализовано | `lib/features/`; `lib/services/`; `lib/repositories/`; `lib/core/database/`; `test/services/service_boundary_test.dart`. | — |
| 3.4 — Фактический код соответствует архитектурной документации | ✅ Реализовано | `docs/ARCHITECTURE.md`; providers связывают UI → services → narrow ports → SQLite/content. | — |
| 3.4 — Код и документация находятся в repository | ✅ Реализовано | Versioned production, tests, `README.md` и `docs/`. | — |
| 3.4 — Воспроизводимая сборка | 🟡 Частично | `README.md` даёт debug run/check commands, но не фиксирует tested toolchain и release signing/build procedure. | `[A][F]` Зафиксировать Flutter/Java/Android versions и пошаговую release build. |
| 3.4 — Нет secrets/tokens/private signing keys | ✅ Реализовано | Tracked API keys/keystores/private-key files не обнаружены; release key пока не настроен. | — |
| 3.4 — Только необходимые Android permissions | ✅ Реализовано | Main manifest не содержит runtime permissions; INTERNET находится только в debug manifest. | — |
| 3.4 — Каждое permission обосновано | 🟡 Частично | Опасных permissions нет, но отдельной таблицы manifest/query/debug INTERNET rationale нет. | `[A][F]` Добавить permissions rationale в release documentation. |
| 3.4 — Startup ≤5 секунд на physical device | ❌ Не реализовано | Нет подтверждения measurement/report в текущем репозитории. | `[A][F]` Измерить cold start несколькими повторами на указанном physical device. |
| 3.4 — Visual response local action ≤1 секунды | ❌ Не реализовано | Нет подтверждения device measurements для budget/task/purchase/savings/navigation. | `[A][F]` Замерить и приложить методику, значения и устройство. |
| 3.4 — Mandatory demo без crash/blocker/progress loss/dead end | 🟡 Частично | `test/services/final_campaign_integration_test.dart` проходит Core Day 1–5; NORMAL reset/delete реализованы, но physical final-build smoke не подтверждён, а DEMO scope шага 14 требует уточнения. | `[O][I29]` Пройти обязательную interim часть сценария. `[A][F]` Повторить на final APK. `[O][Clarify]` Уточнить test-profile scope. |
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
| 3.5 — Пользовательское удаление локальных данных | ✅ Реализовано | Актуальный `origin/main`: Adult confirmation → `deleteNormalProfile`; cascade deletion, navigation to startup и bootstrap behavior покрыты tests. | — |

## 21. Доступность и UX — official UX/accessibility criteria

Прямые accessibility outcomes имеют `[O][I29]`; расширенный аудит всех edge
states и дополнительные UX-паттерны имеют `[Q][Opt]`, если не нужны для
подтверждения конкретного official outcome.

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Portrait UX | 🟡 Частично | Layouts ориентированы на узкий экран, но ориентация не заблокирована. | `[O][I29]` Зафиксировать portrait behavior. `[A][F]` Повторить device QA на final build. |
| Работа на 360dp | 🟡 Частично | Есть существенное widget coverage 360dp, но не все состояния/экраны. | `[O][I29]` Проверить обязательные flows. `[Q][Opt]` Расширить ручную матрицу на все edge states. |
| Короткие понятные тексты | ✅ Реализовано | Основные CTA и child-facing explanations короткие и конкретные. | — |
| Термины объяснены | ✅ Реализовано | Onboarding + 9-entry glossary. | — |
| Следующее действие понятно | 🟡 Частично | Home и errors обычно дают следующий шаг; insufficient shop и history/progress access требуют проверки буквального outcome. | `[O][I29]` Закрыть outcome понятного следующего шага. `[Q][Opt]` Конкретная единая CTA/постоянный route — рекомендуемый способ. |
| Touch targets около 48dp | 🟡 Частично | Filled buttons имеют min 48; Adult unlock 48; Material defaults помогают остальным, но системной проверки всех custom/tap targets нет. | Провести accessibility audit размеров всех интерактивных элементов. |
| Основной текст около 16sp | 🟡 Частично | Ряд child-facing текстов явно 16/18sp, но глобальный `bodyMedium` размер не задан и зависит от Material defaults. | Зафиксировать типографическую шкалу и проверить все экраны. |
| Поддержка font scaling | 🟡 Частично | Home/Budget тестируются с reasonable text scaling; нет полной проверки всех экранов и больших масштабов. | Прогнать 1.3–2.0× на целевых экранах и устранить overflow. |
| Цвет не единственный сигнал | 🟡 Частично | Checkpoints используют icon+label, stats имеют labels/semantics; системного аудита всех success/error/status элементов нет. | Проверить весь flow без различения цветов и добавить non-color cues. |
| Ошибки, успех, категории и состояния имеют non-color cues | 🟡 Частично | Task feedback использует текст, checkpoints — icon+label, но нет полного аудита Shop/Savings/Pet status и TalkBack. | Проверить каждый status/error/success/category элемент и документировать результат. |
| Semantics для ключевых элементов | 🟡 Частично | Finny image, stats, task zones и adult unlock имеют Semantics; coverage не полный. | Проверить TalkBack и добавить labels/hints для custom controls. |
| Назад работает предсказуемо | ✅ Реализовано | Router/AppBars/PopScope обрабатывают back; Adult fallback ведёт в Settings. | — |
| Destructive actions подтверждаются | ✅ Реализовано | Adult reset/delete имеют разные dialogs, cancel по умолчанию и отключение повторного запуска во время операции; widget tests проверяют cancel/confirm/failure. | — |
| Scroll/overflow | 🟡 Частично | Основные длинные экраны scrollable; 360dp tests существуют, но полного набора состояний нет. | Ручной QA всех dialogs/error/keyboard/text-scale states. |

## 22. Testing evidence

Автоматизированные и расширенные QA-проверки по умолчанию имеют `[Q][Opt]`.
Release/physical evidence имеет `[A][F]` и не считается Interim blocker.

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Budget logic tests | ✅ Реализовано | `test/services/core_game_loop_test.dart`; `test/home_budget_planning_test.dart`. | — |
| Purchase и insufficient-funds tests | ✅ Реализовано | `test/services/purchase_business_errors_test.dart`; `test/features/shop/shop_screen_test.dart`. | — |
| Savings tests | ✅ Реализовано | `test/features/savings/`; `test/services/core_game_loop_test.dart` savings cases. | — |
| Transactions tests | ✅ Реализовано | `test/repositories/game_repository_test.dart`: traceable wallet transaction; Core tests. | — |
| Period transitions tests | ✅ Реализовано | `test/services/day_lifecycle_test.dart`; `test/services/day_one_virtual_day_integration_test.dart`. | — |
| Task retry/idempotency tests | ✅ Реализовано | `test/services/task_completion_test.dart`; `test/services/idempotent_retry_after_completion_test.dart`. | — |
| Profile isolation tests | ✅ Реализовано | NORMAL/DEMO cases покрыты Core tests; актуальный `origin/main` также проверяет NORMAL reset/delete и неизменность другого профиля в `profile_data_management_test.dart`. | — |
| Persistence tests | ✅ Реализовано | SQLite reopen tests для Pet, Shop, Savings, Tasks и Core state. | — |
| Pet progression tests | ✅ Реализовано | `test/services/pet_state_test.dart`; `test/services/day_lifecycle_test.dart`. | — |
| Day 1 interactive widget/core tests | ✅ Реализовано | `test/features/tasks/day1_categorization_task_test.dart`; `test/services/task_categorization_test.dart`. | — |
| Day 2 interactive widget/core tests | ✅ Реализовано | `test/features/tasks/day2_budget_priority_task_test.dart`; `test/services/task_budget_priority_test.dart`. | — |
| Day 3 plan-adaptation и Day 4–5 choice tests | ✅ Реализовано | Day 3: `test/features/tasks/day3_plan_adaptation_task_test.dart` и `test/services/task_plan_adaptation_test.dart`; Day 4–5 choice validation/completion: `test/services/task_completion_test.dart`; full sequence: `test/services/final_campaign_integration_test.dart`. | — |
| Adult tests | ✅ Реализовано | `test/features/adult/adult_screen_test.dart`: barrier, tap, long press, progress, stale reads, 360dp. | — |
| Glossary tests | ✅ Реализовано | `test/repositories/glossary_content_test.dart`; `test/features/help/help_screen_test.dart`. | — |
| Navigation tests | ✅ Реализовано | `test/features/navigation_test.dart`; route behavior also exercised by feature widget tests. | — |
| 5-period campaign integration test | ✅ Реализовано | `test/services/final_campaign_integration_test.dart` reaches five completed periods and Stage 3. | — |
| 360dp regression tests | 🟡 Частично | Several key screens set 360×800, but not every route/dialog/error state in Appendix A. | `[Q][Opt]` Add a complete UI matrix or manual 360dp report beyond the mandatory flows. |
| Full automated suite result on audited SHA | 🟡 Частично | Tests exist, but the task explicitly excludes running full `flutter test`; no current CI status is attached to the audited commit. | `[A][F]` Run the full suite in release validation and link the result. |
| Physical-device verification | ❌ Не реализовано | No confirmation in the current repository. | `[A][F]` Execute Appendix A on the final signed APK and provide the device report. |

## 23. Appendix A — обязательный демонстрационный сценарий

Основной сценарий имеет `[O][I29]`. Шаги, которые требуют final signed APK или
имеют спорный profile scope, получают явный override.

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| 1. Установка и запуск с intro | 🟡 Частично | Первый запуск и intro покрыты widget test; установка standalone/final APK не подтверждена. | `[O][Clarify]` Подтвердить формат build для Interim. `[A][F]` Проверить final APK на чистом физическом устройстве. |
| 2. Создание локального профиля | ✅ Реализовано | Onboarding создаёт NORMAL без регистрации. | — |
| 3. Настройка питомца | ✅ Реализовано | Имя + 9 appearance combinations. | — |
| 4. Стартовый бюджет, цель и задания | ✅ Реализовано | Day start, Savings goal selection и task list доступны. | — |
| 5. Составление бюджета | ✅ Реализовано | Draft/confirm flow. | — |
| 6. Задание, награда и explanation | ✅ Реализовано | Day 1/2, Day 3 `plan_adaptation` и choice tasks показывают result/reward. | — |
| 7. Покупка need и want | ✅ Реализовано | Каталог содержит оба типа; purchase flow общий и проверен. | — |
| 8. Сценарий недостатка средств | 🟡 Частично | Ошибка показывает цену/баланс/дефицит, но следующий шаг не формализован. | `[O][I29]` Подтвердить recovery outcome в ручном smoke. `[Q][Opt]` Конкретная CTA — один из UX-способов. |
| 9. Выбор цели и deposit | ✅ Реализовано | Полный Savings flow реализован. | — |
| 10. Feedback о последствиях | 🟡 Частично | Task, plan/fact и stat feedback есть; причинное объяснение эмоции/роста неполно. | Улучшить explanation и проверить понятность с ребёнком/экспертом. |
| 11. Следующий период и новая стадия | ✅ Реализовано | Sequential Day 1–5, Stage 2/3; integration test. | — |
| 12. Перезапуск и сохранение | ✅ Реализовано | Reopen/persistence tests для ключевых domains. | — |
| 13. Раздел взрослого | ✅ Реализовано | Long-press barrier и read-only overview. | — |
| 14. Reset/delete test profile | 🟡 Частично | NORMAL reset/delete через Adult реализованы и проверены; отдельного пользовательского DEMO reset/reseed нет. | `[O][Clarify]` Уточнить, означает ли «test profile» NORMAL либо обязательный DEMO. `[D][Clarify]` DEMO UI/reseed не считать P0 без прямого source. |

## 24. Submission documentation

Незакрытые строки раздела классифицируются как `[A][F]`, если рядом не указан
более ранний этап. Они отслеживают пакет сдачи и не являются дополнительными
функциональными требованиями приложения.

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
| Profile deletion procedure | 🟡 Частично | Delete NORMAL реализован и UI объясняет последствия, но отдельного submission-ready описания процедуры нет. | `[A][F]` Документировать путь Adult → delete, последствия и локальный scope. |
| Test cases | 🟡 Частично | Automated tests присутствуют, но в текущем репозитории нет подтверждения фактического expert checklist с expected results. | Предоставить acceptance test cases, включая Appendix A. |
| Physical-device report | ❌ Не реализовано | Нет подтверждения в текущем репозитории. | Предоставить device/OS/RAM/build/timing/result report. |
| Known limitations | ✅ Реализовано | `README.md` backlog и Known gaps этой матрицы. | — |
| Future plan | ✅ Реализовано | `README.md` backlog и P1/P2 этой матрицы. | — |
| Third-party libraries/licenses | ❌ Не реализовано | Dependency list есть, но в текущем репозитории нет подтверждения фактического license inventory/NOTICE. | Предоставить license report. |
| Fonts/images/sounds licenses | ❌ Не реализовано | Custom fonts/sounds отсутствуют, но provenance launcher/visual assets и consolidated rights statement не подтверждены. | Подготовить rights statement с N/A для отсутствующих типов. |

## 25. Presentation and demo materials

Незакрытые строки раздела имеют `[A][F]`: это presentation/final-demo
artifacts, а не функциональные P0 для Interim 29 Sep.

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
| Next steps | 🟡 Частично | Stage-based Interim/Final/Clarify/Optional plan сформирован в matrix, но presentation roadmap не подтверждён. | Добавить stage-based next-steps slide без спорных P0. |
| Links to repo/build/docs | ❌ Не реализовано | В текущем репозитории нет подтверждения фактической presentation с проверенными ссылками; deck мог быть подготовлен отдельно. | Добавить ссылки/QR в финальный deck и предоставить доступ. |
| Backup demo video ≤3 min | ❌ Не реализовано | Нет подтверждения video/link в текущем репозитории. | Записать final APK flow, уложиться в 3 минуты и проверить доступ. |

## 26. Final submission artifacts

Весь раздел имеет classification `[A][F]`. Ни одна его незакрытая строка не
считается blocker Interim 29 Sep без отдельного прямого требования.

| Требование | Статус | Реализация / доказательство | Что осталось |
|---|---|---|---|
| Expert-accessible repository | 🟡 Частично | GitHub repository/PR доступны текущему подключению, но доступ экспертов не подтверждён. | Проверить public/invite permissions внешней учётной записью. |
| Final release tag | ❌ Не реализовано | Нет подтверждения final tag/release для audited state. | Создать только после принятия release candidate. |
| Complete unobfuscated source | ✅ Реализовано | Repository содержит Flutter/Dart source, content, tests и docs; source-obfuscation artifact не используется. | — |
| Signed release APK | ❌ Не реализовано | Нет подтверждения artifact; release config использует debug key. | Собрать, подписать release key, проверить certificate/hash/install. |
| Install/run instructions | 🟡 Частично | Debug quick start есть в README; final APK install steps отсутствуют. | Добавить final artifact URL/hash и пошаговую установку. |
| Demo-mode instructions | ❌ Не реализовано | Отдельного пользовательского DEMO mode нет; NORMAL reset/delete доступны, а необходимость DEMO UI/reseed требует решения. | `[A][F]` Документировать фактически выбранный demo flow. `[D][Clarify]` Не требовать новый DEMO UI без подтверждения. |
| Profile/test-data reset instructions | 🟡 Частично | NORMAL reset/delete реализованы, но финальные инструкции не подготовлены; DEMO UI/reseed не подтверждён как выбранный flow. | `[A][F]` Документировать NORMAL actions; DEMO instructions добавлять только после product/customer decision. |
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

1. `[O]` Day 4 и два задания Day 5 используют `choice`; Day 1
   (`categorization`), Day 2 (`budget_priority`) и Day 3 (`plan_adaptation`)
   имеют отдельные интерактивные task-механики.
2. `[D][Clarify]` Технические DEMO type/cleanup/isolation существуют, но нет
   готового пользовательского DEMO entry/reset/reseed. Необходимость именно
   такого UI не подтверждена как буквальное official requirement.
3. `[Q][Opt]` Игрушки применяют прямой stat-effect при отдельном use;
   самостоятельных игровых взаимодействий/minigames нет.
4. `[O][Clarify]` Нет постоянного UI истории заданий и периодов; буквальная
   глубина history, требуемая официальным источником, нуждается в уточнении.
5. `[O][Clarify]` Рост Stage 2/3 привязан к Day 2/5. Связь с прохождением есть,
   но достаточность этой связи и конкретная scoring formula не подтверждены.
6. `[Q][Opt]` Нет полного пользовательского transaction journal. Это полезный
   способ повысить explainability, но не отдельное подтверждённое требование.
7. `[O]` Причины эмоционального состояния/роста питомца объяснены неполно.
8. `[O]` Portrait lock отсутствует; Android 8+ не подтверждён на target device.
9. `[A][F]` Release использует debug signing; в текущем репозитории не
    подтверждены signed APK, install evidence, RuStore package, лицензии,
    финальный deck и backup video.
10. `[A][F]` Не подтверждены cold start/response-time measurements и полный
    ручной прогон final build на физическом Android-устройстве.

Актуальный `origin/main` уже содержит принятый командой NORMAL data-management
slice: reset прогресса с сохранением profile identity/Finny и полное delete
NORMAL через Adult с отдельными подтверждениями. Это current implementation,
а не только planned work. DEMO flow классифицируется отдельно.

## Remaining blockers before submission

`Blocker` ниже означает только прямо подтверждённую обязательную работу для
указанного этапа. Спорные трактовки вынесены в clarification и не называются P0.

### Interim 29 Sep — blockers

1. `[O][I29]` Закрыть буквальный Home outcome: active task должен быть виден,
   а требуемые progress/Adult данные — доступны. Матрица не предписывает
   название + отдельную CTA как единственный способ.
2. `[O][I29]` Закрыть буквальную feedback/explainability часть обязательного
   сценария: изменения balance/Pet и выход из ошибок не должны оставаться
   необъяснимыми или приводить в dead end. Полный transaction journal не нужен,
   если outcome закрывается более узким способом.
3. `[O][I29]` Пройти подтверждённую часть Appendix A и зафиксировать результат
   на актуальном build. Граница шага 14 про «test profile» требует уточнения и
   не превращает DEMO UI/reseed в автоматический blocker.

### Final — blockers

1. `[A][F]` Настроить production signing, собрать signed APK, проверить
   certificate/hash и чистую установку.
2. `[A][F]` Подтвердить Android 8+, portrait, cold start, response time и
   обязательный сценарий на согласованном физическом устройстве.
3. `[A][F]` Подготовить final/RuStore package: repository access, release tag,
   install documentation, store metadata, ≥3 screenshots, 512×512 icon,
   age-rating rationale, licenses/rights package, presentation и backup video.
4. `[A][F]` Завершить submission documentation, включая data dictionaries,
   educational content map, privacy/permissions, accessibility и test report.

### Needs customer clarification

1. `[D][Clarify]` Нужны ли готовый DEMO-профиль, отдельный UI reset и reseed,
   или обязательный demo может проходить на NORMAL с уже реализованным reset?
2. `[O][Clarify]` Какой буквальный результат означает Appendix A «reset/delete
   test profile» и к какому этапу он относится?
3. `[O][Clarify]` Достаточна ли связь Stage с обязательным прохождением Day 2/5?
   Если нет, команда должна отдельно принять scoring formula; сама формула не
   является official requirement без подтверждения.
4. `[O][Clarify]` Какова минимальная требуемая глубина history/progress и
   повторного доступа к Period Summary?
5. `[O][Clarify]` Какой объём help после onboarding обязателен и достаточно ли
   текущего glossary/help без полного replay?

### Optional / polish

1. `[Q][Opt]` Добавить полный transaction journal поверх минимального
   объяснения обязательных операций.
2. `[Q][Opt]` Добавить расширенную постоянную history сверх подтверждённой
   буквальной глубины.
3. `[Q][Opt]` Добавить replay полного onboarding и повторную customization Pet.
4. `[Q][Opt]` Добавить игрушкам отдельные interactions/minigames.
5. `[Q][Opt]` Использовать отдельную CTA/название active task, если команда
   выберет этот UX-способ закрытия Home outcome.

## Questions requiring captain/customer decision

1. Нужен ли отдельный пользовательский DEMO flow и какой state должен
   восстанавливаться при reseed? NORMAL reset/delete уже реализованы отдельно.
2. Что означает «test profile» в Appendix A: NORMAL, DEMO или любой профиль,
   созданный для показа?
3. Достаточна ли текущая связь развития Pet с обязательным прохождением Day 2/5;
   если нет, какую scoring formula команда принимает как product decision?
4. Какой минимальный Home outcome, history depth и объём повторной help считаются
   достаточными без навязывания конкретной UI-реализации?
5. Кто владеет release keystore, package ID `ru.codexteam.finny`, RuStore
   кабинетом, возрастной анкетой и доказательствами прав на контент?
6. Какое физическое устройство является приёмочным (модель, Android, RAM), и
   кто подписывает протокол производительности/стабильности?
7. Существуют ли вне repository уже подготовленные presentation, screenshots,
   APK, video, RuStore draft или license evidence, и где эксперты получат к ним
   доступ?

## Контрольные замечания по трактовке статусов

- Day 1 учтён как `categorization`, Day 2 как `budget_priority`, Day 3 как
  `plan_adaptation`, Day 4–5 как `choice`; наличие story/purchase dialogs не
  меняет тип задания.
- NORMAL reset/delete в актуальном `origin/main` считаются реализованными по
  production-коду и tests. Они не доказывают наличие отдельного DEMO flow.
- Core-метод очистки DEMO не означает пользовательский DEMO reset/reseed, пока
  нет UI и повторного заполнения state; необходимость такого UI ещё не является
  подтверждённым P0.
- Возможность пройти периоды подряд без ожидания не означает готовый demo mode.
- 360dp widget tests и эмулятор не подтверждают физическое устройство.
- `signingConfig = debug` не является release signing.
- README использован только как указатель на ограничения и инструкции; статусы
  реализации подтверждены кодом, контентом и тестами.
- Конкретная formula роста, полный journal/history, replay onboarding,
  re-customization и отдельная Home CTA не повышаются до official requirement
  без прямого источника.
- Interim 29 Sep и Final/RuStore разделены; final-only artifacts не считаются
  blockers промежуточного этапа.

## Status counts

Считаются только строки основных matrix-таблиц со статусом, без headings,
легенды, task inventory и этого блока.

- ✅ 197
- 🟡 66
- ❌ 48
- ➖ 7
- **Всего:** 318

Это количество атомизированных audit checks, а не процент выполнения и не
количество независимых официальных требований.
