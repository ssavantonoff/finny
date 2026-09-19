import 'package:finny/app/app.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const syncApple = ShopItem(
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

class _SyncProfiles implements ProfileRepository {
  _SyncProfiles(this.profile);
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

class _SyncGames extends SqliteGameRepository {
  _SyncGames(super.database, this.pet, this.gameState, this.period);

  final Pet pet;
  GameState gameState;
  final GamePeriod period;
  final Map<String, int> inventory = {};

  @override
  Future<GameState> ensureInitialState(int profileId) async => gameState;
  @override
  Future<GameState?> getGameState(int profileId) async => gameState;
  @override
  Future<List<GamePeriod>> getPeriods(int profileId) async => [period];
  @override
  Future<GamePeriod?> getCurrentPeriod(int profileId) async => period;
  @override
  Future<Pet?> getPet(int profileId) async => pet;
  @override
  Future<int> getInventoryQuantity(int profileId, String itemId) async =>
      inventory[itemId] ?? 0;
  @override
  Future<int> getPetDailyUsageCount({
    required int profileId,
    required int periodId,
    required String actionId,
    required PetActionSlot slot,
  }) async => 0;
}

class _SyncPurchases implements PurchaseService {
  _SyncPurchases(this.games);
  final _SyncGames games;

  @override
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required String itemId,
    required String operationId,
  }) async {
    games.inventory[itemId] = (games.inventory[itemId] ?? 0) + 1;
    games.gameState = games.gameState.copyWith(
      walletBalance: games.gameState.walletBalance - 40,
    );
    return games.gameState;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('purchasing item in Shop immediately updates Things inventory', (
    tester,
  ) async {
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
      currentPeriod: 1,
      savedAmount: 0,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    final period = GamePeriod(
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

    final games = _SyncGames(database, pet, gameState, period);
    final content = TestContentRepository(const [], shopItems: [syncApple]);

    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(_SyncProfiles(profile)),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        purchaseServiceProvider.overrideWithValue(_SyncPurchases(games)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const FinnyApp()),
    );
    await tester.pumpAndSettle();

    Finder navItem(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    // 1. Visit Things tab first: empty state
    await tester.tap(navItem('Вещи'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('things-empty')), findsOneWidget);

    // 2. Visit Shop tab
    await tester.tap(navItem('Магазин'));
    await tester.pumpAndSettle();

    // 3. Purchase apple
    final appleCard = find.byKey(const Key('shop-item-food_apple'));
    await tester.tap(appleCard);
    await tester.pumpAndSettle();

    final buyButton = find.byKey(const Key('shop-buy'));
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    // Confirm purchase in bottom sheet
    await tester.tap(buyButton);
    await tester.pumpAndSettle();

    // 4. Switch back to Things tab
    await tester.tap(navItem('Вещи'));
    await tester.pumpAndSettle();

    // Verify Things now shows the purchased apple ×1
    expect(find.byKey(const Key('things-empty')), findsNothing);
    expect(find.text('Яблоко ×1'), findsOneWidget);
  });
}
