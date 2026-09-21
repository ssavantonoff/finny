import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/models/content_entry.dart';
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

const _treat = ShopItem(
  id: 'food_treat',
  name: 'Лакомство',
  category: ShopItemCategory.want,
  price: 60,
  persistent: false,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  usagePolicy: ItemUsagePolicy.unlimited,
  effects: PetStatEffects(satiety: 10, mood: 10),
);

const _promotion = ShopPromotion(
  id: 'day4_treat_discount',
  period: 4,
  itemId: 'food_treat',
  promoPrice: 35,
  maxPromoQuantity: 1,
  checkpoint: 'discount_decision',
);

const _bowlStory = StoryPurchase(
  id: 'day3_bowl_replacement',
  name: 'Временная миска',
  period: 3,
  price: 120,
  category: ShopItemCategory.need,
  checkpoint: 'changed_circumstance',
);

const _dayFour = PeriodDefinition(
  id: 'period_4',
  number: 4,
  title: 'День скидок',
  baseIncome: 500,
  requiredCheckpoints: [
    'financial_task',
    'savings_decision',
    'discount_decision',
  ],
);

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

void main() {
  testWidgets(
    'Day 4 task returns through persistent shell and opens promotion',
    (tester) async {
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
            developmentStage: 2,
            growthPoints: 0,
            satiety: 100,
            care: 100,
            mood: 100,
          ),
        );
        final started = await games.startPeriod(
          profileId: profileId,
          definitionId: _dayFour.id,
          periodNumber: _dayFour.number,
          baseIncome: _dayFour.baseIncome,
          requiredCheckpoints: _dayFour.requiredCheckpoints,
          createdAt: DateTime.utc(2026, 1, 4),
        );
        await confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: started.id!,
        );
      });

      final content = TestContentRepository(
        const [_dayFour],
        shopItems: const [_treat],
        tasks: [testFinancialTask(4)],
        stories: const [_bowlStory],
        promotions: const [_promotion],
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          contentRepositoryProvider.overrideWithValue(content),
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

      final tasksTab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Задания'),
      );
      await tester.tap(tasksTab);
      await _pumpUntil(
        tester,
        find.byKey(const Key('task-open-task_period_4')),
      );
      await tester.tap(find.byKey(const Key('task-open-task_period_4')));
      await _pumpUntil(tester, find.byKey(const Key('task-submit')));
      await tester.tap(find.text('Яблоко'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('task-submit')));
      await _pumpUntil(tester, find.text('Верно!'));

      await tester.tap(find.text('Готово'));
      await _pumpUntil(tester, find.text('Сегодня акция!'));

      final home = container.read(homeControllerProvider) as HomeReady;
      expect(home.period?.resolvedCheckpoints, contains('financial_task'));
      expect(find.byKey(const Key('campaign-promo-buy')), findsOneWidget);
      expect(find.byKey(const Key('campaign-promo-skip')), findsOneWidget);
    },
  );
}
