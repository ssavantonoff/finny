# Core Game Loop v1

## Период и state machine

Последовательность периодов задаётся `assets/content/periods.json`. При старте в
runtime сохраняются identity/order definition, `baseIncome` и required checkpoint
IDs, поэтому уже начатый период не меняется при обновлении content.

Разрешённые переходы:

```text
planning → active → readyToFinish → completed
```

Старт выполняется одной SQLite transaction: создаётся period snapshot,
начисляется `baseIncome`, записывается объяснимая transaction и обновляется
wallet. Повторный старт не может создать второй незавершённый период или повторно
начислить доход.

## Wallet, budget и savings

`openingWalletBalance` — wallet до начисления дохода. `startingBudget` равен
`openingWalletBalance + baseIncome`; savings в него не входит. Wallet и savings
переносятся между периодами отдельно.

В `planning` сохраняется budget draft: Need, Want и Savings. Remainder вычисляется
от `startingBudget`. Подтверждение не перемещает деньги и переводит период в
`active`; после этого исходный plan неизменяем.

Draft можно сохранить с нулём в категориях, но подтверждение требует не менее
10 игровых монет в каждом из Need, Want и Savings. Это game-validation rule
экрана планирования: полный `startingBudget` распределять не требуется, а
положительный remainder допустим.

Purchase, explicit income и wallet → savings разрешены только в
`active`/`readyToFinish`. Новая task reward выдаётся только после canonical
successful completion choice-, categorization-, budget-priority- или
plan-adaptation-задания в `active`: reward,
`task_progress` и checkpoint `financial_task` записываются одной SQLite
transaction. Consistent replay
завершённого задания допустим и в `readyToFinish`/`completed`, но не выдаёт
награду повторно; generic checkpoint API не закрывает `financial_task`.
Purchase, deposit и explicit income используют
persisted caller-provided `operationId`: идентичный retry является no-op, а тот же
ID с другим payload отклоняется. Public savings withdrawal отсутствует.
Savings deposit требует canonical active goal, не может превысить недостающую до
цели сумму и в одной transaction обновляет wallet, глобальную копилку,
`actualSavings`, журнал и checkpoint `savings_decision`.

Цель можно один раз сменить до её достижения без сброса копилки. Claim не зависит
от состояния периода: он списывает canonical цену только из savings, создаёт
`completed_goals`, выдаёт persistent reward в inventory и сохраняет возможный
остаток. Claim не является расходом периода и не меняет его `actualSavings`.

## Checkpoints, bedtime и завершение

Checkpoint принадлежит конкретному period instance. Разрешается закрывать только
ID из required snapshot. Когда закрыты все required checkpoints, период становится
`readyToFinish`, но не завершается автоматически. В этом состоянии optional
финансовые действия остаются разрешены.

Явный bedtime сначала проверяет persisted virtual progress: до `76` Core
возвращает `tooEarly` независимо от статуса периода. После `76` unresolved
checkpoints блокируют сон; зелёные характеристики разрешают обычный сон;
достижимая зелёная зона требует продолжить уход; fallback разрешён только когда
точный расчёт canonical вещей, usage, бесплатных действий, магазина, wallet и
дополнительного natural decay доказал невозможность достичь `70/70/70`. При
sleep расчёт повторяется внутри SQLite
transaction, после чего вместе сохраняются ending wallet, `completedAt`, period,
Pet и переход Stage 2 после Day 2 либо Stage 3 после Day 5. Вечерние значения не
сбрасываются. Completed period недоступен для новых игровых транзакций, изменения
plan или checkpoints.

При старте Day 2–5 `PetStateRules.nextMorningPet` применяется ровно один раз в
той же transaction, что создание следующего периода и начисление base income.
Wallet и savings переносятся; Day 1 утренний reset не получает.

## Виртуальное время и потребности Финни

Каждый период хранит `dayProgress` в диапазоне `0..100`. Фаза вычисляется, а не
сохраняется отдельно: `0..34` — утро, `35..69` — день, `70..100` — вечер.
Реальное ожидание, foreground/background и переходы по вкладкам progress и Pet
не меняют.

Время продвигают только canonical gameplay mutations: первое подтверждение
плана `+10`, первые четыре кормления по `+8`, morning/evening toothbrush по
`+6`, первые два обычных ухода по `+5`, первое required task completion `+30`,
первое savings decision `+8` и первое поглаживание `+4`. Purchase, draft,
выбор/claim цели и retries дают `+0`. Progress ограничен `100`.

Natural decay вычисляется cumulative target от progress: к `100` он составляет
`60` сытости, `20` ухода и `12` настроения. Каждая атомарная операция применяет
только разницу target между старым и новым progress, затем canonical effect и
clamp `0..100`. Поэтому дробление действий и restart не меняют результат.
Новый Финни начинает Day 1 с `55/80/80`. Формула следующего утра Day 2–5
детерминированно ограничивает каждую характеристику значением не выше вечернего:
ночь не восстанавливает низкий stat автоматически.

## Использование вещей и взаимодействия

`ItemUseService.useItem` принимает item ID, перечитывает canonical content и не
доверяет caller-значениям эффектов или usage policy. В `active` и
`readyToFinish` repository атомарно применяет natural decay, stat effect,
virtual progress, уменьшает quantity расходника и фиксирует period-bound usage.
Постоянные предметы не расходуются: расчёска и игрушки ограничены одним
системным эффектом за период, а зубная щётка имеет раздельные morning/evening
slots. Для `toy_ball` и `toy_frisbee` обычное использование заблокировано:
настроение применяется только после завершения соответствующей мини-игры.
Играть повторно можно без повторного эффекта. В Free Play право на эффект
каждой из этих игрушек сохраняется отдельно для профиля без дневного сброса.
Для зубной щётки slot определяется по progress до действия: morning `<35`,
evening `>=70`, в `35..69`
щётка недоступна. Каждый initialized profile получает `care_toothbrush` один раз
без wallet transaction.

Бесплатное действие `погладить` даёт `+5 mood` и `+4 progress` один раз за
период. Старое one-tap `поиграть` больше не является production gameplay path.
Успешные item/free операции сохраняют
`operationId`: тот же payload является безопасным replay даже после завершения
периода, а повтор ID с другим action/slot отклоняется. Новый period получает
новый namespace usage автоматически; restart текущего периода ничего не
сбрасывает.

## Plan / Fact

`PeriodSummary` объединяет immutable plan snapshot и persisted transactions
периода:

- `additionalIncome` — положительные period transactions кроме base income;
- `factNeed` / `factWant` — реальные расходы соответствующих категорий;
- `factSavings` — реальные wallet → savings deposits;
- `factRemainder` — текущий wallet либо зафиксированный ending wallet;
- deviations — `fact - plan`.

Savings не входит в `totalExpenses`, а данные разных профилей всегда фильтруются
по `profileId`.

Day 3 bowl story event — отдельная canonical NEED-операция: миска стоит 120,
может быть отложена или оплачена wallet с покрытием только точного дефицита из
savings. Она не меняет immutable plan; при покупке фактическая NEED-трата и
возможное снятие из savings относятся к периоду действия.
