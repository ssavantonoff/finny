import 'dart:math';

import 'package:finny/app/providers.dart';
import 'package:finny/features/tasks/tasks_screen.dart';
import 'package:finny/features/shop/shop_item_art.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

const _dayOneTask = FinancialTask(
  id: 'task_need_or_want_01',
  title: 'Нужно или хочу?',
  topic: 'needs_and_wants',
  description: 'Разложи вещи Финни на нужное и желаемое.',
  type: 'categorization',
  reward: 50,
  period: 1,
  requiredForCheckpoint: true,
  categorizationScenario: CategorizationTaskScenario(
    prompt: 'Финни готовится к дню. Разложи вещи.',
    categories: [
      CategorizationTaskCategory(
        id: 'need',
        label: 'Нужно',
        description: 'То, что связано с важной заботой о Финни.',
      ),
      CategorizationTaskCategory(
        id: 'want',
        label: 'Хочу',
        description: 'Это приятно, но можно купить позже.',
      ),
    ],
    items: [
      CategorizationTaskItem(
        id: 'food',
        label: 'Корм',
        correctCategoryId: 'need',
        feedback: 'Корм нужен, чтобы Финни был сыт.',
      ),
      CategorizationTaskItem(
        id: 'shampoo',
        label: 'Шампунь',
        correctCategoryId: 'need',
        feedback: 'Шампунь нужен для ухода за Финни.',
      ),
      CategorizationTaskItem(
        id: 'comb',
        label: 'Полотенце',
        correctCategoryId: 'need',
        feedback: 'Полотенце помогает ухаживать за Финни.',
      ),
      CategorizationTaskItem(
        id: 'ball',
        label: 'Мяч',
        correctCategoryId: 'want',
        feedback: 'С мячом весело, но его можно купить позже.',
      ),
      CategorizationTaskItem(
        id: 'bow',
        label: 'Кепка',
        correctCategoryId: 'want',
        feedback: 'Кепка радуют Финни, но без них можно обойтись.',
      ),
      CategorizationTaskItem(
        id: 'room_decoration',
        label: 'Украшение для комнаты',
        correctCategoryId: 'want',
        feedback: 'Украшение делает комнату уютнее.',
      ),
    ],
    successExplanation: 'Сначала важно позаботиться о нужном.',
  ),
);

class _DeterministicShuffleRandom implements Random {
  var _calls = 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) {
    final call = _calls++;
    if (call < 5) return max - 1;
    return max > 1 ? 1 : 0;
  }
}

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

Future<void> _tapToCategory(
  WidgetTester tester,
  String itemId,
  String categoryId,
) async {
  final item = find.byKey(Key('categorization-item-$itemId'));
  final zone = find.byKey(Key('categorization-zone-$categoryId'));
  await tester.ensureVisible(item);
  await tester.tap(item);
  await tester.pump();
  await tester.ensureVisible(zone);
  await tester.tap(
    find.descendant(
      of: zone,
      matching: find.text(categoryId == 'need' ? 'Нужно' : 'Хочу'),
    ),
  );
  await tester.pump();
}

Future<void> _dragToCategory(
  WidgetTester tester,
  String itemId,
  String categoryId,
) async {
  final item = find.byKey(Key('categorization-item-$itemId'));
  final zone = find.byKey(Key('categorization-zone-$categoryId'));
  await tester.ensureVisible(item);
  await tester.ensureVisible(zone);
  final start = tester.getCenter(item);
  final end = tester.getCenter(zone);
  await tester.dragFrom(start, end - start);
  await tester.pump(const Duration(milliseconds: 300));
}

List<String> _visualOrder(WidgetTester tester, Iterable<String> itemIds) {
  final ordered = itemIds.toList();
  ordered.sort((left, right) {
    final leftOffset = tester.getTopLeft(
      find.byKey(Key('categorization-item-$left')),
    );
    final rightOffset = tester.getTopLeft(
      find.byKey(Key('categorization-item-$right')),
    );
    final vertical = leftOffset.dy.compareTo(rightOffset.dy);
    return vertical == 0 ? leftOffset.dx.compareTo(rightOffset.dx) : vertical;
  });
  return ordered;
}

List<String> _visualOrderInZone(
  WidgetTester tester,
  String categoryId,
  Iterable<String> itemIds,
) {
  final zone = find.byKey(Key('categorization-zone-$categoryId'));
  final ordered = itemIds.toList();
  ordered.sort((left, right) {
    final leftOffset = tester.getTopLeft(
      find.descendant(
        of: zone,
        matching: find.byKey(Key('categorization-item-$left')),
      ),
    );
    final rightOffset = tester.getTopLeft(
      find.descendant(
        of: zone,
        matching: find.byKey(Key('categorization-item-$right')),
      ),
    );
    final vertical = leftOffset.dy.compareTo(rightOffset.dy);
    return vertical == 0 ? leftOffset.dx.compareTo(rightOffset.dx) : vertical;
  });
  return ordered;
}

void main() {
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'Day 1 categorization supports tap, drag, correction and completion',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final database = createTestDatabase();
        final shopItems = await tester.runAsync(
          () => AssetContentRepository().loadShopItems(),
        );
        final profiles = SqliteProfileRepository(database);
        final games = SqliteGameRepository(database);
        late int profileId;
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
            definitionId: 'period_1',
            periodNumber: 1,
            baseIncome: 500,
            requiredCheckpoints: const ['financial_task', 'savings_decision'],
            createdAt: DateTime.utc(2026, 1, 2),
          );
          await confirmBudgetForTest(
            games,
            profileId: profileId,
            periodId: period.id!,
          );
        });

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            contentRepositoryProvider.overrideWithValue(
              TestContentRepository(
                testPeriodDefinitions(count: 1),
                tasks: const [_dayOneTask],
                shopItems: shopItems!,
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
            child: MaterialApp(
              home: TasksScreen(random: _DeterministicShuffleRandom()),
            ),
          ),
        );
        await _pumpUntil(
          tester,
          find.byKey(const Key('task-open-task_need_or_want_01')),
        );
        expect(find.text('Задания'), findsOneWidget);
        expect(find.text('День 1'), findsOneWidget);
        expect(
          find.byKey(const Key('task-card-task_need_or_want_01')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const Key('task-open-task_need_or_want_01')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
          find.byKey(const Key('categorization-task-screen')),
          findsOneWidget,
        );
        final firstOpenOrder = _visualOrder(tester, [
          'food',
          'shampoo',
          'comb',
          'ball',
          'bow',
          'room_decoration',
        ]);
        expect(firstOpenOrder, [
          'shampoo',
          'comb',
          'ball',
          'bow',
          'room_decoration',
          'food',
        ]);
        await tester.tap(find.byTooltip('Закрыть'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('task-open-task_need_or_want_01')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final secondOpenOrder = _visualOrder(tester, [
          'food',
          'shampoo',
          'comb',
          'ball',
          'bow',
          'room_decoration',
        ]);
        expect(secondOpenOrder, [
          'food',
          'comb',
          'ball',
          'bow',
          'room_decoration',
          'shampoo',
        ]);
        expect(secondOpenOrder, isNot(firstOpenOrder));
        for (final label in [
          'Корм',
          'Шампунь',
          'Полотенце',
          'Мяч',
          'Кепка',
          'Украшение для комнаты',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(
          find.byKey(const Key('categorization-zone-need')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('categorization-zone-want')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('task-item-art-food')),
            matching: find.byType(ShopItemArt),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.weekend_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('categorization-check')),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('Почти получилось!'), findsNothing);
        expect(find.text('Отлично!'), findsNothing);

        await _tapToCategory(tester, 'food', 'need');
        await tester.ensureVisible(find.byKey(const Key('task-remove-food')));
        await tester.tap(find.byKey(const Key('task-remove-food')));
        await tester.pump();
        expect(
          find.descendant(
            of: find.byKey(const Key('categorization-zone-need')),
            matching: find.byKey(const Key('categorization-item-food')),
          ),
          findsNothing,
        );
        await _tapToCategory(tester, 'food', 'want');
        await _dragToCategory(tester, 'shampoo', 'need');
        await _tapToCategory(tester, 'comb', 'need');
        await _tapToCategory(tester, 'ball', 'want');
        await _tapToCategory(tester, 'bow', 'need');
        await _tapToCategory(tester, 'room_decoration', 'want');

        final needOrderBeforeIncorrect = _visualOrderInZone(tester, 'need', [
          'shampoo',
          'comb',
          'bow',
        ]);
        expect(needOrderBeforeIncorrect, ['comb', 'bow', 'shampoo']);

        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('categorization-check')),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.text('Почти получилось!'), findsNothing);
        await tester.ensureVisible(
          find.byKey(const Key('categorization-check')),
        );
        await tester.tap(find.byKey(const Key('categorization-check')));
        await _pumpUntil(
          tester,
          find.byKey(const Key('categorization-incorrect-title')),
        );

        expect(
          find.byKey(const Key('categorization-feedback-food')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('categorization-feedback-bow')),
          findsOneWidget,
        );
        expect(
          _visualOrderInZone(tester, 'need', ['shampoo', 'comb', 'bow']),
          needOrderBeforeIncorrect,
        );
        final wantZone = find.byKey(const Key('categorization-zone-want'));
        expect(
          find.descendant(
            of: wantZone,
            matching: find.byKey(const Key('categorization-item-food')),
          ),
          findsOneWidget,
        );
        final needZone = find.byKey(const Key('categorization-zone-need'));
        expect(
          find.descendant(
            of: needZone,
            matching: find.byKey(const Key('categorization-item-bow')),
          ),
          findsOneWidget,
        );

        await tester.ensureVisible(
          find.byKey(const Key('categorization-item-food')),
        );
        await tester.tap(find.byKey(const Key('categorization-item-food')));
        await tester.pump();
        expect(
          find.byKey(const Key('categorization-feedback-food')),
          findsNothing,
        );
        await tester.ensureVisible(needZone);
        await tester.tap(
          find.descendant(of: needZone, matching: find.text('Нужно')),
        );
        await tester.pump();
        await _tapToCategory(tester, 'bow', 'want');
        await tester.ensureVisible(
          find.byKey(const Key('categorization-check')),
        );
        await tester.tap(find.byKey(const Key('categorization-check')));
        await _pumpUntil(
          tester,
          find.byKey(const Key('categorization-success-title')),
        );

        expect(find.text('+50 монет'), findsOneWidget);
        expect(
          find.byKey(const Key('categorization-continue')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const Key('categorization-continue')),
        );
        await tester.tap(find.byKey(const Key('categorization-continue')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Выполнено ✓'), findsOneWidget);
        expect(
          find.byKey(const Key('task-open-task_need_or_want_01')),
          findsNothing,
        );

        final persisted = await tester.runAsync(
          () => games.getTaskProgress(profileId, _dayOneTask.id),
        );
        final period = await tester.runAsync(
          () => games.getCurrentPeriod(profileId),
        );
        final state = await tester.runAsync(
          () => games.getGameState(profileId),
        );
        final transactions = await tester.runAsync(
          () => games.getTransactions(profileId),
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
        expect(tester.takeException(), isNull);
      },
    );
  }
}
