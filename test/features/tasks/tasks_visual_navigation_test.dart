import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/core/visual/finny_visual.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}

void main() {
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'Tasks before day shows current Finny and returns Home at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final database = createTestDatabase();
        final profiles = SqliteProfileRepository(database);
        final games = SqliteGameRepository(database);
        final profile = (await tester.runAsync(() async {
          final profile = await profiles.create(
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
              patternId: 'spots',
              developmentStage: 2,
              growthPoints: 0,
              satiety: 55,
              care: 80,
              mood: 80,
            ),
          );
          return profile;
        }))!;
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            contentRepositoryProvider.overrideWithValue(
              TestContentRepository(testPeriodDefinitions(count: 5)),
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
            child: const FinnyApp(),
          ),
        );
        await _pumpUntil(tester, find.byType(NavigationBar));
        await tester.tap(find.byKey(const Key('nav-tasks')));
        await _pumpUntil(tester, find.byKey(const Key('tasks-before-day')));
        expect(find.text('Задания'), findsWidgets);
        expect(find.text('Сначала начни новый день'), findsOneWidget);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          3,
        );
        final asset = FinnyVisual.assetFor(
          developmentStage: 2,
          colorId: 'blue',
          patternId: 'spots',
        );
        await _pumpUntil(
          tester,
          find.descendant(
            of: find.byKey(const Key('tasks-before-day')),
            matching: find.byType(Image),
          ),
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == asset,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('К Финни'));
        await tester.tap(find.text('К Финни'));
        await _pumpUntil(tester, find.byKey(const Key('home-start-day')));
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
        );
        expect(
          await tester.runAsync(() => games.getCurrentPeriod(profile.id!)),
          isNull,
        );
      },
    );
  }
  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    for (final day in [1, 2, 3, 4, 5]) {
      testWidgets('Tasks hub and Day $day focused route at $size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final database = createTestDatabase();
        final profiles = SqliteProfileRepository(database);
        final games = SqliteGameRepository(database);
        await tester.runAsync(() async {
          final profile = await profiles.create(
            Profile(
              gameName: 'Игрок',
              profileType: ProfileType.normal,
              onboardingCompleted: true,
              createdAt: DateTime.utc(2026),
            ),
          );
          final profileId = profile.id!;
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
            definitionId: 'period_$day',
            periodNumber: day,
            baseIncome: 500,
            requiredCheckpoints: const ['financial_task', 'savings_decision'],
            createdAt: DateTime.utc(2026, 1, day),
          );
          await confirmBudgetForTest(
            games,
            profileId: profileId,
            periodId: period.id!,
          );
        });
        final shopItems = await tester.runAsync(
          () => AssetContentRepository().loadShopItems(),
        );
        final tasks = await tester.runAsync(
          () => AssetContentRepository().loadTasks(),
        );
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            contentRepositoryProvider.overrideWithValue(
              TestContentRepository(
                testPeriodDefinitions(count: 5),
                tasks: tasks,
                shopItems: shopItems!,
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
            child: const FinnyApp(),
          ),
        );
        await _pumpUntil(tester, find.byType(NavigationBar));
        await tester.tap(find.byKey(const Key('nav-tasks')));
        final taskId = switch (day) {
          1 => 'task_need_or_want_01',
          2 => 'task_priority_02',
          3 => 'task_changed_plan_03',
          4 => 'task_shopping_trip_04',
          _ => 'task_independent_budget_05',
        };
        await _pumpUntil(tester, find.byKey(Key('task-open-$taskId')));
        expect(find.text('День $day'), findsOneWidget);
        expect(find.byKey(Key('task-card-$taskId')), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(Key('task-open-$taskId')));
        await _pumpUntil(
          tester,
          find.byKey(
            Key(switch (day) {
              1 => 'categorization-task-screen',
              2 => 'budget-priority-task-screen',
              3 => 'plan-adaptation-task-screen',
              4 => 'shopping-trip-screen',
              _ => 'independent-budget-task-screen',
            }),
          ),
        );
        expect(find.byType(NavigationBar).hitTestable(), findsNothing);
        expect(find.byTooltip('Закрыть'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Закрыть'));
        await _pumpUntil(tester, find.byType(NavigationBar));
        expect(find.byKey(Key('task-open-$taskId')), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (day == 5) {
          const secondTaskId = 'task_plan_repair_05';
          await tester.ensureVisible(
            find.byKey(const Key('task-open-$secondTaskId')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('task-open-$secondTaskId')));
          await _pumpUntil(
            tester,
            find.byKey(const Key('plan-repair-task-screen')),
          );
          expect(find.byType(NavigationBar).hitTestable(), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Закрыть'));
          await _pumpUntil(tester, find.byType(NavigationBar));
        }
        for (var attempt = 0; attempt < 100; attempt++) {
          if (container.read(shopControllerProvider).load != ShopLoad.loading) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(
          container.read(shopControllerProvider).load,
          isNot(ShopLoad.loading),
        );
      });
    }
  }
}
