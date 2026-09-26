import 'dart:async';

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
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
  name: 'Наушники',
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

const itemFrisbee = ShopItem(
  id: 'toy_frisbee',
  name: 'Фрисби',
  category: ShopItemCategory.want,
  price: 140,
  persistent: true,
  effectType: 'mood',
  effectValue: 40,
  unlockType: 'available',
  displaySection: ShopDisplaySection.toys,
  usagePolicy: ItemUsagePolicy.oncePerPeriod,
);

class _BrokenThingsContent extends TestContentRepository {
  _BrokenThingsContent() : super(const []);

  @override
  Future<List<ShopItem>> loadShopItems() async => throw StateError('content');
}

class _PendingThingsContent extends TestContentRepository {
  _PendingThingsContent(this.completer) : super(const []);

  final Completer<List<ShopItem>> completer;

  @override
  Future<List<ShopItem>> loadShopItems() => completer.future;
}

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
  late List<ShopItem> canonicalItems;
  setUpAll(() async {
    canonicalItems = await AssetContentRepository().loadShopItems();
  });

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

  testWidgets('loading keeps the Things layout and settles to empty', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final pending = Completer<List<ShopItem>>();
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(
          _ThingsGames(database, activePeriod),
        ),
        contentRepositoryProvider.overrideWithValue(
          _PendingThingsContent(pending),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const ThingsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Вещи'), findsOneWidget);
    expect(find.byKey(const Key('things-filters')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('things-empty')), findsOneWidget);
  });

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
    'inventory renders only owned items without prices or stat effects',
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

      expect(find.byKey(const Key('things-grid')), findsOneWidget);
      expect(find.byKey(const Key('things-item-food_apple')), findsOneWidget);
      expect(
        find.byKey(const Key('things-item-care_toothbrush')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('things-item-toy_ball')), findsOneWidget);
      expect(
        find.byKey(const Key('things-item-accessory_bow')),
        findsOneWidget,
      );
      expect(find.text('Яблоко'), findsOneWidget);
      expect(find.text('Сытость +20'), findsNothing);
      expect(find.text('40'), findsNothing);
      expect(find.text('Зубная щётка'), findsOneWidget);
      expect(
        find.byKey(const Key('things-use-care_toothbrush')),
        findsOneWidget,
      );
      expect(find.text('Мяч'), findsOneWidget);
      expect(find.text('Наушники'), findsOneWidget);
      expect(find.byKey(const Key('things-use-accessory_bow')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('things-equip-accessory_bow')),
            )
            .onPressed,
        isNull,
      );
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

    expect(find.text('Яблоко'), findsOneWidget);
    final useBtn = find.byKey(const Key('things-use-food_apple'));
    expect(useBtn, findsOneWidget);

    await tester.tap(useBtn);
    await tester.pumpAndSettle();

    // After use, quantity is 0, so empty state should show
    expect(find.byKey(const Key('things-empty')), findsOneWidget);
    expect(find.text('Яблоко'), findsNothing);
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
      expect(find.byKey(const Key('things-play-toy_ball')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('things-play-toy_ball')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('filters keep only owned items and room has an empty state', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = _ThingsGames(database, activePeriod);
    games.inventory = {
      itemApple.id: 1,
      itemBrush.id: 1,
      itemBall.id: 1,
      itemBow.id: 1,
    };
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(
          TestContentRepository(
            const [],
            shopItems: [itemApple, itemBrush, itemBall, itemBow, itemFrisbee],
          ),
        ),
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

    expect(find.byKey(const Key('things-item-toy_frisbee')), findsNothing);
    for (final (filter, itemId) in [
      ('food', itemApple.id),
      ('care', itemBrush.id),
      ('toys', itemBall.id),
    ]) {
      await tester.tap(find.byKey(Key('things-filter-$filter')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('things-item-$itemId')), findsOneWidget);
      expect(find.byKey(const Key('things-item-toy_frisbee')), findsNothing);
      expect(
        find.byKey(const Key('things-item-accessory_bow')),
        filter == 'accessories' ? findsOneWidget : findsNothing,
      );
    }
    await tester.drag(
      find.byKey(const Key('things-filters')),
      const Offset(-450, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('things-filter-room')));
    await tester.pumpAndSettle();
    expect(
      find.text('В категории «Комната» пока нет твоих вещей.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('things-filter-accessories')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('things-item-accessory_bow')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('things-filters')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('things-filter-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('things-item-food_apple')), findsOneWidget);
    expect(find.byKey(const Key('things-item-toy_ball')), findsOneWidget);
  });

  testWidgets('Ball opens its existing route even after systemic use', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = _ThingsGames(database, activePeriod);
    games.inventory = {itemBall.id: 1};
    games.usages['item:${itemBall.id}:${PetActionSlot.defaultSlot.storageValue}'] =
        1;
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(
          TestContentRepository(const [], shopItems: [itemBall]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/things',
      routes: [
        GoRoute(path: '/things', builder: (_, _) => const ThingsScreen()),
        GoRoute(
          path: '/toy-ball',
          builder: (_, _) => const Scaffold(body: Text('Ball route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('things-play-toy_ball')));
    await tester.pumpAndSettle();
    expect(find.text('Ball route'), findsOneWidget);
  });

  testWidgets(
    'Frisbee opens its route after systemic use without instant mood',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final games = _ThingsGames(database, activePeriod);
      games.inventory = {itemFrisbee.id: 1};
      final usageKey =
          'item:${itemFrisbee.id}:${PetActionSlot.defaultSlot.storageValue}';
      games.usages[usageKey] = 1;
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
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository(const [], shopItems: [itemFrisbee]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/things',
        routes: [
          GoRoute(path: '/things', builder: (_, _) => const ThingsScreen()),
          GoRoute(
            path: '/toy-frisbee',
            builder: (_, _) => const Scaffold(body: Text('Frisbee route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('things-play-toy_frisbee')));
      await tester.pumpAndSettle();
      expect(find.text('Frisbee route'), findsOneWidget);
      expect(games.usages[usageKey], 1);
    },
  );

  testWidgets('Frisbee can play while Car cannot grant instant rewards', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = _ThingsGames(database, activePeriod);
    games.inventory = {'toy_ball': 1, 'toy_frisbee': 1, 'toy_plush': 1};
    final toys = canonicalItems
        .where((item) => item.displaySection == ShopDisplaySection.toys)
        .toList();
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(
          TestContentRepository(const [], shopItems: toys),
        ),
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

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('things-play-toy_ball')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('things-play-toy_frisbee')),
          )
          .onPressed,
      isNotNull,
    );
    final carButton = find.byKey(const Key('things-use-toy_plush'));
    expect(carButton, findsOneWidget);
    expect(tester.widget<FilledButton>(carButton).onPressed, isNull);
    expect(games.usages, isEmpty);
  });

  testWidgets('owned catalog keeps all 12 final names across Things filters', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = _ThingsGames(database, activePeriod);
    final catalog = canonicalItems;
    games.inventory = {for (final item in catalog) item.id: 1};
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(
          TestContentRepository(const [], shopItems: catalog),
        ),
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

    for (final (filter, section) in [
      ('food', ShopDisplaySection.food),
      ('care', ShopDisplaySection.care),
      ('toys', ShopDisplaySection.toys),
      ('accessories', ShopDisplaySection.accessories),
    ]) {
      final chip = find.byKey(Key('things-filter-$filter'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      final items = catalog.where((item) => item.displaySection == section);
      expect(items, hasLength(3));
      for (final item in items) {
        final card = find.byKey(Key('things-item-${item.id}'));
        expect(card, findsOneWidget, reason: item.id);
        expect(
          find.descendant(of: card, matching: find.text(item.name)),
          findsOneWidget,
          reason: item.id,
        );
      }
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(360, 800), const Size(393, 852)]) {
    testWidgets(
      'mouse drag reaches Room and Accessories and reveals selection at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final database = createTestDatabase();
        addTearDown(database.close);
        final games = _ThingsGames(database, activePeriod);
        games.inventory = {for (final item in canonicalItems) item.id: 1};
        final container = ProviderContainer(
          overrides: [
            campaignLifecycleServiceProvider.overrideWithValue(
              CampaignOnlyLifecycleService(),
            ),
            appDatabaseProvider.overrideWithValue(database),
            activeProfileIdProvider.overrideWith(
              () => _ActiveThingsProfileMock(1),
            ),
            profileRepositoryProvider.overrideWithValue(
              _ThingsProfiles(profile),
            ),
            gameRepositoryProvider.overrideWithValue(games),
            contentRepositoryProvider.overrideWithValue(
              TestContentRepository(const [], shopItems: canonicalItems),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const ThingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final row = find.byKey(const Key('things-filters'));
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: row, matching: find.byType(Scrollable)),
            )
            .position;
        expect(position.pixels, 0);
        await tester.drag(
          row,
          const Offset(-150, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        for (
          var attempt = 0;
          attempt < 8 && position.pixels < position.maxScrollExtent - 1;
          attempt++
        ) {
          await tester.drag(
            row,
            const Offset(-150, 0),
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();
        }

        final room = find.byKey(const Key('things-filter-room'));
        final accessories = find.byKey(const Key('things-filter-accessories'));
        expect(tester.getRect(room).center.dx, greaterThan(0));
        expect(tester.getRect(room).center.dx, lessThan(size.width));
        expect(
          tester.getRect(accessories).right,
          lessThanOrEqualTo(size.width - 16),
        );
        await tester.tap(room);
        await tester.pumpAndSettle();
        expect(
          find.text('В категории «Комната» пока нет твоих вещей.'),
          findsOneWidget,
        );
        expect(tester.getRect(room).left, greaterThanOrEqualTo(16));
        expect(tester.getRect(room).right, lessThanOrEqualTo(size.width - 16));

        position.jumpTo(position.maxScrollExtent - 24);
        await tester.pump();
        expect(tester.getRect(accessories).right, greaterThan(size.width - 16));
        await tester.tap(accessories);
        await tester.pumpAndSettle();
        expect(tester.getRect(accessories).left, greaterThanOrEqualTo(16));
        expect(
          tester.getRect(accessories).right,
          lessThanOrEqualTo(size.width - 16),
        );
        expect(
          find.byKey(const Key('things-item-accessory_bow')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('two-column Things grid fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createTestDatabase();
      addTearDown(database.close);
      final games = _ThingsGames(database, activePeriod);
      games.inventory = {
        itemApple.id: 1,
        itemBrush.id: 1,
        itemBall.id: 1,
        itemBow.id: 1,
      };
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
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository(
              const [],
              shopItems: [itemApple, itemBrush, itemBall, itemBow],
            ),
          ),
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
      expect(tester.takeException(), isNull);
      final grid = tester.widget<GridView>(
        find.byKey(const Key('things-grid')),
      );
      expect(
        (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        2,
      );
      final useLabel = find.descendant(
        of: find.byKey(const Key('things-use-food_apple')),
        matching: find.text('Использовать'),
      );
      expect(tester.getSize(useLabel).height, lessThan(24));
      await tester.drag(
        find.byKey(const Key('things-grid')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('things-item-accessory_bow')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('content error offers a retry', (tester) async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        activeProfileIdProvider.overrideWith(() => _ActiveThingsProfileMock(1)),
        profileRepositoryProvider.overrideWithValue(_ThingsProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(
          _ThingsGames(database, activePeriod),
        ),
        contentRepositoryProvider.overrideWithValue(_BrokenThingsContent()),
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
    expect(
      find.text('Не получилось загрузить вещи. Попробуй ещё раз.'),
      findsOneWidget,
    );
    expect(find.text('Попробовать снова'), findsOneWidget);
    await tester.tap(find.text('Попробовать снова'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не получилось загрузить вещи. Попробуй ещё раз.'),
      findsOneWidget,
    );
  });
}

class _ActiveThingsProfileMock extends ActiveProfileIdController {
  _ActiveThingsProfileMock(this.id);
  final int id;
  @override
  int? build() => id;
}
