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

Purchase, task reward, explicit income и wallet → savings разрешены только в
`active`/`readyToFinish`. Purchase, deposit и explicit income используют
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
