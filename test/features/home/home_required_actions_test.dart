import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/models/content_entry.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
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
    bool bedtime = false,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
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
          satiety: 80,
          care: 80,
          mood: 80,
        ),
      );
      final started = await games.startPeriod(
        profileId: profileId,
        definitionId: 'period_1',
        periodNumber: 1,
        baseIncome: 500,
        requiredCheckpoints: required,
        createdAt: DateTime.utc(2026),
      );
      await confirmBudgetForTest(
        games,
        profileId: profileId,
        periodId: started.id!,
      );
      for (final checkpoint in resolved) {
        await resolveCheckpointForTest(
          database,
          profileId: profileId,
          periodId: started.id!,
          checkpointId: checkpoint,
        );
      }
      if (bedtime) {
        final db = await database.database;
        await db.update(
          'game_periods',
          {'day_progress': 76},
          where: 'id = ?',
          whereArgs: [started.id],
        );
      }
    });

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _TestProfileId(profileId)),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(
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
    await waitFor(tester, find.byKey(const Key('home-day-status')));
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

  testWidgets('unresolved actions are visible and tappable at 360x800', (
    tester,
  ) async {
    await mountHome(tester);
    expect(find.text('Выполнить задание'), findsOneWidget);
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Нужно выполнить'), findsOneWidget);
    expect(find.text('Накопления'), findsOneWidget);
    expect(find.text('Нужно решить'), findsOneWidget);
    for (final key in [
      'home-next-task',
      'home-today-task-action',
      'home-today-savings-action',
    ]) {
      final button = find.byKey(Key(key));
      await tester.ensureVisible(button);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  for (final (key, destination) in [
    ('home-next-task', '/tasks'),
    ('home-today-task-action', '/tasks'),
  ]) {
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

  testWidgets('resolved task recommends savings and its Today CTA navigates', (
    tester,
  ) async {
    final fixture = await mountHome(tester, resolved: ['financial_task']);
    expect(find.text('Задание дня'), findsOneWidget);
    expect(find.text('Готово'), findsOneWidget);
    expect(find.byKey(const Key('home-today-task-action')), findsNothing);
    expect(find.byKey(const Key('home-next-task')), findsNothing);
    expect(find.byKey(const Key('home-next-savings')), findsOneWidget);
    expect(find.text('Решить про накопления'), findsOneWidget);
    await tapVisible(tester, 'home-today-savings-action');
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
    expect(find.byKey(const Key('home-today-card')), findsNothing);
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
}
