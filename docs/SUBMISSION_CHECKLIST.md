# Finny — submission checklist

Статусы в этом файле ограничены тремя значениями:

- **READY** — подтверждено текущим `main` или уже подготовлено в этом
  documentation package.
- **VERIFY** — есть источник или реализация, но нужен внешний artifact, ручная
  проверка, капитанское решение или проверка на целевом устройстве.
- **MISSING** — в текущем репозитории/пакете этого ещё нет.

Чеклист разделяет промежуточную сдачу 29 сентября 2026 года и Final/RuStore.
Final-only artifact не становится автоматически blocker-ом Interim.

# Interim — до 29.09.2026 23:59

| Item | Status | Evidence / next check |
|---|---|---|
| Доступ эксперта к текущему репозиторию и branch/PR | VERIFY | После push проверить remote branch и PR URL; доступ внешнего эксперта не подтверждается локальным commit |
| Документационный пакет submission/demo | READY | Четыре файла этого follow-up: outline, demo script, shotlist, checklist |
| README и краткий способ запуска | VERIFY | README существует, но содержит устаревшее утверждение о read-only Adult; discrepancy не исправляется в рамках этого package |
| Architecture evidence | READY | `docs/ARCHITECTURE.md`, текущая Flutter/Riverpod/GoRouter/SQLite/JSON схема |
| Current Requirements Matrix | READY | `docs/REQUIREMENTS_MATRIX.md` на актуальном `main`; atomic checks и классификация уже разделены |
| Core loop/content evidence | READY | `docs/CORE_GAME_LOOP.md`, `docs/PRODUCT_SPEC.md`, `assets/content/*.json` |
| Пояснение известных ограничений и вопросов | READY | Risks и captain decisions зафиксированы в этом checklist и demo script |
| Intermediate APK или другой пакет для скачивания | VERIFY | Локальный репозиторий не является подтверждением внешней загрузки; приложить artifact, если он требуется Interim |
| Ключевые Interim screenshots | VERIFY | Снять по `docs/SCREENSHOT_SHOTLIST.md`; наличие файлов вне репозитория нужно подтвердить отдельно |
| Короткий demo route | READY | `docs/DEMO_SCRIPT.md` описывает 3–5 минут и backup route; live rehearsal ещё VERIFY |
| NORMAL profile для live demo | VERIFY | Нужна организационная подготовка состояния; готового отдельного DEMO reset/reseed flow в текущем `main` нет |
| Day 1 categorization evidence | READY | Код, assets и tests подтверждают 6 карточек, две зоны и исправляемый feedback |
| Day 2 budget-priority evidence | READY | Код и test подтверждают лимит 150, цены 90/60/80, overflow guard и feedback |
| Day 3 plan adaptation evidence | READY | Current main содержит typed `plan_adaptation`, потерю 80 монет, новый бюджет 220 и widget/core tests |
| Day 4–5 choice flow | VERIFY | Контент и choice validation есть; полный пятидневный manual smoke и внешний Interim artifact нужно проверить |
| Offline Core / no mandatory account | READY | README/spec/architecture и локальные repositories описывают offline scope |
| Safety/privacy scope | READY | Нет real money, bank, ads, subscription, mandatory account, public child chat или cloud sync в заявленном Core |
| Known README discrepancy записана для эксперта | READY | См. раздел `Риски и расхождения` ниже; README намеренно не меняется этим follow-up |

В Interim не считаются автоматическими blockers следующие Final-only items:
production signing, final signed APK, final RuStore package, store icon 512×512,
final store metadata, final presentation и backup final video — если отдельное
официальное Interim instruction не требует их буквально.

# Final

| Item | Status | Evidence / next check |
|---|---|---|
| Финальный release APK | VERIFY | В текущем docs-only diff APK не создаётся; проверить release artifact, hash и install path |
| Production signing | VERIFY | Подтвердить владельца signing key и финальную процедуру вне репозитория |
| Установка на целевом Android 8+ | VERIFY | Проверить на реальном устройстве; текущий код не заменяет device smoke |
| Portrait layout и минимум 360dp | VERIFY | Снять device evidence по shotlist; отдельно проверить clipping и нижнюю навигацию |
| Offline запуск после установки | VERIFY | Core описан и локальные tests есть; нужен ручной startup/restart smoke на финальном APK |
| Persistence после restart | VERIFY | Проверить profile, plan, transactions, inventory и progress после закрытия/повторного запуска |
| Полный Day 1 → Day 5 campaign smoke | VERIFY | Тесты покрывают ключевые slice, но нужен целостный manual route без блокирующего состояния |
| Budget plan/fact | READY | Реализованные Budget и Period Summary screens, services и tests есть в current main; финальный device кадр VERIFY |
| Savings goal flow | READY | Savings screen/service/tests есть; полный финальный device smoke VERIFY |
| Pet creation/customization | READY | Имя, цвет и узор реализованы; повторная customization после создания не заявляется как обязательный requirement |
| Adult overview | READY | Current main содержит overview, barrier и progress data; device smoke VERIFY |
| NORMAL reset progress | READY | Current main содержит repository/controller/UI/tests; status подтверждён кодом и тестами |
| NORMAL delete profile | READY | Current main содержит repository/controller/UI/tests и destructive confirmation |
| Demo reset/reseed flow | MISSING | Отдельный пользовательский DEMO flow не подтверждён current main; не выдавать его за готовую feature |
| Финальные screenshots | VERIFY | Снять на финальном device/APK по shotlist; screenshots этим PR не создаются |
| Финальная презентация PPTX/PDF | MISSING | В этом PR есть только outline, не готовый deck |
| Backup final video | VERIFY | Записать и проверить как внешний artifact; не считать demo script самим видео |
| RuStore package и metadata | VERIFY | Название, описание, screenshots, category, privacy text и package upload требуют внешней проверки |
| Store icon 512×512 и прочие final assets | VERIFY | Проверить фактические assets и размеры; текущий docs-only PR их не добавляет |
| Release/install instructions | MISSING | README не обновляется; добавить отдельную release instruction только после решения капитана |
| Лицензии и attribution | VERIFY | Проверить зависимости и финальный package перед публикацией |
| Startup/performance smoke | VERIFY | Измерить startup, local action response и отсутствие crash/blocker на target device |

# Уже готово

| Area | Status | Evidence |
|---|---|---|
| Documentation-only scope defined | READY | Изменяются только четыре файла из этого пакета |
| Presentation structure | READY | 9-slide `PRESENTATION_OUTLINE.md` с тезисами, visual и speech notes |
| Demo procedure | READY | Main route, backup route, risks и timeboxes в `DEMO_SCRIPT.md` |
| Screenshot inventory | READY | Concrete states, priorities и readiness statuses в `SCREENSHOT_SHOTLIST.md` |
| Submission status model | READY | READY/VERIFY/MISSING и отдельные Interim/Final sections в этом файле |
| Current implementation evidence | READY | Ссылки на code/content/tests приведены по фактическому `main` |
| Adult data management evidence | READY | Reset/delete slice NORMAL отражён как реализованный current main; DEMO отдельно |
| Classification discipline | READY | Official result отделён от accepted decision, recommendation и final artifact |
| 318 atomic-check warning | READY | Matrix explicitly says checks are not independent official requirements or completion percentage |

# Требует решения капитана

| Decision | Status | Why it matters |
|---|---|---|
| Какой profile/state использовать в live demo | VERIFY | Текущий `main` не содержит отдельного готового DEMO reset/reseed; нужен воспроизводимый организационный plan |
| Основной live пример: Day 1 или Day 2 | VERIFY | Day 1 лучше показывает категоризацию, Day 2 быстрее показывает ограниченный бюджет и trade-off |
| Где хранить APK, screenshots и backup video | VERIFY | Нужны owner, доступ эксперта и проверенный внешний URL/артефакт |
| Кто отвечает за production signing и RuStore upload | VERIFY | Это Final release action, не documentation-only изменение |
| Нужен ли UI polish перед hero screenshots | VERIFY | Shotlist отмечает состояния, где читаемость важнее добавления новых функций |
| Что означает “test/demo profile” в submission language | VERIFY | Нужно не смешать accepted product decision с официальным требованием DEMO mode |
| Нужен ли отдельный DEMO flow | VERIFY | Без прямого official source это product decision или clarification, а не P0 requirement |
| Нужен ли replay onboarding или повторная customization | VERIFY | Без прямого official source оставить optional/polish или запросить clarification |
| Какой комплект screenshots минимален для Interim | VERIFY | Final/RuStore shots не следует автоматически переносить на Interim |

## Риски и расхождения

### README против current main

Текущий `README.md` всё ещё говорит, что Adult работает как read-only и reset/delete
не реализованы. В актуальном `main` код, tests и Requirements Matrix уже содержат
accepted NORMAL reset/delete slice с подтверждениями. Это зафиксировано как риск
документационной согласованности; README намеренно не изменяется этим
documentation-only package.

### Реализация против намерения

Статус `READY` для Adult reset/delete относится к фактическому current main. Он не
означает, что будущий DEMO reset/reseed flow существует или что final device QA
уже проведён. Planned work, внешний artifact и captain decision остаются
`VERIFY`/`MISSING` по таблицам выше.

### Requirements Matrix против current main

После создания этой ветки `origin/main` продвинулся до
`cab87fb35334bb5c222011393bd8951004e8990b` с Day 3 `plan_adaptation` и
связанными tests. `docs/REQUIREMENTS_MATRIX.md` на этом SHA всё ещё описывает
Day 3–5 как `choice`. В этом package используется фактический current code как
source of truth, расхождение отмечено для капитана, а matrix не изменяется.

### Метрики матрицы

Requirements Matrix атомизирует составные requirements в audit checks и включает
технические доказательства, QA-проверки и submission artifacts. Поэтому её
`✅ / 🟡 / ❌ / ➖` counts не являются процентом выполнения официального ТЗ.

## Evidence paths

- `docs/PRESENTATION_OUTLINE.md`
- `docs/DEMO_SCRIPT.md`
- `docs/SCREENSHOT_SHOTLIST.md`
- `docs/REQUIREMENTS_MATRIX.md`
- `docs/PRODUCT_SPEC.md`, `docs/ARCHITECTURE.md`, `docs/CORE_GAME_LOOP.md`
- `lib/features/adult/adult_screen.dart`,
  `lib/repositories/profile_data_management_repository.dart`
- `lib/features/tasks/plan_adaptation_task_screen.dart`,
  `test/features/tasks/day3_plan_adaptation_task_test.dart`
- `test/features/adult/adult_screen_test.dart`,
  `test/repositories/profile_data_management_test.dart`
