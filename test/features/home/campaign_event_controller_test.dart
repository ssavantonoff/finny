import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/home/campaign_event_controller.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/special_purchase.dart';
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

class _RetrySpecialService extends SpecialPurchaseService {
  _RetrySpecialService(super.port, super.content);

  bool failNext = true;
  final operationIds = <String>[];

  @override
  Future<GameState> purchaseStory({
    required int profileId,
    required int periodId,
    required String storyPurchaseId,
    required String operationId,
  }) async {
    operationIds.add(operationId);
    if (failNext) {
      failNext = false;
      throw StateError('temporary result failure');
    }
    return super.purchaseStory(
      profileId: profileId,
      periodId: periodId,
      storyPurchaseId: storyPurchaseId,
      operationId: operationId,
    );
  }
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
    ],
  );

  test('Day 3 event charges Need once and retry reuses operationId', () async {
    final player = await activeDay(3, const [
      'financial_task',
      'savings_decision',
      'changed_circumstance',
    ]);
    final service = _RetrySpecialService(
      SqliteSpecialPurchasePort(database),
      content,
    );
    final container = containerFor(player.profileId, service);
    addTearDown(container.dispose);
    final controller = container.read(campaignEventControllerProvider.notifier);

    await controller.load();
    expect(
      (container.read(
        campaignEventControllerProvider,
      ) as CampaignEventReady).kind,
      CampaignEventKind.day3Bowl,
    );
    expect(await controller.purchaseBowl(), isFalse);
    expect(
      container.read(campaignEventControllerProvider),
      isA<CampaignEventReady>(),
    );
    expect(await controller.retry(), isTrue);
    expect(service.operationIds, hasLength(2));
    expect(service.operationIds.toSet(), hasLength(1));

    final state = await games.getGameState(player.profileId);
    final period = await games.getPeriodById(
      player.profileId,
      player.period.id!,
    );
    expect(state?.walletBalance, 380);
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
