import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/budget/budget_controller.dart';
import 'package:finny/features/budget/budget_screen.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/features/home/home_visual_components.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/day_lifecycle_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_content_repository.dart';
import 'helpers/test_database.dart';

class _ActiveProfileController extends ActiveProfileIdController {
  _ActiveProfileController(this.profileId);

  final int? profileId;

  @override
  int? build() => profileId;
}

class _AmbiguousPeriodService extends PeriodService {
  _AmbiguousPeriodService(super.games, super.content);

  @override
  Future<GamePeriod?> startNextPeriod({required int profileId}) async {
    await super.startNextPeriod(profileId: profileId);
    throw StateError('Result was lost after commit.');
  }
}

class _FailingReadsGameRepository extends SqliteGameRepository {
  _FailingReadsGameRepository(super.database);

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async {
    throw StateError('read failed');
  }
}

class _ControlledBudgetService extends BudgetService {
  _ControlledBudgetService(super.games);

  bool failSave = false;
  bool throwAfterSave = false;
  bool throwAfterConfirm = false;
  Duration delay = Duration.zero;
  int activeSaves = 0;
  int maximumConcurrentSaves = 0;

  @override
  Future<GamePeriod> saveDraft({
    required int profileId,
    required int periodId,
    required BudgetAllocation allocation,
  }) async {
    activeSaves++;
    maximumConcurrentSaves = mathMax(maximumConcurrentSaves, activeSaves);
    try {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      if (failSave) throw StateError('save failed');
      final result = await super.saveDraft(
        profileId: profileId,
        periodId: periodId,
        allocation: allocation,
      );
      if (throwAfterSave) throw StateError('result lost');
      return result;
    } finally {
      activeSaves--;
    }
  }

  @override
  Future<GamePeriod> confirmPlan({
    required int profileId,
    required int periodId,
  }) async {
    final result = await super.confirmPlan(
      profileId: profileId,
      periodId: periodId,
    );
    if (throwAfterConfirm) throw StateError('result lost');
    return result;
  }
}

int mathMax(int first, int second) => first > second ? first : second;

class _Harness {
  _Harness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

Future<_Harness> _pumpFeature(
  WidgetTester tester, {
  required AppDatabase database,
  required int? profileId,
  required ProfileRepository profiles,
  required GameRepository games,
  required ContentRepository content,
  String initialLocation = '/home',
  PeriodService? periods,
  BudgetService? budgets,
}) async {
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      activeProfileIdProvider.overrideWith(
        () => _ActiveProfileController(profileId),
      ),
      profileRepositoryProvider.overrideWithValue(profiles),
      gameRepositoryProvider.overrideWithValue(games),
      contentRepositoryProvider.overrideWithValue(content),
      if (periods != null) periodServiceProvider.overrideWithValue(periods),
      if (budgets != null) budgetServiceProvider.overrideWithValue(budgets),
    ],
  );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/budget', builder: (_, _) => const BudgetScreen()),
      GoRoute(
        path: '/startup',
        builder: (_, _) => const Scaffold(body: Text('Startup route')),
      ),
    ],
  );
  addTearDown(() {
    router.dispose();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  for (var attempt = 0; attempt < 5000; attempt++) {
    final loading = initialLocation == '/budget'
        ? container.read(budgetControllerProvider) is BudgetLoading
        : container.read(homeControllerProvider) is HomeLoading;
    if (!loading) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
  }
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return _Harness(container, router);
}

Future<void> _settleFeature(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // Alternate real event-loop turns with widget pumps: a screen action can
  // perform several consecutive sqflite_ffi calls and then navigate to the
  // other feature, whose initial read must settle as well.
  for (var attempt = 0; attempt < 500; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump();
    final budgetVisible = find.byType(BudgetScreen).evaluate().isNotEmpty;
    final busy = budgetVisible
        ? switch (container.read(budgetControllerProvider)) {
            BudgetLoading() => true,
            BudgetReady(:final saving, :final confirming) =>
              saving || confirming,
            _ => false,
          }
        : switch (container.read(homeControllerProvider)) {
            HomeLoading() => true,
            HomeReady(:final startingDay) => startingDay,
            _ => false,
          };
    if (!busy) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      break;
    }
  }
  await tester.pumpAndSettle();
}

Future<Profile> _createPlayer(
  SqliteProfileRepository profiles,
  SqliteGameRepository games, {
  ProfileType type = ProfileType.normal,
  int wallet = 0,
  int savings = 0,
  String petName = 'Финни',
  int satiety = 100,
  int care = 100,
  int mood = 100,
}) async {
  final profile = await profiles.create(
    Profile(
      gameName: type == ProfileType.normal ? 'Игрок' : 'Демо',
      profileType: type,
      onboardingCompleted: true,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
  await games.createInitialState(
    GameState(
      profileId: profile.id!,
      walletBalance: wallet,
      currentPeriod: 0,
      savedAmount: savings,
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  );
  await games.savePet(
    Pet(
      profileId: profile.id!,
      name: petName,
      colorId: 'purple',
      patternId: 'spots',
      developmentStage: 1,
      growthPoints: 0,
      satiety: satiety,
      care: care,
      mood: mood,
    ),
  );
  return profile;
}

List<PeriodDefinition> _definitions({int income = 500}) => [
  PeriodDefinition(
    id: 'period_1',
    number: 1,
    title: 'Нужно или хочется?',
    baseIncome: income,
    requiredCheckpoints: const ['financial_task', 'savings_decision'],
  ),
];

Future<GamePeriod> _startPlanning(
  int profileId,
  SqliteGameRepository games,
  ContentRepository content,
) async => (await PeriodService(
  games,
  content,
).startNextPeriod(profileId: profileId))!;

Future<GamePeriod> _resolveAll(
  int profileId,
  GamePeriod period,
  PeriodService service,
  GameRepository games,
  AppDatabase database,
  ContentRepository content,
) async {
  var current = period;
  for (final checkpoint in current.requiredCheckpoints) {
    current = checkpoint == 'financial_task'
        ? (await TaskService(
                    games,
                    SqliteTaskCompletionPort(database),
                    content,
                  ).submitAnswer(
                    profileId: profileId,
                    periodId: period.id!,
                    taskId: 'task_period_1',
                    answerId: 'apple',
                  )
                  as TaskAnswerCompleted)
              .period
        : await resolveCheckpointForTest(
            database,
            profileId: profileId,
            periodId: period.id!,
            checkpointId: checkpoint,
          );
  }
  return current;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late TestContentRepository content;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    content = TestContentRepository(_definitions());
  });

  tearDown(() => database.close());

  testWidgets('Home renders every period state with real Pet and wallet', (
    tester,
  ) async {
    final profile = (await tester.runAsync(
      () => _createPlayer(profiles, games, wallet: 40, petName: 'Пушок'),
    ))!;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
    );

    expect(find.text('Первый день'), findsOneWidget);
    expect(find.text('Начать день'), findsOneWidget);
    expect(tester.widget<HomeWallet>(find.byType(HomeWallet)).balance, 40);
    expect(find.text('Пушок'), findsOneWidget);

    var period = (await tester.runAsync(
      () => _startPlanning(profile.id!, games, content),
    ))!;
    await tester.runAsync(
      harness.container.read(homeControllerProvider.notifier).load,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-required-actions')), findsOneWidget);
    expect(find.text('Продолжить план'), findsOneWidget);

    period = (await tester.runAsync(
      () => confirmPlanForTest(
        BudgetService(games),
        profileId: profile.id!,
        periodId: period.id!,
      ),
    ))!;
    await tester.runAsync(
      harness.container.read(homeControllerProvider.notifier).load,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-required-actions')), findsOneWidget);
    expect(find.text('Выполнить задание'), findsOneWidget);

    final periods = PeriodService(games, content);
    period = (await tester.runAsync(
      () => _resolveAll(profile.id!, period, periods, games, database, content),
    ))!;
    await tester.runAsync(() async {
      final db = await database.database;
      await db.update(
        'game_periods',
        {'day_progress': 76},
        where: 'id = ?',
        whereArgs: [period.id],
      );
    });
    await tester.runAsync(
      harness.container.read(homeControllerProvider.notifier).load,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-required-actions')), findsOneWidget);
    expect(find.byKey(const Key('home-finish-day')), findsOneWidget);

    await tester.runAsync(
      () => completePeriodForTest(
        database,
        profileId: profile.id!,
        periodId: period.id!,
      ),
    );
    await tester.runAsync(
      harness.container.read(homeControllerProvider.notifier).load,
    );
    await tester.pumpAndSettle();
    expect(find.text('Все 5 дней завершены • Финни — этап 1'), findsOneWidget);
  });

  testWidgets(
    'Start Day uses real income, carry-over, blocks double tap and survives restart',
    (tester) async {
      content = TestContentRepository(_definitions(income: 375));
      final profile = (await tester.runAsync(
        () => _createPlayer(profiles, games, wallet: 125),
      ))!;
      final harness = await _pumpFeature(
        tester,
        profileId: profile.id,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
      );

      final start = find.byKey(const Key('home-start-day'));
      await tester.tap(start);
      await tester.tap(start);
      await _settleFeature(tester, harness.container);

      expect(find.text('Новый день начался!'), findsOneWidget);
      expect(find.text('Ты получил 375 🪙'), findsOneWidget);
      expect(find.textContaining('Сначала составь план'), findsOneWidget);
      final persisted = (await tester.runAsync(
        () async => (
          await games.getPeriods(profile.id!),
          await games.getTransactions(profile.id!),
          await games.getGameState(profile.id!),
        ),
      ))!;
      expect(persisted.$1, hasLength(1));
      expect(persisted.$2, hasLength(1));
      expect(persisted.$3?.walletBalance, 500);

      Navigator.of(tester.element(find.text('Новый день начался!'))).pop();
      await tester.pumpAndSettle();
      await _pumpFeature(
        tester,
        profileId: profile.id,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
      );
      expect(find.text('Новый день начался!'), findsNothing);
      expect(find.text('Продолжить план'), findsOneWidget);
      expect(
        await tester.runAsync(() => games.getTransactions(profile.id!)),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'completed Day 1 enters Day 2 without first-day state or repeated morning',
    (tester) async {
      content = TestContentRepository(
        testPeriodDefinitions(count: 3),
        stories: const [
          StoryPurchase(
            id: 'day3_bowl_replacement',
            name: 'Новая миска',
            period: 3,
            price: 120,
            category: ShopItemCategory.need,
            checkpoint: 'changed_circumstance',
          ),
        ],
      );
      final profile = (await tester.runAsync(
        () => _createPlayer(
          profiles,
          games,
          satiety: PetStateRules.dayOneInitialSatiety,
          care: PetStateRules.dayOneInitialCare,
          mood: PetStateRules.dayOneInitialMood,
        ),
      ))!;
      final periods = PeriodService(games, content);
      final budgets = BudgetService(games);
      final lifecycle = DayLifecycleService(
        SqliteDayLifecyclePort(database),
        content,
      );

      var day1 = (await tester.runAsync(
        () => periods.startNextPeriod(profileId: profile.id!),
      ))!;
      day1 = (await tester.runAsync(
        () => confirmPlanForTest(
          budgets,
          profileId: profile.id!,
          periodId: day1.id!,
        ),
      ))!;
      await tester.runAsync(() async {
        for (final checkpoint in day1.requiredCheckpoints) {
          day1 = await resolveCheckpointForTest(
            database,
            profileId: profile.id!,
            periodId: day1.id!,
            checkpointId: checkpoint,
          );
        }
        await (await database.database).update(
          'game_periods',
          {'day_progress': 76},
          where: 'id = ?',
          whereArgs: [day1.id],
        );
      });
      final day1Evening = (await tester.runAsync(
        () async =>
            (await games.getPet(profile.id!))!
                .copyWith(satiety: 80, care: 78, mood: 60),
      ))!;
      await tester.runAsync(() => games.savePet(day1Evening));
      final completedDay1 = (await tester.runAsync(
        () => lifecycle.sleep(
          profileId: profile.id!,
          periodId: day1.id!,
          allowFallback: true,
        ),
      ))!;
      final summary = (await tester.runAsync(
        () => periods.getSummary(profileId: profile.id!, periodId: day1.id!),
      ))!;
      expect(completedDay1.period.status, GamePeriodStatus.completed);
      expect(summary.factRemainder, completedDay1.period.endWalletBalance);

      final harness = await _pumpFeature(
        tester,
        profileId: profile.id,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
      );
      expect(find.text('Первый день с Финни'), findsNothing);
      expect(find.byKey(const Key('home-day-status')), findsNothing);
      expect(find.text('Начать следующий день'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-start-day')));
      await _settleFeature(tester, harness.container);
      final day2State = harness.container.read(homeControllerProvider);
      expect(day2State, isA<HomeReady>());
      expect((day2State as HomeReady).period?.periodNumber, 2);
      expect(day2State.completedDays, 1);
      final afterDay2Start = (await tester.runAsync(
        () async => (
          await games.getPeriods(profile.id!),
          await games.getGameState(profile.id!),
          await games.getPet(profile.id!),
        ),
      ))!;
      expect(afterDay2Start.$1.first.status, GamePeriodStatus.completed);
      expect(afterDay2Start.$1.last.periodNumber, 2);
      expect(afterDay2Start.$2?.currentPeriod, 2);
      expect(
        [
          afterDay2Start.$3?.satiety,
          afterDay2Start.$3?.care,
          afterDay2Start.$3?.mood,
        ],
        [40, 39, 35],
      );

      Navigator.of(tester.element(find.text('Новый день начался!'))).pop();
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final controller = harness.container.read(
          homeControllerProvider.notifier,
        );
        await controller.load();
        await controller.load();
        await expectLater(
          periods.startNextPeriod(profileId: profile.id!),
          throwsStateError,
        );
      });
      final afterReload = (await tester.runAsync(
        () => games.getPet(profile.id!),
      ))!;
      expect(
        [afterReload.satiety, afterReload.care, afterReload.mood],
        [40, 39, 35],
      );

      var day2 = (await tester.runAsync(
        () => games.getCurrentPeriod(profile.id!),
      ))!;
      day2 = (await tester.runAsync(
        () => confirmPlanForTest(
          budgets,
          profileId: profile.id!,
          periodId: day2.id!,
        ),
      ))!;
      await tester.runAsync(() async {
        for (final checkpoint in day2.requiredCheckpoints) {
          day2 = await resolveCheckpointForTest(
            database,
            profileId: profile.id!,
            periodId: day2.id!,
            checkpointId: checkpoint,
          );
        }
        await (await database.database).update(
          'game_periods',
          {'day_progress': 76},
          where: 'id = ?',
          whereArgs: [day2.id],
        );
        await games.savePet(
          (await games.getPet(profile.id!))!
              .copyWith(satiety: 90, care: 70, mood: 100),
        );
        await lifecycle.sleep(
          profileId: profile.id!,
          periodId: day2.id!,
          allowFallback: false,
        );
        await harness.container.read(homeControllerProvider.notifier).load();
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-day-status')), findsNothing);
      expect(find.text('Начать следующий день'), findsOneWidget);

      final day3 = (await tester.runAsync(
        harness.container.read(homeControllerProvider.notifier).startDay,
      ))!;
      expect(day3.periodNumber, 3);
      final day3Morning = (await tester.runAsync(
        () => games.getPet(profile.id!),
      ))!;
      expect(
        [day3Morning.satiety, day3Morning.care, day3Morning.mood],
        [40, 35, 40],
      );
      await tester.runAsync(
        harness.container.read(homeControllerProvider.notifier).load,
      );
      final afterDay3Reload = (await tester.runAsync(
        () => games.getPet(profile.id!),
      ))!;
      expect(
        [afterDay3Reload.satiety, afterDay3Reload.care, afterDay3Reload.mood],
        [40, 35, 40],
      );
    },
  );

  testWidgets('ambiguous Start Day rereads persistence before retry', (
    tester,
  ) async {
    final profile = (await tester.runAsync(
      () => _createPlayer(profiles, games),
    ))!;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      periods: _AmbiguousPeriodService(games, content),
    );

    await tester.tap(find.byKey(const Key('home-start-day')));
    await _settleFeature(tester, harness.container);

    expect(find.text('Новый день начался!'), findsOneWidget);
    final persisted = (await tester.runAsync(
      () async => (
        await games.getPeriods(profile.id!),
        await games.getTransactions(profile.id!),
      ),
    ))!;
    expect(persisted.$1, hasLength(1));
    expect(persisted.$2, hasLength(1));
    expect(find.textContaining('Не получилось начать'), findsNothing);
  });

  testWidgets('critical Home repository error is not an empty state', (
    tester,
  ) async {
    final profile = (await tester.runAsync(
      () => _createPlayer(profiles, games),
    ))!;
    final failing = _FailingReadsGameRepository(database);
    await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: failing,
      content: content,
      database: database,
    );

    expect(find.text('Не получилось открыть дом Финни.'), findsOneWidget);
    expect(find.text('Начать день'), findsNothing);
  });

  testWidgets('missing Pet returns to bootstrap instead of creating a fake', (
    tester,
  ) async {
    final profile = (await tester.runAsync(() async {
      final created = await profiles.create(
        Profile(
          gameName: 'Игрок',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await games.ensureInitialState(created.id!);
      return created;
    }))!;
    await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
    );
    expect(find.text('Startup route'), findsOneWidget);
    expect(
      await tester.runAsync<Pet?>(() => games.getPet(profile.id!)),
      isNull,
    );
  });

  testWidgets(
    'Budget restores non-multiple draft, constrains controls and autosaves',
    (tester) async {
      final setup = (await tester.runAsync(() async {
        final profile = await _createPlayer(profiles, games, wallet: 125);
        final period = await _startPlanning(profile.id!, games, content);
        await BudgetService(games).saveDraft(
          profileId: profile.id!,
          periodId: period.id!,
          allocation: const BudgetAllocation(need: 105, want: 200, savings: 95),
        );
        return (profile, period);
      }))!;
      final profile = setup.$1;
      final period = setup.$2;
      final harness = await _pumpFeature(
        tester,
        profileId: profile.id,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
        initialLocation: '/budget',
      );

      expect(find.text('105 🪙'), findsOneWidget);
      expect(find.text('200 🪙'), findsOneWidget);
      expect(find.text('95 🪙'), findsOneWidget);
      expect(find.text('225 🪙'), findsOneWidget);
      expect(find.text('Осталось с прошлого дня'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('625'), findsOneWidget);

      final plus = find.byKey(const Key('budget-plus-Нужно Финни'));
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await _settleFeature(tester, harness.container);
      GamePeriod? persisted = await tester.runAsync<GamePeriod?>(
        () => games.getPeriodById(profile.id!, period.id!),
      );
      expect(persisted?.plannedNeed, 115);

      final controller = harness.container.read(
        budgetControllerProvider.notifier,
      );
      final ready =
          harness.container.read(budgetControllerProvider) as BudgetReady;
      expect(controller.maximumFor(ready, BudgetCategory.need), 330);
      controller.previewValue(BudgetCategory.need, 331);
      expect(
        (harness.container.read(
          budgetControllerProvider,
        ) as BudgetReady).draft.need,
        115,
      );

      final slider = find.byKey(const Key('budget-slider-Нужно Финни'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(800, 0));
      await _settleFeature(tester, harness.container);
      persisted = await tester.runAsync<GamePeriod?>(
        () => games.getPeriodById(profile.id!, period.id!),
      );
      expect(persisted?.plannedNeed, 330);
      expect(persisted!.plannedTotal, persisted.startingBudget);
      expect(persisted.plannedFree, 0);
    },
  );

  testWidgets('remaining amount below step can be allocated in full', (
    tester,
  ) async {
    final setup = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      final period = await _startPlanning(profile.id!, games, content);
      await BudgetService(games).saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: 495, want: 0, savings: 0),
      );
      return (profile, period);
    }))!;
    final profile = setup.$1;
    final period = setup.$2;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      initialLocation: '/budget',
    );

    final plus = find.byKey(const Key('budget-plus-Нужно Финни'));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await _settleFeature(tester, harness.container);

    final persisted = await tester.runAsync<GamePeriod?>(
      () => games.getPeriodById(profile.id!, period.id!),
    );
    expect(persisted?.plannedNeed, 500);
    expect(persisted?.plannedFree, 0);
  });

  test('rapid draft changes are serialized and newest value wins', () async {
    final profile = await _createPlayer(profiles, games);
    final period = await _startPlanning(profile.id!, games, content);
    final controlled = _ControlledBudgetService(games)
      ..delay = const Duration(milliseconds: 20);
    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWith(
          () => _ActiveProfileController(profile.id),
        ),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        budgetServiceProvider.overrideWithValue(controlled),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(budgetControllerProvider.notifier);
    await controller.load();

    final saves = [
      controller.setValue(BudgetCategory.need, 110),
      controller.setValue(BudgetCategory.need, 120),
      controller.setValue(BudgetCategory.need, 130),
    ];
    await Future.wait(saves);

    expect(controlled.maximumConcurrentSaves, 1);
    expect(
      (await games.getPeriodById(profile.id!, period.id!))?.plannedNeed,
      130,
    );
    final state = container.read(budgetControllerProvider) as BudgetReady;
    expect(state.draft.need, 130);
    expect(state.persistedDraft.need, 130);
    expect(state.saving, isFalse);
    expect(state.saveFailed, isFalse);
  });

  testWidgets(
    'Back waits for pending autosave and reopened Budget restores it',
    (tester) async {
      final setup = (await tester.runAsync(() async {
        final profile = await _createPlayer(profiles, games);
        final period = await _startPlanning(profile.id!, games, content);
        return (profile, period);
      }))!;
      final profile = setup.$1;
      final period = setup.$2;
      final controlled = _ControlledBudgetService(games)
        ..delay = const Duration(milliseconds: 80);
      final harness = await _pumpFeature(
        tester,
        profileId: profile.id,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
        initialLocation: '/budget',
        budgets: controlled,
      );

      final plus = find.byKey(const Key('budget-plus-Нужно Финни'));
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.tap(find.byType(BackButton));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byType(BudgetScreen), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await _settleFeature(tester, harness.container);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        (await tester.runAsync<GamePeriod?>(
          () => games.getPeriodById(profile.id!, period.id!),
        ))?.plannedNeed,
        10,
      );

      await tester.tap(find.text('Продолжить план'));
      await _settleFeature(tester, harness.container);
      expect(find.text('10 🪙'), findsOneWidget);
    },
  );

  testWidgets('draft survives a new ProviderContainer restart', (tester) async {
    final profile = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      final period = await _startPlanning(profile.id!, games, content);
      await BudgetService(games).saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: 200, want: 100, savings: 100),
      );
      return profile;
    }))!;
    await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      initialLocation: '/budget',
    );
    expect(find.text('200 🪙'), findsOneWidget);

    await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      initialLocation: '/budget',
    );
    expect(find.text('200 🪙'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('budget-editor-want')),
        matching: find.text('100 🪙'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('budget-editor-savings')),
        matching: find.text('100 🪙'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('save error is friendly, disables confirm and can retry', (
    tester,
  ) async {
    final setup = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      final period = await _startPlanning(profile.id!, games, content);
      return (profile, period);
    }))!;
    final profile = setup.$1;
    final period = setup.$2;
    final controlled = _ControlledBudgetService(games)..failSave = true;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      initialLocation: '/budget',
      budgets: controlled,
    );

    final plus = find.byKey(const Key('budget-plus-Нужно Финни'));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await _settleFeature(tester, harness.container);
    expect(find.text('Не получилось сохранить изменение'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('budget-confirm')))
          .onPressed,
      isNull,
    );
    expect(
      (await tester.runAsync<GamePeriod?>(
        () => games.getPeriodById(profile.id!, period.id!),
      ))?.plannedNeed,
      0,
    );

    controlled.failSave = false;
    final retry = find.text('Повторить');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await _settleFeature(tester, harness.container);
    expect(find.text('Не получилось сохранить изменение'), findsNothing);
    expect(
      (await tester.runAsync<GamePeriod?>(
        () => games.getPeriodById(profile.id!, period.id!),
      ))?.plannedNeed,
      10,
    );
  });

  testWidgets('ambiguous draft save uses persisted result', (tester) async {
    final setup = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      final period = await _startPlanning(profile.id!, games, content);
      return (profile, period);
    }))!;
    final profile = setup.$1;
    final period = setup.$2;
    final controlled = _ControlledBudgetService(games)..throwAfterSave = true;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      initialLocation: '/budget',
      budgets: controlled,
    );

    final plus = find.byKey(const Key('budget-plus-Нужно Финни'));
    await tester.ensureVisible(plus);
    await tester.tap(plus);
    await _settleFeature(tester, harness.container);

    expect(
      (await tester.runAsync<GamePeriod?>(
        () => games.getPeriodById(profile.id!, period.id!),
      ))?.plannedNeed,
      10,
    );
    expect(find.text('Не получилось сохранить изменение'), findsNothing);
  });

  testWidgets(
    'confirm stays disabled until every budget category has 10 coins',
    (tester) async {
      final setup = (await tester.runAsync(() async {
        final profile = await _createPlayer(profiles, games, savings: 17);
        final period = await _startPlanning(profile.id!, games, content);
        return (profile, period);
      }))!;
      final profile = setup.$1;
      final period = setup.$2;
      final harness = await _pumpFeature(
        tester,
        profileId: profile.id,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
        initialLocation: '/budget',
      );

      final confirm = find.byKey(const Key('budget-confirm'));
      await tester.ensureVisible(confirm);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(find.text('Всё готово?'), findsNothing);
      expect(find.textContaining('минимум'), findsNothing);

      for (final category in ['Нужно Финни', 'Хочется Финни', 'Копилка']) {
        final plus = find.byKey(Key('budget-plus-$category'));
        await tester.ensureVisible(plus);
        await tester.tap(plus);
        await _settleFeature(tester, harness.container);
      }

      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      await tester.tap(confirm);
      await _settleFeature(tester, harness.container);
      expect(find.text('Всё готово?'), findsOneWidget);
      expect(find.text('Останется'), findsOneWidget);
      expect(find.text('470'), findsOneWidget);
      await tester.tap(find.byKey(const Key('budget-confirm-sheet')));
      await _settleFeature(tester, harness.container);

      final persistedState = (await tester.runAsync(
        () async => (
          await games.getPeriodById(profile.id!, period.id!),
          await games.getGameState(profile.id!),
        ),
      ))!;
      final persisted = persistedState.$1;
      final gameState = persistedState.$2;
      expect(persisted?.status, GamePeriodStatus.active);
      expect(gameState?.walletBalance, 500);
      expect(gameState?.savedAmount, 17);
      expect(find.byType(HomeScreen), findsOneWidget);

      harness.router.go('/budget');
      await _settleFeature(tester, harness.container);
      expect(find.text('Твой план'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
      expect(
        find.text('План подтверждён. Изменить его уже нельзя.'),
        findsOneWidget,
      );
      final immutable = await tester.runAsync(() async {
        try {
          await BudgetService(games).saveDraft(
            profileId: profile.id!,
            periodId: period.id!,
            allocation: const BudgetAllocation(need: 10, want: 0, savings: 0),
          );
          return false;
        } on StateError {
          return true;
        }
      });
      expect(immutable, isTrue);
    },
  );

  testWidgets('ambiguous confirm rereads active period and returns Home', (
    tester,
  ) async {
    final setup = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      final period = await _startPlanning(profile.id!, games, content);
      await BudgetService(games).saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: 10, want: 10, savings: 10),
      );
      return (profile, period);
    }))!;
    final profile = setup.$1;
    final period = setup.$2;
    final controlled = _ControlledBudgetService(games)
      ..throwAfterConfirm = true;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
      initialLocation: '/budget',
      budgets: controlled,
    );

    final confirm = find.byKey(const Key('budget-confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await _settleFeature(tester, harness.container);
    await tester.tap(find.byKey(const Key('budget-confirm-sheet')));
    await _settleFeature(tester, harness.container);

    expect(
      (await tester.runAsync<GamePeriod?>(
        () => games.getPeriodById(profile.id!, period.id!),
      ))?.status,
      GamePeriodStatus.active,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Не получилось подтвердить'), findsNothing);
  });

  testWidgets('additional income changes Home wallet but not confirmed plan', (
    tester,
  ) async {
    final profile = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      final period = await _startPlanning(profile.id!, games, content);
      await BudgetService(games).saveDraft(
        profileId: profile.id!,
        periodId: period.id!,
        allocation: const BudgetAllocation(need: 200, want: 100, savings: 100),
      );
      await BudgetService(games)
          .confirmPlan(profileId: profile.id!, periodId: period.id!);
      await PeriodService(games, content).addExplicitIncome(
        profileId: profile.id!,
        periodId: period.id!,
        amount: 50,
        operationId: 'extra-50',
        source: 'test',
        description: 'Дополнительный доход',
      );
      return profile;
    }))!;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
    );
    expect(tester.widget<HomeWallet>(find.byType(HomeWallet)).balance, 550);
    harness.router.go('/budget');
    await _settleFeature(tester, harness.container);
    expect(find.text('200 🪙'), findsOneWidget);
    expect(find.text('100 🪙'), findsNWidgets(3));
    expect(find.text('500'), findsOneWidget);
  });

  test('Budget changes stay isolated from DEMO profile', () async {
    final normal = await _createPlayer(profiles, games);
    final demo = await _createPlayer(
      profiles,
      games,
      type: ProfileType.demo,
      wallet: 75,
    );
    final normalPeriod = await _startPlanning(normal.id!, games, content);
    final demoPeriod = await _startPlanning(demo.id!, games, content);
    final container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWith(
          () => _ActiveProfileController(normal.id),
        ),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(budgetControllerProvider.notifier);
    await controller.load();
    await controller.setValue(BudgetCategory.need, 80);

    expect(
      (await games.getPeriodById(normal.id!, normalPeriod.id!))?.plannedNeed,
      80,
    );
    expect(
      (await games.getPeriodById(demo.id!, demoPeriod.id!))?.plannedNeed,
      0,
    );
    expect((await games.getGameState(demo.id!))?.walletBalance, 575);
  });

  testWidgets('Home and Budget fit 360dp with reasonable text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final profile = (await tester.runAsync(() async {
      final profile = await _createPlayer(profiles, games);
      await _startPlanning(profile.id!, games, content);
      return profile;
    }))!;
    final harness = await _pumpFeature(
      tester,
      profileId: profile.id,
      profiles: profiles,
      games: games,
      content: content,
      database: database,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Продолжить план'));
    await _settleFeature(tester, harness.container);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('budget-confirm')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'postponed bowl remains visible between days and after campaign',
    (tester) async {
      final definitions = testPeriodDefinitions(count: 5);
      definitions[2] = PeriodDefinition(
        id: 'period_3',
        number: 3,
        title: 'Период 3',
        baseIncome: 500,
        requiredCheckpoints: const [
          'financial_task',
          'savings_decision',
          'changed_circumstance',
        ],
      );
      content = TestContentRepository(
        definitions,
        stories: const [
          StoryPurchase(
            id: 'day3_bowl_replacement',
            name: 'Новая миска',
            period: 3,
            price: 120,
            category: ShopItemCategory.need,
            checkpoint: 'changed_circumstance',
          ),
        ],
      );
      final profile = (await tester.runAsync(
        () => _createPlayer(profiles, games),
      ))!;
      final profileId = profile.id!;

      Future<GamePeriod> start(int number) => games.startPeriod(
        profileId: profileId,
        definitionId: 'period_$number',
        periodNumber: number,
        baseIncome: 500,
        requiredCheckpoints: definitions[number - 1].requiredCheckpoints,
        createdAt: DateTime.utc(2026, 1, number),
      );

      Future<void> finish(GamePeriod period) async {
        final active = await confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: period.id!,
        );
        for (final checkpoint in active.requiredCheckpoints) {
          await resolveCheckpointForTest(
            database,
            profileId: profileId,
            periodId: period.id!,
            checkpointId: checkpoint,
          );
        }
        await completePeriodForTest(
          database,
          profileId: profileId,
          periodId: period.id!,
        );
      }

      await tester.runAsync(() async {
        await finish(await start(1));
        await finish(await start(2));
        final day3 = await start(3);
        final db = await database.database;
        await db.insert('campaign_story_events', {
          'profile_id': profileId,
          'story_id': 'day3_bowl_replacement',
          'origin_period_id': day3.id,
          'threshold': 1,
          'status': 'postponed',
          'armed_at': DateTime.utc(2026, 1, 3).toIso8601String(),
          'postponed_at': DateTime.utc(2026, 1, 3).toIso8601String(),
          'purchased_at': null,
          'decision_operation_id': 'postponed-day3',
          'decision_kind': 'postpone',
          'purchase_period_id': null,
          'savings_used': 0,
        });
        await finish(day3);
      });
      expect(
        await tester.runAsync(() => games.getCurrentPeriod(profileId)),
        isNull,
      );

      final harness = await _pumpFeature(
        tester,
        profileId: profileId,
        profiles: profiles,
        games: games,
        content: content,
        database: database,
      );

      Future<void> reload() async {
        await tester.runAsync(
          harness.container.read(homeControllerProvider.notifier).load,
        );
        await _settleFeature(tester, harness.container);
      }

      void expectCard({required bool enabled, required String message}) {
        final state =
            harness.container.read(homeControllerProvider) as HomeReady;
        expect(state.bowlEvent?.isOutstanding, isTrue);
        expect(find.byKey(const Key('home-bowl-obligation')), findsOneWidget);
        expect(
          tester
                  .widget<TextButton>(
                    find.byKey(const Key('home-bowl-purchase')),
                  )
                  .onPressed !=
              null,
          enabled,
        );
        if (!enabled) expect(find.text(message), findsOneWidget);
      }

      expectCard(
        enabled: false,
        message: 'Купить можно после начала следующего дня.',
      );
      await tester.runAsync(() => start(4));
      await reload();
      expectCard(
        enabled: false,
        message: 'Купить можно после подтверждения плана дня.',
      );
      final day4 = (await tester.runAsync(
        () => games.getCurrentPeriod(profileId),
      ))!;
      await tester.runAsync(
        () => confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: day4.id!,
        ),
      );
      await reload();
      expectCard(enabled: true, message: '');
      expect(find.byKey(const Key('home-required-actions')), findsOneWidget);

      await tester.runAsync(() async {
        for (final checkpoint in day4.requiredCheckpoints) {
          await resolveCheckpointForTest(
            database,
            profileId: profileId,
            periodId: day4.id!,
            checkpointId: checkpoint,
          );
        }
        await completePeriodForTest(
          database,
          profileId: profileId,
          periodId: day4.id!,
        );
      });
      await reload();
      expectCard(
        enabled: false,
        message: 'Купить можно после начала следующего дня.',
      );
      await tester.runAsync(() async => finish(await start(5)));
      await reload();
      expect(
        (harness.container.read(
          homeControllerProvider,
        ) as HomeReady).allDaysCompleted,
        isTrue,
      );
      expectCard(
        enabled: false,
        message: 'Кампания завершена. Покупка осталась отложенной.',
      );
    },
  );
}
