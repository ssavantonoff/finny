import 'package:finny/app/providers.dart';
import 'package:finny/features/tasks/tasks_screen.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

Future<void> _tapToDecision(
  WidgetTester tester,
  String itemId,
  String decision,
) async {
  final item = find.byKey(Key('budget-priority-item-$itemId'));
  final zone = find.byKey(Key('budget-priority-zone-$decision'));
  await _reveal(tester, item);
  await tester.tap(item);
  await tester.pump();
  await _reveal(tester, zone);
  await tester.tap(zone);
  await tester.pump();
}

Future<void> _dragToDecision(
  WidgetTester tester,
  String itemId,
  String decision,
) async {
  final item = find.byKey(Key('budget-priority-item-$itemId'));
  final zone = find.byKey(Key('budget-priority-zone-$decision'));
  await _reveal(tester, item);
  await _reveal(tester, zone);
  final start = tester.getCenter(item);
  final end = tester.getCenter(zone);
  await tester.dragFrom(start, end - start);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).last;
    final position = tester.state<ScrollableState>(scrollable).position;
    for (final fraction in [0.0, 0.5, 1.0]) {
      position.jumpTo(position.maxScrollExtent * fraction);
      await tester.pump();
      if (finder.evaluate().isNotEmpty) break;
    }
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilRevealed(
  WidgetTester tester,
  Finder finder, {
  int attempts = 100,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      await tester.pump();
      return;
    }
    final scrollable = find.byType(Scrollable).last;
    final position = tester.state<ScrollableState>(scrollable).position;
    for (final fraction in [0.0, 0.5, 1.0]) {
      position.jumpTo(position.maxScrollExtent * fraction);
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        await tester.ensureVisible(finder);
        await tester.pump();
        return;
      }
    }
  }
  expect(finder, findsOneWidget);
}

void main() {
  testWidgets(
    'Day 2 budget priority supports limits, correction and completion',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final database = createTestDatabase();
      final profiles = SqliteProfileRepository(database);
      final games = SqliteGameRepository(database);
      late int profileId;
      late List<Map<String, Object?>> inventoryBefore;
      await tester.runAsync(() async {
        final profile = await profiles.create(
          Profile(
            gameName: 'Игрок',
            profileType: ProfileType.normal,
            onboardingCompleted: true,
            createdAt: DateTime.utc(2026),
          ),
        );
        profileId = profile.id!;
        await games.ensureInitialState(profileId);
        await games.savePet(
          Pet(
            profileId: profileId,
            name: 'Финни',
            colorId: 'blue',
            patternId: 'plain',
            developmentStage: 1,
            growthPoints: 0,
            satiety: 55,
            care: 80,
            mood: 80,
          ),
        );
        final period = await games.startPeriod(
          profileId: profileId,
          definitionId: 'period_2',
          periodNumber: 2,
          baseIncome: 500,
          requiredCheckpoints: const ['financial_task', 'savings_decision'],
          createdAt: DateTime.utc(2026, 1, 2),
        );
        await confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: period.id!,
        );
        inventoryBefore = await (await database.database).query(
          'inventory',
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
      });

      final task = testBudgetPriorityTask();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository(
              testPeriodDefinitions(count: 2),
              tasks: [task],
            ),
          ),
        ],
      );
      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(profileId);
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
        find.byKey(const Key('task-open-task_priority_02')),
      );
      await tester.tap(find.byKey(const Key('task-open-task_priority_02')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(const Key('budget-priority-task-screen')),
        findsOneWidget,
      );
      expect(find.text('Бюджет задания: 150 монет'), findsOneWidget);
      expect(find.text('Осталось: 150 монет'), findsOneWidget);
      expect(find.text('Это бюджет только для задания.'), findsOneWidget);
      expect(find.text('Корм'), findsOneWidget);
      expect(find.text('90 монет'), findsOneWidget);
      expect(find.text('Шампунь'), findsOneWidget);
      expect(find.text('60 монет'), findsOneWidget);
      expect(find.text('Наушники'), findsOneWidget);
      expect(find.text('80 монет'), findsOneWidget);
      expect(find.text('Купить сейчас'), findsOneWidget);
      await _reveal(
        tester,
        find.byKey(const Key('budget-priority-zone-later')),
      );
      expect(find.text('Оставить на потом'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('budget-priority-check')),
            )
            .onPressed,
        isNull,
      );

      await _tapToDecision(tester, 'food', 'buy_now');
      expect(find.text('Осталось: 60 монет'), findsOneWidget);

      final bow = find.byKey(const Key('budget-priority-item-bow'));
      final buyNow = find.byKey(const Key('budget-priority-zone-buy_now'));
      await _dragToDecision(tester, 'bow', 'buy_now');
      final budgetError = find.byKey(const Key('budget-priority-budget-error'));
      expect(budgetError, findsOneWidget);
      expect(tester.getTopLeft(budgetError).dy, lessThan(200));
      expect(find.text('Не хватает 20 монет'), findsOneWidget);
      expect(find.text('Осталось: 60 монет'), findsOneWidget);
      expect(
        find.descendant(
          of: buyNow,
          matching: find.byKey(const Key('budget-priority-item-food')),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: buyNow, matching: bow), findsNothing);

      final later = find.byKey(const Key('budget-priority-zone-later'));
      await _tapToDecision(tester, 'bow', 'later');
      expect(
        find.byKey(const Key('budget-priority-budget-error')),
        findsNothing,
      );

      await _dragToDecision(tester, 'shampoo', 'buy_now');
      expect(find.text('Осталось: 0 монет'), findsOneWidget);
      await _tapToDecision(tester, 'bow', 'buy_now');
      expect(find.text('Не хватает 80 монет'), findsOneWidget);
      expect(find.descendant(of: buyNow, matching: bow), findsNothing);
      await _reveal(tester, later);
      await tester.tap(later);
      await tester.pump();
      expect(budgetError, findsNothing);
      await _tapToDecision(tester, 'food', 'later');
      await _tapToDecision(tester, 'bow', 'buy_now');
      expect(find.text('Осталось: 10 монет'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('budget-priority-check')),
            )
            .onPressed,
        isNotNull,
      );

      await _reveal(tester, find.byKey(const Key('budget-priority-check')));
      await tester.tap(find.byKey(const Key('budget-priority-check')));
      await _pumpUntilRevealed(
        tester,
        find.byKey(const Key('budget-priority-incorrect-title')),
      );
      expect(
        find.text(
          'Проверь, что сначала выбраны важные покупки и бюджет не превышен.',
        ),
        findsOneWidget,
      );
      await _reveal(
        tester,
        find.byKey(const Key('budget-priority-feedback-food')),
      );
      expect(
        find.byKey(const Key('budget-priority-feedback-food')),
        findsOneWidget,
      );
      await _reveal(
        tester,
        find.byKey(const Key('budget-priority-feedback-bow')),
      );
      expect(
        find.byKey(const Key('budget-priority-feedback-bow')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('budget-priority-feedback-shampoo')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: buyNow,
          matching: find.byKey(const Key('budget-priority-item-bow')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: later,
          matching: find.byKey(const Key('budget-priority-item-food')),
        ),
        findsOneWidget,
      );

      await _tapToDecision(tester, 'bow', 'later');
      expect(
        find.byKey(const Key('budget-priority-feedback-food')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('budget-priority-feedback-bow')),
        findsNothing,
      );
      await _tapToDecision(tester, 'food', 'buy_now');
      expect(find.text('Осталось: 0 монет'), findsOneWidget);

      await _reveal(tester, find.byKey(const Key('budget-priority-check')));
      await tester.tap(find.byKey(const Key('budget-priority-check')));
      await _pumpUntilRevealed(
        tester,
        find.byKey(const Key('budget-priority-success-title')),
      );
      expect(find.text('+50 монет'), findsOneWidget);
      expect(
        find.text(
          'Ты сначала выбрал важные покупки и уложился в бюджет.\n'
          'Желание можно оставить на потом.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await _reveal(tester, find.byKey(const Key('budget-priority-continue')));
      await tester.tap(find.byKey(const Key('budget-priority-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Выполнено ✓'), findsOneWidget);

      final persisted = await tester.runAsync(
        () => games.getTaskProgress(profileId, task.id),
      );
      final period = await tester.runAsync(
        () => games.getCurrentPeriod(profileId),
      );
      final state = await tester.runAsync(() => games.getGameState(profileId));
      final transactions = await tester.runAsync(
        () => games.getTransactions(profileId),
      );
      final inventory = await tester.runAsync(
        () async => (await database.database).query(
          'inventory',
          where: 'profile_id = ?',
          whereArgs: [profileId],
        ),
      );
      expect(persisted, isNotNull);
      expect(period?.dayProgress, 40);
      expect(period?.resolvedCheckpoints, contains('financial_task'));
      expect(state?.walletBalance, 550);
      expect(
        transactions?.where(
          (entry) => entry.type == GameTransactionType.taskReward,
        ),
        hasLength(1),
      );
      expect(inventory, inventoryBefore);
      expect(tester.takeException(), isNull);
    },
  );
}
