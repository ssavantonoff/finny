import 'package:finny/features/tasks/day_five_task_screens.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/models/financial_task.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      ProviderContainer container,
      FinancialTask task,
      Map<String, ShopItem> catalog,
    })
  >
  data(String id) async {
    final content = AssetContentRepository();
    return (
      container: ProviderContainer(),
      task: (await content.loadTasks()).singleWhere((task) => task.id == id),
      catalog: {
        for (final item in await content.loadShopItems()) item.id: item,
      },
    );
  }

  testWidgets('independent budget starts empty and fits 360dp', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = (await tester.runAsync(
      () => data('task_independent_budget_05'),
    ))!;
    addTearDown(fixture.container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          home: IndependentBudgetTaskScreen(
            task: fixture.task,
            controller: fixture.container.read(
              tasksControllerProvider.notifier,
            ),
            shopItems: fixture.catalog,
          ),
        ),
      ),
    );
    expect(find.text('Покупки: 0'), findsOneWidget);
    expect(find.text('На цель: 0'), findsOneWidget);
    expect(find.byKey(const Key('day5-task-feedback')), findsNothing);
    final food = find.byKey(const Key('independent-budget-toggle-food_feed'));
    await tester.ensureVisible(food);
    await tester.tap(food);
    await tester.pump();
    expect(find.text('Покупки: 90'), findsOneWidget);
    expect(find.byKey(const Key('day5-task-feedback')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan repair starts at 410 and allows delaying required food', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = (await tester.runAsync(() => data('task_plan_repair_05')))!;
    addTearDown(fixture.container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: MaterialApp(
          home: PlanRepairTaskScreen(
            task: fixture.task,
            controller: fixture.container.read(
              tasksControllerProvider.notifier,
            ),
            shopItems: fixture.catalog,
          ),
        ),
      ),
    );
    expect(find.text('410 / 350'), findsOneWidget);
    expect(find.text('Не хватает 60 монет'), findsOneWidget);
    final later = find.byKey(const Key('plan-repair-later-food_feed'));
    await tester.ensureVisible(later);
    await tester.tap(later);
    await tester.pump();
    expect(find.text('320 / 350'), findsOneWidget);
    expect(find.byKey(const Key('day5-task-feedback')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
