import 'dart:math';

import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
import 'package:finny/models/story_event.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

const _story = StoryPurchase(
  id: 'day3_bowl_replacement',
  name: 'Новая миска',
  period: 3,
  price: 120,
  category: ShopItemCategory.need,
  checkpoint: 'changed_circumstance',
);

const _promotion = ShopPromotion(
  id: 'day4_treat_discount',
  period: 4,
  itemId: 'food_treat',
  promoPrice: 35,
  maxPromoQuantity: 1,
  checkpoint: 'discount_decision',
);

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

class _ActiveProfile extends ActiveProfileIdController {
  _ActiveProfile(this.id);
  final int id;

  @override
  int? build() => id;
}

void main() {
  late AppDatabase database;
  late SqliteGameRepository games;
  late SqliteProfileRepository profiles;
  late TestContentRepository content;

  setUp(() {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    profiles = SqliteProfileRepository(database);
    content = TestContentRepository(
      testPeriodDefinitions(count: 5),
      shopItems: const [_treat],
      stories: const [_story],
      promotions: const [_promotion],
      tasks: [
        testPlanAdaptationTask(),
        for (var day = 1; day <= 5; day++)
          if (day != 3) testFinancialTask(day),
      ],
    );
  });
  tearDown(() => database.close());

  Future<({int profileId, GamePeriod period})> activeDay(
    int day,
    List<String> checkpoints,
  ) async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    await games.ensureInitialState(profile.id!);
    var period = await games.startPeriod(
      profileId: profile.id!,
      definitionId: 'period_$day',
      periodNumber: day,
      baseIncome: 500,
      requiredCheckpoints: checkpoints,
      createdAt: DateTime.utc(2026),
    );
    period = await games.confirmBudget(
      profileId: profile.id!,
      periodId: period.id!,
    );
    return (profileId: profile.id!, period: period);
  }

  ProviderContainer containerFor(
    int profileId,
    SpecialPurchaseService service,
  ) => ProviderContainer(
    overrides: [
      activeProfileIdProvider.overrideWith(() => _ActiveProfile(profileId)),
      gameRepositoryProvider.overrideWithValue(games),
      contentRepositoryProvider.overrideWithValue(content),
      specialPurchaseServiceProvider.overrideWithValue(service),
      storyEventPortProvider.overrideWithValue(
        SqliteStoryEventPort(database, random: Random(1)),
      ),
    ],
  );

  test('Day 3 event charges Need once and retry reuses operationId', () async {
    final player = await activeDay(3, const [
      'financial_task',
      'savings_decision',
      'changed_circumstance',
    ]);
    final service = SpecialPurchaseService(
      SqliteSpecialPurchasePort(database),
      content,
    );
    final container = containerFor(player.profileId, service);
    addTearDown(container.dispose);
    final controller = container.read(campaignEventControllerProvider.notifier);

    await TaskService(
      games,
      SqliteTaskCompletionPort(database),
      content,
    ).submitPlanAdaptation(
      profileId: player.profileId,
      periodId: player.period.id!,
      taskId: 'task_changed_plan_03',
      assignments: const {
        'food': 'keep',
        'shampoo': 'keep',
        'toy': 'later',
        'savings': 'keep',
      },
    );
    await controller.load();
    final armed = await SqliteStoryEventPort(database, random: Random(1))
        .loadDay3Bowl(
          profileId: player.profileId,
          qualifyingActionIds: const {'free:pet', 'food_treat'},
        );
    expect(armed?.status, StoryEventStatus.armed);
    for (var i = 0; i < armed!.threshold; i++) {
      final db = await database.database;
      await db.insert('pet_action_operations', {
        'profile_id': player.profileId,
        'operation_id': 'fixture-pet-$i',
        'period_id': player.period.id,
        'action_id': i == 0 ? 'free:pet' : 'item:food_treat',
        'usage_slot': 'default',
        'created_at': DateTime.now()
            .toUtc()
            .add(Duration(seconds: i))
            .toIso8601String(),
      });
    }
    await controller.load();
    expect(
      (container.read(
        campaignEventControllerProvider,
      ) as CampaignEventReady).kind,
      CampaignEventKind.day3Bowl,
    );
    expect(await controller.purchaseBowl(), isTrue);
    expect(
      container.read(campaignEventControllerProvider),
      isA<CampaignEventReady>(),
    );

    final state = await games.getGameState(player.profileId);
    final period = await games.getPeriodById(
      player.profileId,
      player.period.id!,
    );
    expect(state?.walletBalance, 430);
    expect(period?.actualNeed, 120);
    expect(period?.plannedNeed, 0);
    expect(period?.resolvedCheckpoints, contains('changed_circumstance'));
    expect(
      await games.getInventoryQuantity(
        player.profileId,
        'day3_bowl_replacement',
      ),
      0,
    );
  });

  test(
    'postponed bowl stays open after an unaffordable later purchase',
    () async {
      final player = await activeDay(3, const [
        'financial_task',
        'savings_decision',
        'changed_circumstance',
      ]);
      final container = containerFor(
        player.profileId,
        SpecialPurchaseService(SqliteSpecialPurchasePort(database), content),
      );
      addTearDown(container.dispose);
      final controller = container.read(
        campaignEventControllerProvider.notifier,
      );
      await TaskService(
        games,
        SqliteTaskCompletionPort(database),
        content,
      ).submitPlanAdaptation(
        profileId: player.profileId,
        periodId: player.period.id!,
        taskId: 'task_changed_plan_03',
        assignments: const {
          'food': 'keep',
          'shampoo': 'keep',
          'toy': 'later',
          'savings': 'keep',
        },
      );
      await controller.load();
      final db = await database.database;
      for (var i = 0; i < 2; i++) {
        await db.insert('pet_action_operations', {
          'profile_id': player.profileId,
          'operation_id': 'pet-after-task-$i',
          'period_id': player.period.id,
          'action_id': 'free:pet',
          'usage_slot': 'default',
          'created_at': DateTime.now()
              .toUtc()
              .add(Duration(seconds: i))
              .toIso8601String(),
        });
      }
      await controller.load();
      expect(await controller.postponeBowl(), isTrue);
      await db.update(
        'game_states',
        {'wallet_balance': 20, 'saved_amount': 30},
        where: 'profile_id = ?',
        whereArgs: [player.profileId],
      );
      expect(await controller.prepareBowlPurchase(), isTrue);
      expect(await controller.purchaseBowlFromSavings(), isFalse);
      final state = container.read(campaignEventControllerProvider);
      expect(state, isA<CampaignEventReady>());
      final ready = state as CampaignEventReady;
      expect(ready.storyEvent?.status, StoryEventStatus.postponed);
      expect(ready.storyEvent?.walletBalance, 20);
      expect(ready.storyEvent?.savedAmount, 30);
      expect(ready.pending, isNotNull);
      expect(ready.message, contains('не хватает монет'));
    },
  );

  test(
    'Day 4 promotion appears only after task and BUY is canonical once',
    () async {
      final player = await activeDay(4, const [
        'financial_task',
        'savings_decision',
        'discount_decision',
      ]);
      final service = SpecialPurchaseService(
        SqliteSpecialPurchasePort(database),
        content,
      );
      final container = containerFor(player.profileId, service);
      addTearDown(container.dispose);
      final controller = container.read(
        campaignEventControllerProvider.notifier,
      );

      await controller.load();
      expect(
        container.read(campaignEventControllerProvider),
        isA<CampaignEventIdle>(),
      );
      await TaskService(
        games,
        SqliteTaskCompletionPort(database),
        content,
      ).submitAnswer(
        profileId: player.profileId,
        periodId: player.period.id!,
        taskId: 'task_period_4',
        answerId: 'apple',
      );
      await controller.load();
      expect(
        (container.read(
          campaignEventControllerProvider,
        ) as CampaignEventReady).kind,
        CampaignEventKind.day4Promotion,
      );
      expect(await controller.buyPromotion(), isTrue);
      expect((await games.getGameState(player.profileId))?.walletBalance, 515);
      expect(
        await games.getInventoryQuantity(player.profileId, 'food_treat'),
        1,
      );
      expect(
        (await games.getPeriodById(
          player.profileId,
          player.period.id!,
        ))?.resolvedCheckpoints,
        contains('discount_decision'),
      );
    },
  );
}
