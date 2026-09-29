# Finny — матрица готовности требований

**Аудит:** 29 сентября 2026 г.
**Source of truth:** `main` на `18a70efb1dd56b3e74f55ad04bc707f5f764c050`
(merge PR #61).
**Scope:** production-код, JSON-контент, Android-конфигурация и файлы
репозитория. Статус ✅ означает, что реализация подтверждена статически и/или
автоматическими тестами; он не заменяет проверку на устройстве. Внешние
release- и submission-материалы не видны из репозитория и учитываются отдельно.

| Статус | Значение |
| --- | --- |
| ✅ IMPLEMENTED | Есть в текущем коде/контенте и подтверждено доступной проверкой. |
| 🟡 PARTIAL / REQUIRES VERIFICATION | Реализация есть частично или объём подтверждения ограничен. |
| 🔍 MANUAL / RELEASE VERIFICATION | Требуется устройство, подписанный APK или внешний артефакт. |
| ❌ MISSING | В проверенном репозитории отсутствует требуемый результат. |

## Первый запуск и Campaign

| Требование | Статус | Evidence / граница проверки |
| --- | --- | --- |
| Onboarding | ✅ IMPLEMENTED | `lib/features/onboarding/`, `lib/app/bootstrap.dart`. |
| Локальный профиль без регистрации | ✅ IMPLEMENTED | Bootstrap создаёт NORMAL-профиль; сервер и аккаунт не нужны. |
| Имя профиля и имя Финни | ✅ IMPLEMENTED | Onboarding и `lib/features/pet_creation/`. |
| Выбор внешности Финни | ✅ IMPLEMENTED | Цвет и узор в Pet Creation; stage меняется при росте. |
| Повторное открытие подсказки «Как играть» | ✅ IMPLEMENTED | Settings → `/how-to-play`; определения общие с onboarding. |
| Пять последовательных периодов | ✅ IMPLEMENTED | `assets/content/periods.json` содержит дни 1–5; переходы зависят от действий, не от календаря. |
| Finale после дня 5 | ✅ IMPLEMENTED | Period Summary → `/progress?day=5` → `/finale`. |
| Free Play после Finale | ✅ IMPLEMENTED | «Продолжить с Финни» или отложенный переход через Campaign Complete. Day 6 отсутствует. |

## Home, бюджет и решения

| Требование | Статус | Evidence / граница проверки |
| --- | --- | --- |
| Финни на Home | ✅ IMPLEMENTED | `lib/features/home/`, 27 готовых PNG внешности. |
| Баланс и состояние | ✅ IMPLEMENTED | Home показывает кошелёк, сытость, уход, настроение. |
| Текущая цель | ✅ IMPLEMENTED | Home читает активную цель накоплений. |
| Доступ к действиям и заданию дня | ✅ IMPLEMENTED | Home checkpoints и переходы к Tasks/Savings/Budget. |
| Навигация | ✅ IMPLEMENTED | Пять нижних вкладок; Settings доступен с Home. |
| Бюджет «Нужно», «Хочу», «Копилка» | ✅ IMPLEMENTED | `lib/features/budget/`, `lib/services/budget_service.dart`. |
| Остаток бюджета и редактирование черновика | ✅ IMPLEMENTED | Значения меняются до подтверждения; остаток виден. |
| Подтверждённый план | ✅ IMPLEMENTED | Plan сохраняется для сравнения с Fact. |
| Plan / Fact периода | ✅ IMPLEMENTED | `PeriodService.getSummary`, Period Summary. |
| Нужные и желаемые покупки | ✅ IMPLEMENTED | Категории NEED/WANT в `assets/content/shop_items.json`. |
| Цена и назначение товара | ✅ IMPLEMENTED | Shop card/details показывает цену и описание/эффект. |
| Подтверждение покупки | ✅ IMPLEMENTED | Shop details запрашивает подтверждение перед покупкой. |
| Недостаток средств | ✅ IMPLEMENTED | Core не допускает отрицательный кошелёк; UI показывает недоступность/ошибку. |
| Изменение баланса и транзакция | ✅ IMPLEMENTED | Покупка проходит через service/repository с persisted transaction. |
| Сохраняемый инвентарь | ✅ IMPLEMENTED | SQLite inventory и экран «Вещи». |
| Аксессуары в разных слотах | ✅ IMPLEMENTED | Кепка/head, Бандана/neck, Крылья/back; Home показывает одновременно. |
| Награды целей в комнате | ✅ IMPLEMENTED | Три награды и восемь композитов сочетаний полученных целей. |
| Игрушечные взаимодействия | ✅ IMPLEMENTED | Мяч, фрисби, машинка из «Вещей»; Finny Catch в Free Play. |

## Накопления, задания, последствия и рост

| Требование | Статус | Evidence / граница проверки |
| --- | --- | --- |
| Три цели | ✅ IMPLEMENTED | `assets/content/goals.json`: ночник 400, самокат 600, домик 900. |
| Активная цель, накоплено и осталось | ✅ IMPLEMENTED | Savings UI и `SavingsService`. |
| Пополнение копилки | ✅ IMPLEMENTED | Атомарная операция с persisted proof; правила читаются из Core. |
| Подтверждение достигнутой цели | ✅ IMPLEMENTED | Claim фиксирует completed goal и награду. |
| Не менее шести финансовых заданий | ✅ IMPLEMENTED | Шесть записей в `tasks.json`: дни 1–4 и два задания дня 5. |
| Не менее трёх тем | ✅ IMPLEMENTED | NEED/WANT, приоритеты, адаптация плана, сравнение покупок, самостоятельное планирование. |
| Не только multiple-choice | ✅ IMPLEMENTED | Categorization, budget priority, plan adaptation, shopping trip, independent budget, plan repair. |
| Объяснение после действия | ✅ IMPLEMENTED | Сценарии содержат feedback/successExplanation; UI показывает результат. |
| Исправимые ошибки | ✅ IMPLEMENTED | Задания позволяют повторить решение без потери уже полученного прогресса. |
| Понятные последствия решений | ✅ IMPLEMENTED | Сценарии показывают feedback и объяснение; Period Summary сопоставляет План и Факт. |
| Отсутствие сурового наказания | ✅ IMPLEMENTED | Нет механики смерти или потери питомца за ошибку. Тон текста дополнительно проверить с детьми вручную. |
| Три стадии роста | ✅ IMPLEMENTED | Stage 1/2/3; рост после дней 2 и 5. |
| Не менее девяти визуальных комбинаций | ✅ IMPLEMENTED | 3 стадии × 3 цвета × 3 узора = 27 PNG в `assets/images/finny/`. |

## Постоянный прогресс, помощь и взрослый раздел

| Требование | Статус | Evidence / граница проверки |
| --- | --- | --- |
| Завершённые задания | ✅ IMPLEMENTED | `/progress-overview` читает task progress; Day 5 учитывает оба proof отдельно и legacy-завершение. |
| Текущая цель в «Прогрессе» | ✅ IMPLEMENTED | `SavingsService.loadSnapshot`. |
| План/Факт последнего завершённого периода | ✅ IMPLEMENTED | Последний completed period и `PeriodService.getSummary`; полного архива нет. |
| Финансовый словарь | ✅ IMPLEMENTED | Settings → «Финансовые термины», JSON glossary. |
| Назначение игры и темы обучения для взрослого | ✅ IMPLEMENTED | Adult overview после удержания кнопки. |
| Обзор дней, этапа и накоплений для взрослого | ✅ IMPLEMENTED | `lib/features/adult/`. |
| Сброс игрового прогресса NORMAL | ✅ IMPLEMENTED | Подтверждение; имя профиля и внешность Финни сохраняются. |
| Полное удаление локального профиля | ✅ IMPLEMENTED | Подтверждение и SQLite cascade. |
| Отличие роста от пользовательского «Прогресса» | ✅ IMPLEMENTED | `/progress` — временный growth screen; `/progress-overview` — постоянный раздел Settings. |

## Сохранение и демонстрация

| Требование | Статус | Evidence / граница проверки |
| --- | --- | --- |
| SQLite/local state | ✅ IMPLEMENTED | `lib/core/database/app_database.dart`, schema version **14**. |
| Сохранение профиля, питомца, кошелька, периодов, бюджета, транзакций | ✅ IMPLEMENTED | SQLite repositories и migration tests. |
| Сохранение заданий, копилки, целей, инвентаря и экипировки | ✅ IMPLEMENTED | Соответствующие repositories/services и tests. |
| Campaign lifecycle и Free Play state | ✅ IMPLEMENTED | `CampaignLifecycleRepository`, Free Play repository. |
| Восстановление после перезапуска | ✅ IMPLEMENTED | Persisted state и автоматические restart tests; чистый install/restart на финальном APK — отдельно. |
| Пять дней подряд без календарного ожидания | ✅ IMPLEMENTED | Virtual day progress идёт от действий. |
| Локальный тестовый профиль | ✅ IMPLEMENTED | Обычный NORMAL-профиль; reset/delete доступны в Adult. |
| Демонстрация для эксперта | ✅ IMPLEMENTED | Пять дней проходят подряд; используется обычный локальный профиль с Adult reset/delete. Отдельного пользовательского Demo mode нет; технический тип DEMO существует только внутри архитектуры. |
| JSON-контент | ✅ IMPLEMENTED | Tasks, shop, goals, periods, glossary и специальные ситуации в `assets/content/`. |
| Расширяемость контента | 🟡 PARTIAL / REQUIRES VERIFICATION | Новые записи поддерживаемых схем читаются из JSON; новый тип задания/механика потребует кода и тестов. |

## Android, offline, приватность и доступность

| Требование | Статус | Evidence / граница проверки |
| --- | --- | --- |
| Android package ID | ✅ IMPLEMENTED | `ru.codexteam.finny` в `android/app/build.gradle.kts`. |
| minSdk / compileSdk / targetSdk | ✅ IMPLEMENTED | Gradle использует Flutter SDK. Для установленного Flutter 3.47.4 defaults: **24 / 36 / 36**; итоговый APK проверить отдельно. |
| Работа в portrait | 🟡 PARTIAL / REQUIRES VERIFICATION | Есть widget tests на 360×800 и 393×852. Физический portrait и крупный шрифт — ручная проверка; принудительной блокировки ориентации нет. |
| Лишние production permissions | ✅ IMPLEMENTED | `src/main/AndroidManifest.xml` не запрашивает опасных permissions; INTERNET есть только в debug/profile manifests. |
| Core без backend и сети | ✅ IMPLEMENTED | Локальные SQLite/JSON; сервер для игрового пути не нужен. Offline-install проверить на устройстве. |
| Без аналитики, рекламы и платежей | ✅ IMPLEMENTED | В production-коде и зависимостях репозитория такие SDK/flows не обнаружены. |
| Локальное хранение данных | ✅ IMPLEMENTED | Профиль и игровой прогресс в SQLite. |
| Semantics, labels и прокрутка | 🟡 PARTIAL / REQUIRES VERIFICATION | Во многих экранах есть `Semantics`, tooltip и scroll; сплошной аудит всех элементов не выполнен. |
| Text scaling и touch targets | 🟡 PARTIAL / REQUIRES VERIFICATION | Есть widget tests с масштабом 1.3 и экраны с кнопками ≥48dp; не все интерактивные элементы подтверждены. |
| Диалоги подтверждения | ✅ IMPLEMENTED | Shop и destructive Adult actions требуют явного подтверждения. |
| TalkBack, крупный шрифт, физический overflow | 🔍 MANUAL / RELEASE VERIFICATION | Проверить на финальном устройстве и APK. |
| Анимации и reduced motion | 🔍 MANUAL / RELEASE VERIFICATION | Проверить вручную; автоматических доказательств полной поддержки нет. |

## Release и материалы сдачи

| Требование | Статус | Evidence / следующий шаг |
| --- | --- | --- |
| Внешняя release-подпись в коде | ✅ IMPLEMENTED | `android/key.properties`, keystore вне repo; сборка падает без конфигурации, debug fallback отсутствует. |
| Финальный подписанный release APK | 🔍 MANUAL / RELEASE VERIFICATION | Собрать с командным keystore; в этом аудите артефакт и подпись не проверялись. |
| Сертификат и чистая установка | 🔍 MANUAL / RELEASE VERIFICATION | `apksigner verify`, install и запуск на целевом Android. |
| README | ✅ IMPLEMENTED | Актуализирован по production-коду в этой docs-задаче. |
| Архитектурный документ | 🟡 PARTIAL / REQUIRES VERIFICATION | `docs/ARCHITECTURE.md` существует, но раздел миграций называет schema 12; текущий код — schema 14. Документ вне scope этой задачи. |
| Сценарий демонстрации | ✅ IMPLEMENTED | `docs/DEMO_SCRIPT.md` синхронизирован; live-прогон ещё требуется. |
| Презентация | ❌ MISSING | В repo есть только `docs/PRESENTATION_OUTLINE.md`, готового deck нет. Внешние файлы не проверялись. |
| PDF/DOCX технической документации | ❌ MISSING | Готовые файлы в repo не найдены; внешние материалы не проверялись. |
| Материалы RuStore | ❌ MISSING | Подтверждённый комплект публикации в repo не найден. |
| Скриншоты | ❌ MISSING | Есть `docs/SCREENSHOT_SHOTLIST.md`, готовых submission screenshots в repo нет. |
| Иконка приложения | 🟡 PARTIAL / REQUIRES VERIFICATION | `ic_launcher.png` присутствует в Android resources; финальную графику и store-иконку проверить вручную. |
| Backup video ≤3 минут | ❌ MISSING | Готовое видео в repo не найдено; сценарий записи описан в DEMO_SCRIPT. |
| Release tag | ❌ MISSING | В локальном Git на дату аудита теги отсутствуют; remote/submission проверить отдельно. |
| Доступные ссылки на материалы | 🔍 MANUAL / RELEASE VERIFICATION | Проверить после подготовки внешних артефактов и публикации. |

## Автоматическая проверка текущего main

Это **количество Flutter-тестов**, а не число строк матрицы или процент
выполнения требований: `flutter test --no-pub --concurrency=1` — **714 passed**
на указанном main. `flutter analyze --no-pub` — **No issues found** на
документационной ветке. Ручная проверка
подписанного APK, TalkBack и физических устройств этим результатом не заменена.
