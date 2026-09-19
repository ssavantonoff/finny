import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/purchase_exception.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/content_repository.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/item_use_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SqliteGameRepository games;
  late PurchaseService purchases;
  late int profileId;
  late int periodId;

  setUp(() async {
    database = createTestDatabase();
    games = SqliteGameRepository(database);
    purchases = PurchaseService(
      SqlitePurchasePort(database),
      AssetContentRepository(),
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
        developmentStage: 0,
        growthPoints: 0,
        satiety: 40,
        care: 40,
        mood: 40,
      ),
    );
    final period = await games.startPeriod(
      profileId: profileId,
      definitionId: 'period_1',
      periodNumber: 1,
      baseIncome: 1000,
      requiredCheckpoints: const [],
      createdAt: DateTime.utc(2026),
    );
    periodId = period.id!;
    await games.confirmBudget(profileId: profileId, periodId: periodId);
  });
  tearDown(() => database.close());

  test(
    'three canonical apple purchases increase quantity but never use Pet',
    () async {
      for (var index = 1; index <= 3; index++) {
        await purchases.purchase(
          profileId: profileId,
          periodId: periodId,
          itemId: 'food_apple',
          operationId: 'apple-$index',
        );
      }
      expect((await games.getGameState(profileId))!.walletBalance, 880);
      expect(await games.getInventoryQuantity(profileId, 'food_apple'), 3);
      final transactions = await games.getTransactions(profileId);
      expect(
        transactions.where((entry) => entry.source == 'purchase_food_apple'),
        hasLength(3),
      );
      expect(transactions.last.type, GameTransactionType.needExpense);
      final pet = (await games.getPet(profileId))!;
      expect((pet.satiety, pet.care, pet.mood), (34, 38, 39));
      expect(await (await database.database).query('pet_daily_usage'), isEmpty);
      expect(
        await (await database.database).query('pet_action_operations'),
        isEmpty,
      );
    },
  );

  test('persistent accessory stays owned and never changes Pet', () async {
    await purchases.purchase(
      profileId: profileId,
      periodId: periodId,
      itemId: 'accessory_bow',
      operationId: 'bow-one',
    );
    expect(await games.getInventoryQuantity(profileId, 'accessory_bow'), 1);
    expect((await games.getGameState(profileId))!.walletBalance, 920);
    await expectLater(
      purchases.purchase(
        profileId: profileId,
        periodId: periodId,
        itemId: 'accessory_bow',
        operationId: 'bow-two',
      ),
      throwsA(isA<PersistentItemAlreadyOwnedException>()),
    );
    await purchases.purchase(
      profileId: profileId,
      periodId: periodId,
      itemId: 'accessory_bow',
      operationId: 'bow-one',
    );
    expect((await games.getGameState(profileId))!.walletBalance, 920);
    expect(await games.getInventoryQuantity(profileId, 'accessory_bow'), 1);
    expect(
      (await games.getTransactions(profileId))
          .where((entry) => entry.source == 'purchase_accessory_bow'),
      hasLength(1),
    );
    final pet = (await games.getPet(profileId))!;
    expect((pet.satiety, pet.care, pet.mood), (34, 38, 39));
    expect(await (await database.database).query('pet_daily_usage'), isEmpty);
  });

  test(
    'multi-stat treat purchase does not apply effects automatically',
    () async {
      await purchases.purchase(
        profileId: profileId,
        periodId: periodId,
        itemId: 'food_treat',
        operationId: 'treat-one',
      );
      expect((await games.getGameState(profileId))!.walletBalance, 940);
      expect(await games.getInventoryQuantity(profileId, 'food_treat'), 1);
      final pet = (await games.getPet(profileId))!;
      expect((pet.satiety, pet.care, pet.mood), (34, 38, 39));
      final afterUse =
          await ItemUseService(
            SqlitePetActionPort(database),
            AssetContentRepository(),
          ).useItem(
            profileId: profileId,
            periodId: periodId,
            itemId: 'food_treat',
            operationId: 'use-treat',
          );
      expect((afterUse.satiety, afterUse.care, afterUse.mood), (40, 37, 48));
      expect(await games.getInventoryQuantity(profileId, 'food_treat'), 0);
    },
  );
}
