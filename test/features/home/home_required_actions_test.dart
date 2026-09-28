import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/core/visual/finny_modal_actions.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/home/finny_sleep_dialog.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

class _TestProfileId extends ActiveProfileIdController {
  _TestProfileId(this.profileId);

  final int profileId;

  @override
  int? build() => profileId;
}

class _HomeFixture {
  _HomeFixture(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 300; attempt++) {
      if (finder.evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3)),
      );
      await tester.pump();
    }
    expect(finder, findsOneWidget);
    await tester.pumpAndSettle();
  }

  Future<_HomeFixture> mountHome(
    WidgetTester tester, {
    List<String> required = const ['financial_task', 'savings_decision'],
    List<String> resolved = const [],
    bool planning = false,
    bool bedtime = false,
    int day = 1,
    bool legacyDayFiveCompleted = false,
    Size size = const Size(360, 800),
    int petSatiety = 80,
    int walletBalance = 1000,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = createTestDatabase();
    final games = SqliteGameRepository(database);
    final profiles = SqliteProfileRepository(database);
    final profile = await tester.runAsync(
      () => profiles.create(
        Profile(
          gameName: 'Игрок',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      ),
    );
    final profileId = profile!.id!;
    await tester.runAsync(() async {
      await games.ensureInitialState(profileId);
      await games.savePet(
        Pet(
          profileId: profileId,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'plain',
          developmentStage: 1,
          growthPoints: 0,
          satiety: petSatiety,
          care: 80,
          mood: 80,
        ),
      );
      final started = await games.startPeriod(
        profileId: profileId,
        definitionId: day == 5 ? 'period_5_independent' : 'period_1',
        periodNumber: day,
        baseIncome: 500,
        requiredCheckpoints: required,
        createdAt: DateTime.utc(2026),
      );
      if (!planning) {
        await confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: started.id!,
        );
      }
      for (final checkpoint in resolved) {
        await resolveCheckpointForTest(
          database,
          profileId: profileId,
          periodId: started.id!,
          checkpointId: checkpoint,
        );
      }
      final db = await database.database;
      if (bedtime) {
        await db.update(
          'game_periods',
          {'day_progress': 76},
          where: 'id = ?',
          whereArgs: [started.id],
        );
      }
      await db.update(
        'game_states',
        {'wallet_balance': walletBalance},
        where: 'profile_id = ?',
        whereArgs: [profileId],
      );
      if (legacyDayFiveCompleted) {
        final db = await database.database;
        await db.insert('task_progress', {
          'profile_id': profileId,
          'task_id': 'task_final_choice_05',
          'status': 'completed',
          'reward_claimed': 1,
          'scenario_state': '{"answerId":"balanced"}',
          'updated_at': DateTime.utc(2026).toIso8601String(),
        });
        await db.insert(
          'transactions',
          GameTransaction(
            profileId: profileId,
            periodId: started.id!,
            type: GameTransactionType.taskReward,
            amount: 50,
            source: 'task_reward_task_final_choice_05',
            description: 'Старая награда',
            createdAt: DateTime.utc(2026),
            deduplicationKey: 'task_reward_${started.id}_task_final_choice_05',
          ).toMap(),
        );
        await resolveCheckpointForTest(
          database,
          profileId: profileId,
          periodId: started.id!,
          checkpointId: 'financial_task',
        );
      }
    });

    final dayFiveContent = day == 5
        ? await tester.runAsync(() async {
            final assets = AssetContentRepository();
            return TestContentRepository(
              [
                PeriodDefinition(
                  id: 'period_5_independent',
                  number: 5,
                  title: 'Самостоятельный выбор',
                  baseIncome: 500,
                  requiredCheckpoints: required,
                ),
              ],
              tasks: await assets.loadTasks(),
              shopItems: await assets.loadShopItems(),
              stories: await assets.loadStoryPurchases(),
              promotions: await assets.loadPromotions(),
            );
          })
        : null;
    final dayOneBedtimeContent = day == 1 && petSatiety < 70
        ? await tester.runAsync(() async {
            final assets = AssetContentRepository();
            return TestContentRepository([
              PeriodDefinition(
                id: 'period_1',
                number: 1,
                title: 'День 1',
                baseIncome: 500,
                requiredCheckpoints: required,
              ),
            ], shopItems: await assets.loadShopItems());
          })
        : null;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _TestProfileId(profileId)),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(
          day == 5
              ? dayFiveContent!
              : dayOneBedtimeContent ??
                    TestContentRepository([
                      PeriodDefinition(
                        id: 'period_1',
                        number: 1,
                        title: 'День 1',
                        baseIncome: 500,
                        requiredCheckpoints: required,
                      ),
                    ]),
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/tasks',
          builder: (_, _) => const Scaffold(body: Text('Tasks target')),
        ),
        GoRoute(
          path: '/savings',
          builder: (_, _) => const Scaffold(body: Text('Savings target')),
        ),
        GoRoute(
          path: '/budget',
          builder: (_, _) => const Scaffold(body: Text('Budget target')),
        ),
        GoRoute(
          path: '/things',
          builder: (_, _) => const Scaffold(body: Text('Things target')),
        ),
        GoRoute(
          path: '/shop',
          builder: (_, _) => const Scaffold(body: Text('Shop target')),
        ),
        GoRoute(
          path: '/period-summary',
          builder: (_, _) => const Scaffold(body: Text('Summary target')),
        ),
      ],
    );
    addTearDown(() async {
      router.dispose();
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await waitFor(tester, find.byKey(const Key('home-room-background')));
    expect(container.read(homeControllerProvider), isA<HomeReady>());
    expect(tester.takeException(), isNull);
    return _HomeFixture(container, router);
  }

  Future<void> tapVisible(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void expectRequiredActionsReadOnly(WidgetTester tester) {
    final requiredActions = find.byKey(const Key('home-required-actions'));
    expect(requiredActions, findsOneWidget);
    for (final buttonType in [
      TextButton,
      FilledButton,
      OutlinedButton,
      IconButton,
    ]) {
      expect(
        find.descendant(of: requiredActions, matching: find.byType(buttonType)),
        findsNothing,
      );
    }
    expect(
      find.descendant(
        of: requiredActions,
        matching: find.byKey(const Key('home-today-task-action')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: requiredActions,
        matching: find.byKey(const Key('home-today-savings-action')),
      ),
      findsNothing,
    );
  }

  testWidgets('Day 5 status stays read-only as task progress changes', (
    tester,
  ) async {
    final fixture = await mountHome(tester, day: 5);
    final ready = fixture.container.read(homeControllerProvider) as HomeReady;
    final profileId = ready.profile.id!;
    final periodId = ready.period!.id!;
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Нужно выполнить'), findsOneWidget);
    expectRequiredActionsReadOnly(tester);
    await tester.runAsync(
      () => fixture.container
          .read(taskServiceProvider)
          .submitIndependentBudget(
            profileId: profileId,
            periodId: periodId,
            taskId: 'task_independent_budget_05',
            selectedItemIds: {'food_feed', 'care_comb'},
            savingsAmount: 50,
          ),
    );
    await tester.runAsync(
      fixture.container.read(homeControllerProvider.notifier).load,
    );
    await tester.pumpAndSettle();
    expect(find.text('Нужно выполнить'), findsOneWidget);
    await tester.runAsync(
      () => fixture.container
          .read(taskServiceProvider)
          .submitPlanRepair(
            profileId: profileId,
            periodId: periodId,
            taskId: 'task_plan_repair_05',
            nowItemIds: {'food_feed', 'care_comb', 'scenario_waterer_05'},
            savingsAmount: 70,
          ),
    );
    await tester.runAsync(
      fixture.container.read(homeControllerProvider.notifier).load,
    );
    await tester.pumpAndSettle();
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expectRequiredActionsReadOnly(tester);
  });

  testWidgets('Day 5 planning hides task CTA', (tester) async {
    await mountHome(tester, day: 5, planning: true);
    expect(find.text('Нужно выполнить'), findsOneWidget);
    expect(find.byKey(const Key('home-today-task-action')), findsNothing);
  });

  testWidgets('legacy Day 5 is complete in Home without new progress', (
    tester,
  ) async {
    final fixture = await mountHome(
      tester,
      day: 5,
      legacyDayFiveCompleted: true,
    );
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expectRequiredActionsReadOnly(tester);
    final home = fixture.container.read(homeControllerProvider) as HomeReady;
    expect(home.dayFiveTaskCompletion?.legacyCompleted, isTrue);
    expect(home.dayFiveTaskCompletion?.completedTaskIds, isEmpty);
  });

  testWidgets(
    'planning shows statuses without actions, then active enables them',
    (tester) async {
      final fixture = await mountHome(tester, planning: true);
      expect(find.byKey(const Key('home-continue-plan')), findsOneWidget);
      expect(find.text('Продолжить план'), findsOneWidget);
      expect(find.byKey(const Key('home-required-actions')), findsOneWidget);
      expect(find.text('Задание дня'), findsOneWidget);
      expect(find.text('Накопления'), findsOneWidget);
      for (final key in [
        'home-today-task-action',
        'home-today-savings-action',
        'home-next-task',
        'home-next-savings',
      ]) {
        expect(find.byKey(Key(key)), findsNothing);
      }
      expect(tester.takeException(), isNull);

      final home = fixture.container.read(homeControllerProvider) as HomeReady;
      await tester.runAsync(
        () => confirmBudgetForTest(
          fixture.container.read(gameRepositoryProvider),
          profileId: home.profile.id!,
          periodId: home.period!.id!,
        ),
      );
      await tester.runAsync(
        fixture.container.read(homeControllerProvider.notifier).load,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-continue-plan')), findsNothing);
      expect(find.byKey(const Key('home-next-task')), findsOneWidget);
      expect(find.byKey(const Key('home-today-task-action')), findsNothing);
      expect(find.byKey(const Key('home-today-savings-action')), findsNothing);
      expectRequiredActionsReadOnly(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('required action statuses are read-only at 360x800', (
    tester,
  ) async {
    await mountHome(tester);
    expect(find.text('Выполнить задание'), findsOneWidget);
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Накопления'), findsOneWidget);
    expect(find.text('Нужно выполнить'), findsOneWidget);
    expect(find.text('Нужно решить'), findsOneWidget);
    expectRequiredActionsReadOnly(tester);
    final mainCta = find.byKey(const Key('home-next-task'));
    expect(tester.getSize(mainCta).height, greaterThanOrEqualTo(48));
    expect(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (key, destination) in [('home-next-task', '/tasks')]) {
    testWidgets('$key opens $destination', (tester) async {
      final fixture = await mountHome(tester);
      await tapVisible(tester, key);
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        destination,
      );
      expect(find.text('Tasks target'), findsOneWidget);
    });
  }

  testWidgets('resolved task recommends savings and main CTA navigates', (
    tester,
  ) async {
    final fixture = await mountHome(tester, resolved: ['financial_task']);
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.byKey(const Key('home-today-task-action')), findsNothing);
    expect(find.byKey(const Key('home-next-task')), findsNothing);
    expect(find.byKey(const Key('home-next-savings')), findsOneWidget);
    expect(find.text('Решить про накопления'), findsOneWidget);
    expect(find.byKey(const Key('home-today-savings-action')), findsNothing);
    await tapVisible(tester, 'home-next-savings');
    expect(fixture.router.routeInformationProvider.value.uri.path, '/savings');
    expect(find.text('Savings target'), findsOneWidget);
  });

  testWidgets('primary savings recommendation navigates', (tester) async {
    final fixture = await mountHome(tester, resolved: ['financial_task']);
    await tapVisible(tester, 'home-next-savings');
    expect(fixture.router.routeInformationProvider.value.uri.path, '/savings');
  });

  testWidgets('both resolved restore the plan CTA before bedtime', (
    tester,
  ) async {
    await mountHome(tester, resolved: ['financial_task', 'savings_decision']);
    expect(find.text('Готово'), findsNWidgets(2));
    expect(find.byKey(const Key('home-today-task-action')), findsNothing);
    expect(find.byKey(const Key('home-today-savings-action')), findsNothing);
    expect(find.byKey(const Key('home-view-plan')), findsOneWidget);
    expect(find.text('Посмотреть план'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (resolved, buttonKey, destination, reason) in [
    (
      ['savings_decision'],
      'home-blocker-go-task',
      '/tasks',
      'Осталось выполнить сегодняшнее финансовое задание.',
    ),
    (
      ['financial_task'],
      'home-blocker-go-savings',
      '/savings',
      'Осталось решить, будешь ли ты сегодня откладывать монеты.',
    ),
  ]) {
    testWidgets('bedtime blocker $buttonKey opens $destination', (
      tester,
    ) async {
      final fixture = await mountHome(
        tester,
        resolved: resolved,
        bedtime: true,
      );
      await tapVisible(tester, 'home-finish-day');
      await waitFor(tester, find.text(reason));
      expect(find.byKey(Key(buttonKey)), findsOneWidget);
      expect(find.text('Вернуться'), findsOneWidget);
      await tapVisible(tester, buttonKey);
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        destination,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bedtime blocker offers both unresolved destinations', (
    tester,
  ) async {
    await mountHome(tester, bedtime: true);
    await tapVisible(tester, 'home-finish-day');
    await waitFor(
      tester,
      find.textContaining('сегодняшнее финансовое задание'),
    );
    expect(find.byKey(const Key('home-blocker-go-task')), findsOneWidget);
    expect(find.byKey(const Key('home-blocker-go-savings')), findsOneWidget);
    expect(find.text('Вернуться'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changed circumstance only has no invented route', (
    tester,
  ) async {
    await mountHome(tester, required: ['changed_circumstance'], bedtime: true);
    expect(find.byKey(const Key('home-required-actions')), findsNothing);
    expect(find.byKey(const Key('home-finish-day')), findsOneWidget);
    expect(find.textContaining('сломается миска'), findsNothing);
    await tapVisible(tester, 'home-finish-day');
    await waitFor(tester, find.text('Проведи ещё немного времени с Финни.'));
    expect(find.byKey(const Key('home-blocker-go-task')), findsNothing);
    expect(find.byKey(const Key('home-blocker-go-savings')), findsNothing);
    expect(find.text('Вернуться'), findsOneWidget);
    await tester.tap(find.text('Вернуться'));
    await tester.pumpAndSettle();
    expect(find.text('Проведи ещё немного времени с Финни.'), findsNothing);
  });

  testWidgets('unknown checkpoint keeps generic reason without route', (
    tester,
  ) async {
    await mountHome(tester, required: ['future_checkpoint'], bedtime: true);
    await tapVisible(tester, 'home-finish-day');
    await waitFor(
      tester,
      find.text('Осталось завершить одно важное дело этого дня.'),
    );
    expect(find.byKey(const Key('home-blocker-go-task')), findsNothing);
    expect(find.byKey(const Key('home-blocker-go-savings')), findsNothing);
    expect(find.text('Вернуться'), findsOneWidget);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets('blocked bedtime dialog fits and routes at $size', (
      tester,
    ) async {
      final fixture = await mountHome(tester, bedtime: true, size: size);
      await tapVisible(tester, 'home-finish-day');
      await waitFor(tester, find.text('Перед сном осталось важное дело'));
      expect(find.text('Вернуться'), findsOneWidget);
      expect(find.text('К заданию'), findsOneWidget);
      expect(find.text('К накоплениям'), findsOneWidget);
      expectFinnyDialogVisuals(tester);
      for (final buttonFinder in [
        find.widgetWithText(TextButton, 'Вернуться'),
        find.widgetWithText(FilledButton, 'К заданию'),
        find.widgetWithText(FilledButton, 'К накоплениям'),
      ]) {
        expect(tester.getSize(buttonFinder).height, greaterThanOrEqualTo(48));
      }
      final route = size.width == 360 ? '/tasks' : '/savings';
      await tester.tap(
        find.text(route == '/tasks' ? 'К заданию' : 'К накоплениям'),
      );
      await tester.pumpAndSettle();
      expect(fixture.router.routeInformationProvider.value.uri.path, route);
      expect(tester.takeException(), isNull);
    });

    testWidgets('care bedtime dialog is Finny styled and routes at $size', (
      tester,
    ) async {
      final fixture = await mountHome(
        tester,
        bedtime: true,
        resolved: ['financial_task', 'savings_decision'],
        petSatiety: 20,
        walletBalance: 1000,
        size: size,
      );
      await tapVisible(tester, 'home-finish-day');
      await waitFor(tester, find.text('Финни ещё не готов спать'));
      expect(find.text('Подними Сытость в зелёную зону.'), findsOneWidget);
      expect(find.text('Вернуться'), findsOneWidget);
      expect(find.text('Открыть Вещи'), findsOneWidget);
      expect(find.text('Открыть Магазин'), findsOneWidget);
      expectFinnyDialogVisuals(tester);
      for (final buttonFinder in [
        find.widgetWithText(TextButton, 'Вернуться'),
        find.widgetWithText(FilledButton, 'Открыть Вещи'),
        find.widgetWithText(TextButton, 'Открыть Магазин'),
      ]) {
        expect(tester.getSize(buttonFinder).height, greaterThanOrEqualTo(48));
      }
      final route = size.width == 360 ? '/things' : '/shop';
      await tester.tap(
        find.text(route == '/things' ? 'Открыть Вещи' : 'Открыть Магазин'),
      );
      await tester.pumpAndSettle();
      expect(fixture.router.routeInformationProvider.value.uri.path, route);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fallback bedtime dialog preserves finish action at $size', (
      tester,
    ) async {
      final fixture = await mountHome(
        tester,
        bedtime: true,
        resolved: ['financial_task', 'savings_decision'],
        petSatiety: 20,
        walletBalance: 0,
        size: size,
      );
      await tapVisible(tester, 'home-finish-day');
      await waitFor(tester, find.text('Сегодня Финни нужна помощь'));
      expect(find.text('Вернуться'), findsOneWidget);
      expect(find.text('Завершить день'), findsOneWidget);
      expectFinnyDialogVisuals(tester);
      await tester.tap(find.text('Завершить день'));
      await tester.pump();
      await waitFor(tester, find.text('Summary target'));
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/period-summary',
      );
      expect(find.text('Summary target'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'too early bedtime dialog fits and uses purple actions at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => FinnyBedtimeDialog(
                          icon: Icons.wb_sunny_rounded,
                          title: 'Ещё рано спать',
                          body: 'У Финни ещё есть время для дел и заботы. Вернись к нему позже.',
                          actions: [
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                style: FinnyModalActions.primary,
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Хорошо'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Ещё рано спать'), findsOneWidget);
        expect(find.text('Хорошо'), findsOneWidget);
        expectFinnyDialogVisuals(tester);
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Хорошо')).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.text('Хорошо'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

void expectFinnyDialogVisuals(WidgetTester tester) {
  final dialog = tester.widget<Dialog>(find.byType(Dialog));
  expect(dialog.backgroundColor, Colors.white);
  expect(dialog.surfaceTintColor, Colors.transparent);
  for (final button in tester.widgetList<FilledButton>(
    find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(FilledButton),
    ),
  )) {
    expect(
      button.style?.backgroundColor?.resolve({}),
      anyOf(AppColors.primary, AppColors.primaryLight),
    );
  }
  for (final button in tester.widgetList<TextButton>(
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextButton)),
  )) {
    expect(button.style?.backgroundColor?.resolve({}), AppColors.primaryLight);
  }
}
