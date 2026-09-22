import 'dart:math';

import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/tasks/shopping_trip_task_screen.dart';
import 'package:finny/features/tasks/tasks_controller.dart';
import 'package:finny/models/financial_task.dart';
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

class _ActiveProfile extends ActiveProfileIdController {
  _ActiveProfile(this.id);
  final int id;
  @override
  int? build() => id;
}

class _FixedRandom implements Random {
  int calls = 0;
  final ints = [0, 1, 0];
  final bools = [true, false, true];
  int _intIndex = 0;
  int _boolIndex = 0;
  @override
  int nextInt(int max) {
    calls++;
    return ints[_intIndex++ % ints.length] % max;
  }

  @override
  bool nextBool() {
    calls++;
    return bools[_boolIndex++ % bools.length];
  }

  @override
  double nextDouble() => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SqliteGameRepository games;
  late ProviderContainer container;
  late FinancialTask task;
  late _FixedRandom random;
  late int profileId;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    task = (await AssetContentRepository().loadTasks()).singleWhere(
      (task) => task.id == 'task_shopping_trip_04',
    );
    final profile = await SqliteProfileRepository(database).create(
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
        satiety: 80,
        care: 80,
        mood: 80,
      ),
    );
    final period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_4_discount',
      periodNumber: 4,
      baseIncome: 500,
      requiredCheckpoints: const ['financial_task', 'savings_decision'],
      createdAt: DateTime.utc(2026),
    );
    await confirmBudgetForTest(
      games,
      profileId: profileId,
      periodId: period.id!,
    );
    container = ProviderContainer(
      overrides: [
        activeProfileIdProvider.overrideWith(() => _ActiveProfile(profileId)),
        appDatabaseProvider.overrideWithValue(database),
        contentRepositoryProvider.overrideWithValue(
          TestContentRepository(testPeriodDefinitions(count: 5), tasks: [task]),
        ),
      ],
    );
    await container.read(tasksControllerProvider.notifier).load();
    random = _FixedRandom();
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => ShoppingTripTaskScreen(
                      task: task,
                      controller: container.read(
                        tasksControllerProvider.notifier,
                      ),
                      random: random,
                    ),
                  ),
                ),
                child: const Text('Открыть задание'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть задание'));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> waitForText(WidgetTester tester, String text) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text(text).evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text(text), findsOneWidget);
  }

  testWidgets(
    'intro, fixed shelves, stable random and quantity controls on 360dp',
    (tester) async {
      await mount(tester);
      expect(
        find.text('Купи всё из списка и уложись в 190 монет.'),
        findsOneWidget,
      );
      expect(find.text('Вода — не меньше 1 л'), findsOneWidget);
      expect(find.text('Мыло — не меньше 3 шт.'), findsOneWidget);
      expect(find.text('Печенье — не меньше 300 г'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.text('Купи всё из списка и уложись в 190 монет.'),
            )
            .style
            ?.fontSize,
        greaterThanOrEqualTo(18),
      );
      expect(random.calls, 6);
      await tapKey(tester, 'shopping-enter');
      expect(find.text('1 из 3 · Вода'), findsOneWidget);
      expect(find.text('25 🪙'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('shopping-shelf-header')))
            .style
            ?.fontSize,
        greaterThanOrEqualTo(22),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('shopping-requirement')))
            .style
            ?.fontSize,
        greaterThanOrEqualTo(18),
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('shopping-product-price-water-small')),
            )
            .style
            ?.fontSize,
        greaterThanOrEqualTo(19),
      );
      expect(find.byKey(const Key('shopping-cart-bar')), findsOneWidget);
      expect(find.byKey(const Key('shopping-cart-icon')), findsOneWidget);
      expect(find.byKey(const Key('shopping-cart-count-badge')), findsNothing);
      expect(find.text('Корзина'), findsOneWidget);
      expect(find.text('0 товаров · 0 / 190 🪙'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('shopping-cart-title')))
            .style
            ?.fontSize,
        greaterThanOrEqualTo(18),
      );
      final smallX = tester
          .getTopLeft(find.byKey(const Key('shopping-product-water-small')))
          .dx;
      final largeX = tester
          .getTopLeft(find.byKey(const Key('shopping-product-water-large')))
          .dx;
      expect(smallX, lessThan(largeX));
      await tapKey(tester, 'shopping-plus-water-small');
      await tapKey(tester, 'shopping-plus-water-small');
      final plus = tester.widget<IconButton>(
        find.byKey(const Key('shopping-plus-water-small')),
      );
      expect(plus.onPressed, isNull);
      expect(find.text('2 товара · 50 / 190 🪙'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('shopping-cart-count-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'shopping-cart-bar');
      expect(find.text('0,5 л ×2 — 50 🪙'), findsOneWidget);
      await tester.tap(find.byTooltip('Убрать Вода 0,5 л'));
      await tester.pumpAndSettle();
      expect(find.text('Итого: 25 / 190 🪙'), findsOneWidget);
      await tester.tap(find.text('Закрыть').last);
      await tester.pumpAndSettle();
      await tapKey(tester, 'shopping-next');
      expect(find.text('2 из 3 · Мыло'), findsOneWidget);
      await tapKey(tester, 'shopping-next');
      expect(find.text('3 из 3 · Печенье'), findsOneWidget);
      expect(random.calls, 6);
      await tester.tap(find.text('← Назад'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('← Назад'));
      await tester.pumpAndSettle();
      expect(find.text('1 из 3 · Вода'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('shopping-product-water-small')))
            .dx,
        smallX,
      );
      expect(random.calls, 6);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'over-budget checkout preserves basket; 190 succeeds without reshuffle',
    (tester) async {
      await mount(tester);
      await tapKey(tester, 'shopping-enter');
      await tapKey(tester, 'shopping-plus-water-large');
      await tapKey(tester, 'shopping-next');
      await tapKey(tester, 'shopping-plus-soap-small');
      await tapKey(tester, 'shopping-plus-soap-small');
      await tapKey(tester, 'shopping-next');
      await tapKey(tester, 'shopping-plus-cookies-large');
      expect(find.textContaining('210 / 190 🪙'), findsOneWidget);
      await tapKey(tester, 'shopping-next');
      expect(find.text('Касса'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('shopping-checkout-total')))
            .style
            ?.fontSize,
        greaterThanOrEqualTo(20),
      );
      expect(find.text('Корзина дороже бюджета на 20 монет.'), findsNothing);
      await tapKey(tester, 'shopping-check');
      await waitForText(tester, 'Корзина дороже бюджета на 20 монет.');
      expect(find.text('Корзина дороже бюджета на 20 монет.'), findsOneWidget);
      expect(random.calls, 6);
      await tester.tap(find.text('← Назад к полкам'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'shopping-minus-cookies-large');
      await tapKey(tester, 'shopping-plus-cookies-small');
      await tapKey(tester, 'shopping-plus-cookies-small');
      await tester.tap(find.text('← Назад'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'shopping-minus-soap-small');
      await tapKey(tester, 'shopping-minus-soap-small');
      await tapKey(tester, 'shopping-plus-soap-large');
      await tapKey(tester, 'shopping-next');
      expect(find.textContaining('190 / 190 🪙'), findsOneWidget);
      await tapKey(tester, 'shopping-next');
      await tapKey(tester, 'shopping-check');
      await waitForText(tester, 'Покупки готовы!');
      expect(find.text('Покупки готовы!'), findsOneWidget);
      expect(find.text('Потрачено: 190 🪙'), findsOneWidget);
      expect(find.text('+50 монет'), findsOneWidget);
      expect(random.calls, 6);
      expect(
        (await tester.runAsync(() => games.getGameState(profileId)))!
            .walletBalance,
        550,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty exit is immediate; nonempty exit asks and next attempt starts empty',
    (tester) async {
      await mount(tester);
      await tapKey(tester, 'shopping-enter');
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Открыть задание'), findsOneWidget);
      await tester.tap(find.text('Открыть задание'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'shopping-enter');
      await tapKey(tester, 'shopping-plus-water-small');
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      expect(find.text('Выйти из магазина?'), findsOneWidget);
      expect(find.text('Корзина очистится.'), findsOneWidget);
      await tester.tap(find.text('Остаться'));
      await tester.pumpAndSettle();
      expect(find.text('1 товар · 25 / 190 🪙'), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть задание'));
      await tester.pumpAndSettle();
      await tapKey(tester, 'shopping-enter');
      expect(find.text('0 товаров · 0 / 190 🪙'), findsOneWidget);
    },
  );
}
