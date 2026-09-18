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

Purchase, explicit income и wallet → savings разрешены только в
`active`/`readyToFinish`. Новая task reward выдаётся только за правильный ответ
на canonical choice task в `active`: reward, `task_progress` и checkpoint
`financial_task` записываются одной SQLite transaction. Consistent replay
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

## Checkpoints и завершение

Checkpoint принадлежит конкретному period instance. Разрешается закрывать только
ID из required snapshot. Когда закрыты все required checkpoints, период становится
`readyToFinish`, но не завершается автоматически. В этом состоянии optional
финансовые действия остаются разрешены.

Только явное завершение переводит период в `completed` и фиксирует ending wallet.
Completed period недоступен для новых игровых транзакций, изменения plan или
checkpoints. Следующий content period стартует только отдельной командой.

## Active-time Финни

Характеристики Финни изменяются Core-операциями, а не виджетами. В активном или
готовом к завершению периоде `applyActiveElapsedTime` атомарно обновляет Pet и
period-bound счётчики: за шесть минут foreground active-time дневной decay
достигает максимумов `15` сытости, `10` ухода и `12` настроения. Persisted
счётчики исключают повторное применение после restart. Реальное wall-clock время
между вызовами, planning и completed не учитываются.

## Использование вещей и взаимодействия

`ItemUseService.useItem` принимает item ID, перечитывает canonical content и не
доверяет caller-значениям эффектов или usage policy. В `active` и
`readyToFinish` repository атомарно применяет stat effect, уменьшает quantity
расходника и фиксирует period-bound usage. Постоянные предметы не расходуются:
расчёска и каждая игрушка доступны один раз за период, а зубная щётка имеет
раздельные morning/evening slots. Morning доступен только в `active`, evening —
после перехода в `readyToFinish`.

Бесплатные действия `погладить` (+20 mood) и `поиграть` (+25 mood) имеют
отдельные once-per-period usage records. Успешные item/free операции сохраняют
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
