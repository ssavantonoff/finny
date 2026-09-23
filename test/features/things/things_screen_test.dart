import '../../helpers/campaign_only_lifecycle_service.dart';

import 'package:finny/app/providers.dart';
import 'package:finny/core/theme/app_theme.dart';
import 'package:finny/features/things/things_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';

const itemApple = ShopItem(
  id: 'food_apple',
  name: 'Яблоко',
  category: ShopItemCategory.need,
  price: 40,
  persistent: false,
  effectType: 'satiety',
  effectValue: 20,
  unlockType: 'available',
  displaySection: ShopDisplaySection.food,
  usagePolicy: ItemUsagePolicy.unlimited,
);

const itemBrush = ShopItem(
  id: 'care_toothbrush',
  name: 'Зубная щётка',
  category: ShopItemCategory.need,
  price: 80,
  persistent: true,
  effectType: 'care',
  effectValue: 8,
  unlockType: 'available',
  displaySection: ShopDisplaySection.care,
  usagePolicy: ItemUsagePolicy.toothbrush,
);

const itemBall = ShopItem(
  id: 'toy_ball',
  name: 'Мяч',
  category: ShopItemCategory.want,
  price: 120,
  persistent: true,
  effectType: 'mood',
  effectValue: 35,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

const itemBow = ShopItem(
  id: 'accessory_bow',
  name: 'Бантик',
  category: ShopItemCategory.want,
  price: 80,
  persistent: true,
  effectType: 'none',
  effectValue: 0,
  unlockType: 'available',
  displaySection: ShopDisplaySection.accessories,
  equipSlot: ShopEquipSlot.head,
  usagePolicy: ItemUsagePolicy.none,
);

class _ThingsProfiles implements ProfileRepository {
  _ThingsProfiles(this.profile);
  final Profile profile;

  @override
  Future<Profile> create(Profile profile) async => profile;
  @override
  Future<List<Profile>> findAll() async => [profile];
  @override
  Future<Profile?> findById(int id) async => profile;
  @override
  Future<void> update(Profile profile) async {}
}

class _ThingsGames extends SqliteGameRepository {
  _ThingsGames(super.database, this.period);

  GamePeriod? period;
  Map<String, int> inventory = {};
  Map<String, int> usages = {};

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async =>
      period == null ? const [] : [period!];

  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async => period;

  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async =>
      inventory[itemId] ?? 0;

  @override
  Future<int> getPetDailyUsageCount({
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  }) async {
    final key = '$actionId:${slot.storageValue}';
    return usages[key] ?? 0;
  }
}

class _ThingsMockItemUse extends ItemUseService {
  _ThingsMockItemUse(super.petPort, super.content, this.onUse);

  final Future<Pet> Function(String itemId, PetActionSlot slot) onUse;

  @override
  Future<Pet> useItem({
    required int profileId,
    required int periodId,
    required String itemId,
    required String operationId,
    PetActionSlot slot = PetActionSlot.defaultSlot,
  }) => onUse(itemId, slot);
}

void main() {
  final profile = Profile(
    id: 1,
    gameName: 'Игрок',
    profileType: ProfileType.normal,
    onboardingCompleted: true,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  final activePeriod = GamePeriod(
    id: 10,
    profileId: 1,
    definitionId: 'period_1',
    periodNumber: 1,
    startWalletBalance: 500,
    baseIncome: 500,
    extraIncome: 0,
    plannedNeed: 200,
    plannedWant: 100,
    plannedSavings: 100,
    plannedFree: 100,
    actualNeed: 0,
    actualWant: 0,
    actualSavings: 0,
    requiredCheckpoints: const [],
    resolvedCheckpoints: const [],
    growthPointsEarned: 0,
    status: GamePeriodStatus.active,
    createdAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets(
    'empty state displays when no items are owned with go-to-shop button',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final games = _ThingsGames(database, activePeriod);
      final content = TestContentRepository(
        const [],
        shopItems: [itemApple, itemBrush],
      );

      final container = ProviderContainer(
        overrides: [
          campaignLifecycleServiceProvider.overrideWithValue(
            CampaignOnlyLifecycleService(),
          ),
          appDatabaseProvider.overrideWithValue(database),
          activeProfileIdProvider.overrideWith(
            () => _ActiveThingsProfileMock(1),
          ),
          profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const ThingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('things-empty')), findsOneWidget);
      expect(find.text('У тебя пока нет вещей'), findsOneWidget);
      expect(find.byKey(const Key('things-go-to-shop')), findsOneWidget);
      expect(find.text('Заглянуть в магазин'), findsOneWidget);
    },
  );

  testWidgets(
    'inventory renders owned items with counts, effects and sections',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final games = _ThingsGames(database, activePeriod);
      games.inventory = {
        itemApple.id: 3,
        itemBrush.id: 1,
        itemBall.id: 1,
        itemBow.id: 1,
      };

      final content = TestContentRepository(
        const [],
        shopItems: [itemApple, itemBrush, itemBall, itemBow],
      );

      final container = ProviderContainer(
        overrides: [
          campaignLifecycleServiceProvider.overrideWithValue(
            CampaignOnlyLifecycleService(),
          ),
          appDatabaseProvider.overrideWithValue(database),
          activeProfileIdProvider.overrideWith(
            () => _ActiveThingsProfileMock(1),
          ),
          profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const ThingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Section headers
      expect(find.byKey(const Key('things-section-food')), findsOneWidget);
      expect(find.byKey(const Key('things-section-care')), findsOneWidget);
      expect(find.byKey(const Key('things-section-toys')), findsOneWidget);
      expect(
        find.byKey(const Key('things-section-accessories')),
        findsOneWidget,
      );

      // Consumable count ×3 and effect
      expect(find.text('Яблоко ×3'), findsOneWidget);
      expect(find.text('Сытость +20'), findsOneWidget);

      // Persistent toothbrush: label "Почистить зубы"
      expect(find.text('Зубная щётка'), findsOneWidget);
      expect(find.text('Почистить зубы'), findsOneWidget);

      // Persistent ball: label "Использовать"
      expect(find.text('Мяч'), findsOneWidget);

      // Accessory: shows 'Аксессуар' without use button
      expect(find.text('Бантик'), findsOneWidget);
      expect(find.text('Аксессуар'), findsOneWidget);
      expect(find.byKey(const Key('things-use-accessory_bow')), findsNothing);
    },
  );

  testWidgets('using consumable decrements count and removes when 0', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);

    final games = _ThingsGames(database, activePeriod);
    games.inventory = {itemApple.id: 1};

    final content = TestContentRepository(const [], shopItems: [itemApple]);

    final mockItemUse = _ThingsMockItemUse(
      SqlitePetActionPort(database),
      content,
      (itemId, slot) async {
        games.inventory[itemId] = (games.inventory[itemId] ?? 1) - 1;
        return const Pet(
          profileId: 1,
          name: 'Финни',
          colorId: 'purple',
          patternId: 'spots',
          developmentStage: 0,
          growthPoints: 0,
          satiety: 90,
          care: 60,
          mood: 30,
        );
      },
    );

    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        itemUseServiceProvider.overrideWithValue(mockItemUse),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const ThingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Яблоко ×1'), findsOneWidget);
    final useBtn = find.byKey(const Key('things-use-food_apple'));
    expect(useBtn, findsOneWidget);

    await tester.tap(useBtn);
    await tester.pumpAndSettle();

    // After use, quantity is 0, so empty state should show
    expect(find.byKey(const Key('things-empty')), findsOneWidget);
    expect(find.text('Яблоко ×1'), findsNothing);
  });

  testWidgets(
    'persistent item used today shows «Сегодня использовано» and disables use',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final games = _ThingsGames(database, activePeriod);
      games.inventory = {itemBall.id: 1};
      // Mark ball as used today
      games.usages['item:${itemBall.id}:${PetActionSlot.defaultSlot.storageValue}'] =
          1;

      final content = TestContentRepository(const [], shopItems: [itemBall]);

      final container = ProviderContainer(
        overrides: [
          campaignLifecycleServiceProvider.overrideWithValue(
            CampaignOnlyLifecycleService(),
          ),
          appDatabaseProvider.overrideWithValue(database),
          activeProfileIdProvider.overrideWith(
            () => _ActiveThingsProfileMock(1),
          ),
          profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.light, home: const ThingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Мяч'), findsOneWidget);
      expect(find.text('Сегодня использовано'), findsOneWidget);
      expect(find.byKey(const Key('things-use-toy_ball')), findsNothing);
    },
  );
}

class _ActiveThingsProfileMock extends ActiveProfileIdController {
  _ActiveThingsProfileMock(this.id);
  final int id;
  @override
  int? build() => id;
}
