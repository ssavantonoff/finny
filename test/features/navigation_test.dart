import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/app/router.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/adult/adult_screen.dart';
import 'package:finny/features/home/home_screen.dart';
import 'package:finny/features/home/home_controller.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/features/settings/settings_screen.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/special_purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

class _PromoNavFixture {
  _PromoNavFixture(this.database, this.games, this.profileId, this.container);

  final AppDatabase database;
  final SqliteGameRepository games;
  final int profileId;
  final ProviderContainer container;

  Future<void> close() async {
    container.dispose();
    await database.close();
  }
}

class _NavProfiles implements ProfileRepository {
  _NavProfiles(this.profile);
  final Profile profile;

  @override
  Future<Profile> create(Profile profile) async => profile;

  @override
  Future<List<Profile>> findAll() async => [profile];

  @override
  Future<Profile?> findById(int id) async => id == profile.id ? profile : null;

  @override
  Future<void> update(Profile profile) async {}
}

class _NavGames extends SqliteGameRepository {
  _NavGames(super.database, this.pet, this.gameState);

  final Pet pet;
  final GameState gameState;

  @override
  Future<GameState> ensureInitialState(int profileId) async => gameState;

  @override
  Future<GameState?> getGameState(int profileId) async => gameState;

  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async => const [];

  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async => null;

  @override
  Future<Pet?> getPet(int profileId) async => pet;

  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestContentRepository promoContent;
  setUpAll(() async {
    final assets = AssetContentRepository();
    promoContent = TestContentRepository(
      testPeriodDefinitions(count: 5),
      shopItems: await assets.loadShopItems(),
      stories: await assets.loadStoryPurchases(),
      promotions: await assets.loadPromotions(),
    );
  });

  Future<_PromoNavFixture> fixture(int day, {bool purchased = false}) async {
    final database = createTestDatabase();
    final games = SqliteGameRepository(database);
    final profile = await SqliteProfileRepository(database).create(
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
        satiety: 80,
        care: 80,
        mood: 80,
      ),
    );
    if (day > 0) {
      final period = await games.startPeriod(
        profileId: profileId,
        definitionId: 'period_$day',
        periodNumber: day,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task', 'savings_decision'],
        createdAt: DateTime.utc(2026),
      );
      if (purchased) {
        await confirmBudgetForTest(
          games,
          profileId: profileId,
          periodId: period.id!,
        );
        await SpecialPurchaseService(
          SqliteSpecialPurchasePort(database),
          promoContent,
        ).purchasePromotion(
          profileId: profileId,
          periodId: period.id!,
          promotionId: 'day4_treat_discount',
          operationId: 'nav-promo-prepurchased',
        );
      }
    }
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        contentRepositoryProvider.overrideWithValue(promoContent),
      ],
    );
    return _PromoNavFixture(database, games, profileId, container);
  }

  Future<void> mountPromoApp(
    WidgetTester tester,
    _PromoNavFixture fixture,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const FinnyApp(),
      ),
    );
    for (var attempt = 0; attempt < 300; attempt++) {
      if (find.byKey(const Key('nav-shop')).evaluate().isNotEmpty &&
          fixture.container.read(shopControllerProvider).load ==
              ShopLoad.ready &&
          fixture.container.read(homeControllerProvider) is HomeReady) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('nav-shop')), findsOneWidget);
    expect(fixture.container.read(shopControllerProvider).load, ShopLoad.ready);
    expect(fixture.container.read(homeControllerProvider), isA<HomeReady>());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'unused Day 4 promo badge appears on Home before Shop and stays selected',
    (tester) async {
      final nav = (await tester.runAsync(() => fixture(4)))!;
      addTearDown(nav.close);
      await mountPromoApp(tester, nav);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
      expect(find.byKey(const Key('nav-shop-promo-badge')), findsOneWidget);
      expect(find.text('АКЦИЯ'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('В магазине действует акция')),
        findsOneWidget,
      );
      final shopIcon = find.descendant(
        of: find.byKey(const Key('nav-shop')),
        matching: find.byIcon(Icons.storefront_outlined),
      );
      final thingsIcon = find.descendant(
        of: find.byKey(const Key('nav-things')),
        matching: find.byIcon(Icons.backpack_outlined),
      );
      final shopLabel = find.descendant(
        of: find.byKey(const Key('nav-shop')),
        matching: find.text('Магазин'),
      );
      final thingsLabel = find.descendant(
        of: find.byKey(const Key('nav-things')),
        matching: find.text('Вещи'),
      );
      expect(
        tester.getCenter(shopIcon).dy,
        closeTo(tester.getCenter(thingsIcon).dy, 1),
      );
      expect(
        tester.getCenter(shopLabel).dy,
        closeTo(tester.getCenter(thingsLabel).dy, 1),
      );
      await tester.tap(find.byKey(const Key('nav-shop')));
      for (var attempt = 0; attempt < 300; attempt++) {
        if (tester
                    .widget<NavigationBar>(find.byType(NavigationBar))
                    .selectedIndex ==
                2 &&
            nav.container.read(shopControllerProvider).load == ShopLoad.ready &&
            find
                .byKey(const Key('nav-shop-promo-badge'))
                .evaluate()
                .isNotEmpty) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 3)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
      expect(find.byKey(const Key('nav-shop-promo-badge')), findsOneWidget);
      final selectedShopIcon = find.descendant(
        of: find.byKey(const Key('nav-shop')),
        matching: find.byIcon(Icons.storefront),
      );
      expect(
        tester.getCenter(selectedShopIcon).dy,
        closeTo(tester.getCenter(thingsIcon).dy, 1),
      );
      expect(
        tester.getCenter(shopLabel).dy,
        closeTo(tester.getCenter(thingsLabel).dy, 1),
      );
      final periodId =
          (nav.container.read(homeControllerProvider) as HomeReady).period!.id!;
      await tester.runAsync(() async {
        await confirmBudgetForTest(
          nav.games,
          profileId: nav.profileId,
          periodId: periodId,
        );
        final shop = nav.container.read(shopControllerProvider.notifier);
        await shop.load();
        await shop.buy(
          'food_treat',
          profileId: nav.profileId,
          periodId: periodId,
        );
      });
      await tester.pump();
      expect(
        nav.container.read(shopControllerProvider).promotionPurchased,
        isTrue,
      );
      expect(find.byKey(const Key('nav-shop-promo-badge')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('persisted purchased promotion has no nav badge on restart', (
    tester,
  ) async {
    final nav = (await tester.runAsync(() => fixture(4, purchased: true)))!;
    addTearDown(nav.close);
    await mountPromoApp(tester, nav);
    expect(
      nav.container.read(shopControllerProvider).promotionPurchased,
      isTrue,
    );
    expect(find.byKey(const Key('nav-shop-promo-badge')), findsNothing);
  });

  for (final day in [1, 2, 3, 5]) {
    testWidgets('Day $day has no Shop promotion badge', (tester) async {
      final nav = (await tester.runAsync(() => fixture(day)))!;
      addTearDown(nav.close);
      await mountPromoApp(tester, nav);
      expect(find.byKey(const Key('nav-shop-promo-badge')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home period refresh reveals Day 4 badge without visiting Shop', (
    tester,
  ) async {
    final nav = (await tester.runAsync(() => fixture(0)))!;
    addTearDown(nav.close);
    await mountPromoApp(tester, nav);
    expect(find.byKey(const Key('nav-shop-promo-badge')), findsNothing);
    await tester.runAsync(
      () => nav.games.startPeriod(
        profileId: nav.profileId,
        definitionId: 'period_4',
        periodNumber: 4,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task', 'savings_decision'],
        createdAt: DateTime.utc(2026),
      ),
    );
    final homeLoad = nav.container.read(homeControllerProvider.notifier).load();
    for (var attempt = 0; attempt < 300; attempt++) {
      if (find.byKey(const Key('nav-shop-promo-badge')).evaluate().isNotEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 3)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await homeLoad;
    expect(find.byKey(const Key('nav-shop-promo-badge')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'bottom navigation, Home settings entry point and outside-shell routes',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(database.close);

      final profile = Profile(
        id: 1,
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final pet = const Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 0,
        growthPoints: 0,
        satiety: 100,
        care: 100,
        mood: 100,
      );
      final gameState = GameState(
        profileId: 1,
        walletBalance: 500,
        currentPeriod: 0,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final profiles = _NavProfiles(profile);
      final games = _NavGames(database, pet, gameState);

      final container = ProviderContainer(
        overrides: [
          profileRepositoryProvider.overrideWithValue(profiles),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(
            TestContentRepository(testPeriodDefinitions()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FinnyApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Bootstrap navigates existing profile with pet to /home
      expect(find.byType(NavigationBar), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations, hasLength(5));

      // Verify exact destination labels and icons in order
      expect((navBar.destinations[0] as NavigationDestination).label, 'Финни');
      expect((navBar.destinations[1] as NavigationDestination).label, 'Вещи');
      expect(
        (navBar.destinations[2] as NavigationDestination).label,
        'Магазин',
      );
      expect(
        (navBar.destinations[3] as NavigationDestination).label,
        'Задания',
      );
      expect(
        (navBar.destinations[4] as NavigationDestination).label,
        'Накопления',
      );
      expect(navBar.selectedIndex, 0);

      Finder navItem(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );

      // Tap "Вещи" (index 1)
      await tester.tap(navItem('Вещи'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );

      // Tap "Магазин" (index 2)
      await tester.tap(navItem('Магазин'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );

      // Tap "Задания" (index 3)
      await tester.tap(navItem('Задания'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );

      // Tap "Накопления" (index 4)
      await tester.tap(navItem('Накопления'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );

      // Tap back to "Финни" (index 0)
      await tester.tap(navItem('Финни'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('home-settings')), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byKey(const Key('settings-help')), findsOneWidget);
      expect(find.byKey(const Key('settings-adult')), findsOneWidget);
      expect(find.text('Финансовые термины'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settings-adult')));
      await tester.pumpAndSettle();

      expect(find.byType(AdultScreen), findsOneWidget);
      expect(find.byKey(const Key('adult-barrier')), findsOneWidget);

      // Navigate to outside-shell route: /budget
      container.read(routerProvider).go('/budget');
      await tester.pumpAndSettle();
      // NavigationBar must NOT be present on /budget
      expect(find.byType(NavigationBar), findsNothing);
    },
  );
}
