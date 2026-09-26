import 'dart:math';

import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/tasks/tasks_screen.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/features/tasks/plan_adaptation_task_screen.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

class _ActiveProfile extends ActiveProfileIdController {
  _ActiveProfile(this.profileId);
  final int profileId;

  @override
  int? build() => profileId;
}

class _UnchangedShuffleRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var index = 0; index < 100; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> _tapToZone(WidgetTester tester, String itemId, String zone) async {
  final item = find.byKey(Key('plan-adaptation-item-$itemId'));
  await tester.ensureVisible(item);
  await tester.pumpAndSettle();
  await tester.tap(item);
  await tester.pump();
  final place = find.byKey(Key('plan-adaptation-place-$zone'));
  await tester.ensureVisible(place);
  await tester.pumpAndSettle();
  await tester.tap(place);
  await tester.pump();
}

void main() {
  testWidgets(
    'Day 3 plan adaptation supports tap, drag and non-mutating correction',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late final AppDatabase database;
      late final Profile profile;
      await tester.runAsync(() async {
        database = createTestDatabase();
        final profiles = SqliteProfileRepository(database);
        final games = SqliteGameRepository(database);
        profile = await profiles.create(
          Profile(
            gameName: 'Игрок',
            profileType: ProfileType.normal,
            onboardingCompleted: true,
            createdAt: DateTime.utc(2026),
          ),
        );
        await games.ensureInitialState(profile.id!);
        await games.savePet(
          Pet(
            profileId: profile.id!,
            name: 'Финни',
            colorId: 'blue',
            patternId: 'plain',
            developmentStage: 1,
            growthPoints: 0,
            satiety: 60,
            care: 60,
            mood: 60,
          ),
        );
        final period = await games.startPeriod(
          profileId: profile.id!,
          definitionId: 'period_3',
          periodNumber: 3,
          baseIncome: 500,
          requiredCheckpoints: const ['financial_task'],
          createdAt: DateTime.utc(2026),
        );
        await confirmBudgetForTest(
          games,
          profileId: profile.id!,
          periodId: period.id!,
        );
      });
      final task = testPlanAdaptationTask();
      final container = ProviderContainer(
        overrides: [
          activeProfileIdProvider.overrideWith(
            () => _ActiveProfile(profile.id!),
          ),
          appDatabaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository(
              testPeriodDefinitions(count: 3),
              tasks: [task],
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
            ),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TasksScreen()),
        ),
      );
      await _pumpUntil(
        tester,
        find.byKey(const Key('task-open-task_changed_plan_03')),
      );
      await tester.tap(find.byKey(const Key('task-open-task_changed_plan_03')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('plan-adaptation-task-screen')),
        findsOneWidget,
      );
      expect(find.text('Исходный план: 300 монет'), findsOneWidget);
      expect(find.text('Потерялось: −80 монет'), findsOneWidget);
      expect(find.text('Теперь доступно: 220 монет'), findsOneWidget);
      expect(find.text('Сейчас в плане: 300 монет'), findsOneWidget);

      final later = find.byKey(const Key('plan-adaptation-zone-later'));
      await _tapToZone(tester, 'toy', 'later');
      await _tapToZone(tester, 'savings', 'later');
      await tester.tap(find.byKey(const Key('plan-adaptation-check')));
      await _pumpUntil(
        tester,
        find.byKey(const Key('plan-adaptation-incorrect-title')),
      );
      expect(
        find.text(
          'Игрушку уже можно отложить. Накопления пока можно сохранить.',
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: later,
          matching: find.byKey(const Key('plan-adaptation-item-toy')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      // Keep the card placement intact after the incorrect check.
      expect(
        find.byKey(const Key('plan-adaptation-item-food')),
        findsOneWidget,
      );
      await _tapToZone(tester, 'savings', 'keep');
      await tester.drag(
        find.descendant(
          of: find.byKey(const Key('plan-adaptation-task-screen')),
          matching: find.byType(ListView),
        ),
        const Offset(0, 800),
      );
      await tester.pumpAndSettle();
      expect(find.text('Сейчас в плане: 200 монет'), findsOneWidget);
      expect(find.text('Свободно: 20 монет'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('plan-adaptation-check')),
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('plan-adaptation-task-screen')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('plan-adaptation-check')));
      await _pumpUntil(
        tester,
        find.byKey(const Key('plan-adaptation-success-title')),
      );
      expect(find.textContaining('+50 монет'), findsOneWidget);
      final armedEvents = (await tester.runAsync(
        () async => (await database.database).query('campaign_story_events'),
      ))!;
      expect(armedEvents, hasLength(1));
      expect(armedEvents.single['status'], 'armed');
      expect(armedEvents.single['threshold'], anyOf(1, 2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unchanged random shuffle falls back to a rotated card order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlanAdaptationTaskScreen(
          task: testPlanAdaptationTask(),
          controller: TasksController(),
          random: _UnchangedShuffleRandom(),
        ),
      ),
    );
    final keepZone = find.byKey(const Key('plan-adaptation-zone-keep'));
    final cards = tester.widgetList<Draggable<String>>(
      find.descendant(of: keepZone, matching: find.byType(Draggable<String>)),
    );
    expect(cards.map((card) => card.data).toList(), [
      'shampoo',
      'toy',
      'savings',
      'food',
    ]);
  });

  testWidgets('drag moves a card to the later zone', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: PlanAdaptationTaskScreen(
          task: testPlanAdaptationTask(),
          controller: TasksController(),
          random: _UnchangedShuffleRandom(),
        ),
      ),
    );
    final toy = find.byKey(const Key('plan-adaptation-item-toy'));
    final later = find.byKey(const Key('plan-adaptation-zone-later'));
    expect(later, findsOneWidget);
    await tester.drag(toy, tester.getCenter(later) - tester.getCenter(toy));
    await tester.pumpAndSettle();
    expect(find.descendant(of: later, matching: toy), findsOneWidget);
  });
}
