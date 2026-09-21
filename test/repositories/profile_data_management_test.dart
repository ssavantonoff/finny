import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/completed_goal.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_data_management_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

const _runtimeTables = [
  'pet_action_operations',
  'pet_daily_usage',
  'period_special_actions',
  'task_progress',
  'transactions',
  'inventory',
  'game_periods',
  'completed_goals',
];

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late SqliteProfileDataManagement management;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    management = SqliteProfileDataManagement(database);
  });

  tearDown(() => database.close());

  Future<Profile> createProfile({
    required String name,
    required ProfileType type,
  }) => profiles.create(
    Profile(
      gameName: name,
      profileType: type,
      onboardingCompleted: true,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );

  Future<int> seedRuntime(
    int profileId, {
    required bool withPet,
    int wallet = 700,
  }) async {
    await games.createInitialState(
      GameState(
        profileId: profileId,
        walletBalance: wallet,
        currentPeriod: 2,
        activeGoalId: 'goal_bicycle',
        savedAmount: 240,
        goalChangeUsed: true,
        updatedAt: DateTime.utc(2026, 2, 2),
      ),
    );
    if (withPet) {
      await games.savePet(
        Pet(
          profileId: profileId,
          name: 'Искра',
          colorId: 'violet',
          patternId: 'stripes',
          developmentStage: 3,
          growthPoints: 99,
          satiety: 12,
          care: 23,
          mood: 34,
        ),
      );
    }

    final db = await database.database;
    final periodId = await db.insert(
      'game_periods',
      GamePeriod(
        profileId: profileId,
        definitionId: 'period_2_saving',
        periodNumber: 2,
        startWalletBalance: wallet,
        baseIncome: 500,
        extraIncome: 20,
        plannedNeed: 100,
        plannedWant: 80,
        plannedSavings: 50,
        plannedFree: 290,
        actualNeed: 40,
        actualWant: 30,
        actualSavings: 20,
        requiredCheckpoints: const ['financial_task'],
        resolvedCheckpoints: const ['financial_task'],
        growthPointsEarned: 10,
        dayProgress: 80,
        status: GamePeriodStatus.readyToFinish,
        createdAt: DateTime.utc(2026, 2, 2),
      ).toMap(),
    );
    await db.insert(
      'transactions',
      GameTransaction(
        profileId: profileId,
        periodId: periodId,
        type: GameTransactionType.wantExpense,
        amount: -30,
        source: 'seed_purchase',
        description: 'Тестовая покупка',
        createdAt: DateTime.utc(2026, 2, 3),
        deduplicationKey: 'seed-$profileId',
      ).toMap(),
    );
    await db.insert('inventory', {
      'profile_id': profileId,
      'item_id': 'want_ball',
      'quantity': 2,
      'acquired_at': DateTime.utc(2026, 2, 3).toIso8601String(),
    });
    await db.insert(
      'task_progress',
      TaskProgress(
        profileId: profileId,
        taskId: 'task_period_2',
        status: TaskProgressStatus.completed,
        rewardClaimed: true,
        scenarioState: const {'done': true},
        updatedAt: DateTime.utc(2026, 2, 3),
      ).toMap(),
    );
    await db.insert(
      'completed_goals',
      CompletedGoal(
        profileId: profileId,
        goalId: 'goal_old',
        rewardAssetId: 'reward_old',
        pricePaid: 100,
        completedAt: DateTime.utc(2026, 2, 3),
        claimOperationId: 'claim-$profileId',
      ).toMap(),
    );
    await db.insert('pet_daily_usage', {
      'profile_id': profileId,
      'period_id': periodId,
      'action_id': 'time:care',
      'usage_slot': 'default',
      'usage_count': 1,
      'updated_at': DateTime.utc(2026, 2, 3).toIso8601String(),
    });
    await db.insert('pet_action_operations', {
      'profile_id': profileId,
      'operation_id': 'pet-operation-$profileId',
      'period_id': periodId,
      'action_id': 'free:pet',
      'usage_slot': 'default',
      'created_at': DateTime.utc(2026, 2, 3).toIso8601String(),
    });
    await db.insert('period_special_actions', {
      'profile_id': profileId,
      'period_id': periodId,
      'action_id': 'discount_day_2',
      'outcome': 'skipped',
      'operation_id': 'special-$profileId',
      'created_at': DateTime.utc(2026, 2, 3).toIso8601String(),
    });
    return periodId;
  }

  Future<List<Map<String, Object?>>> rowsFor(
    String table,
    int profileId,
  ) async {
    final db = await database.database;
    return db.query(
      table,
      where: 'profile_id = ?',
      whereArgs: [profileId],
      orderBy: 'rowid ASC',
    );
  }

  test(
    'reset NORMAL preserves identity and restores canonical runtime',
    () async {
      final normal = await createProfile(
        name: 'Обычный игрок',
        type: ProfileType.normal,
      );
      final demo = await createProfile(name: 'Демо', type: ProfileType.demo);
      await seedRuntime(normal.id!, withPet: true);
      await seedRuntime(demo.id!, withPet: true, wallet: 300);
      final demoBefore = {
        for (final table in _runtimeTables)
          table: await rowsFor(table, demo.id!),
      };

      await management.resetNormalProfile(normal.id!);

      final restoredProfile = await profiles.findById(normal.id!);
      expect(restoredProfile?.toMap(), normal.toMap());
      expect(restoredProfile?.profileType, ProfileType.normal);
      expect(restoredProfile?.onboardingCompleted, isTrue);
      expect(restoredProfile?.createdAt, normal.createdAt);

      final pet = await games.getPet(normal.id!);
      expect(pet?.name, 'Искра');
      expect(pet?.colorId, 'violet');
      expect(pet?.patternId, 'stripes');
      expect(pet?.developmentStage, 1);
      expect(pet?.growthPoints, 0);
      expect(pet?.satiety, PetStateRules.dayOneInitialSatiety);
      expect(pet?.care, PetStateRules.dayOneInitialCare);
      expect(pet?.mood, PetStateRules.dayOneInitialMood);

      final state = await games.getGameState(normal.id!);
      expect(state?.walletBalance, 0);
      expect(state?.currentPeriod, 0);
      expect(state?.savedAmount, 0);
      expect(state?.activeGoalId, isNull);
      expect(state?.goalChangeUsed, isFalse);
      expect(state?.updatedAt.isUtc, isTrue);

      final db = await database.database;
      for (final table in [
        'pet_action_operations',
        'pet_daily_usage',
        'period_special_actions',
        'task_progress',
        'transactions',
        'game_periods',
        'completed_goals',
      ]) {
        expect(await rowsFor(table, normal.id!), isEmpty, reason: table);
      }
      final inventory = await rowsFor('inventory', normal.id!);
      expect(inventory, hasLength(1));
      expect(inventory.single['item_id'], 'care_toothbrush');
      expect(inventory.single['quantity'], 1);
      expect(
        await db.query(
          'game_states',
          where: 'profile_id = ?',
          whereArgs: [normal.id],
        ),
        hasLength(1),
      );

      for (final table in _runtimeTables) {
        expect(
          await rowsFor(table, demo.id!),
          demoBefore[table],
          reason: table,
        );
      }
    },
  );

  test(
    'reset NORMAL is idempotent and does not duplicate initial rows',
    () async {
      final normal = await createProfile(
        name: 'Повторный игрок',
        type: ProfileType.normal,
      );
      await seedRuntime(normal.id!, withPet: true);

      await management.resetNormalProfile(normal.id!);
      await management.resetNormalProfile(normal.id!);

      final db = await database.database;
      expect(
        await db.query(
          'game_states',
          where: 'profile_id = ?',
          whereArgs: [normal.id],
        ),
        hasLength(1),
      );
      final inventory = await rowsFor('inventory', normal.id!);
      expect(inventory, hasLength(1));
      expect(inventory.single['item_id'], 'care_toothbrush');
      expect(inventory.single['quantity'], 1);
      expect((await games.getPet(normal.id!))?.name, 'Искра');
    },
  );

  test('reset NORMAL without Pet does not fabricate one', () async {
    final normal = await createProfile(
      name: 'Без питомца',
      type: ProfileType.normal,
    );
    await seedRuntime(normal.id!, withPet: false);

    await management.resetNormalProfile(normal.id!);

    expect(await games.getPet(normal.id!), isNull);
    expect((await games.getGameState(normal.id!))?.currentPeriod, 0);
    expect(await games.getInventoryQuantity(normal.id!, 'care_toothbrush'), 1);
  });

  test('reset rejects DEMO without mutation', () async {
    final demo = await createProfile(name: 'Демо', type: ProfileType.demo);
    await seedRuntime(demo.id!, withPet: true, wallet: 300);
    final before = {
      for (final table in _runtimeTables) table: await rowsFor(table, demo.id!),
    };

    await expectLater(
      management.resetNormalProfile(demo.id!),
      throwsStateError,
    );

    for (final table in _runtimeTables) {
      expect(await rowsFor(table, demo.id!), before[table], reason: table);
    }
    expect(await profiles.findById(demo.id!), isNotNull);
  });

  test('delete NORMAL removes only its profile and cascaded runtime', () async {
    final normal = await createProfile(
      name: 'Удаляемый игрок',
      type: ProfileType.normal,
    );
    final demo = await createProfile(name: 'Демо', type: ProfileType.demo);
    await seedRuntime(normal.id!, withPet: true);
    await seedRuntime(demo.id!, withPet: true, wallet: 300);

    await management.deleteNormalProfile(normal.id!);

    expect(await profiles.findById(normal.id!), isNull);
    for (final table in [..._runtimeTables, 'pets', 'game_states']) {
      expect(await rowsFor(table, normal.id!), isEmpty, reason: table);
    }
    expect(await profiles.findById(demo.id!), isNotNull);
    expect((await games.getGameState(demo.id!))?.walletBalance, 300);
    expect(await games.getPet(demo.id!), isNotNull);
    expect(await rowsFor('game_periods', demo.id!), isNotEmpty);
  });

  test('delete DEMO is rejected without mutation', () async {
    final demo = await createProfile(name: 'Демо', type: ProfileType.demo);
    await seedRuntime(demo.id!, withPet: true, wallet: 300);
    final before = {
      for (final table in _runtimeTables) table: await rowsFor(table, demo.id!),
    };

    await expectLater(
      management.deleteNormalProfile(demo.id!),
      throwsStateError,
    );

    expect(await profiles.findById(demo.id!), isNotNull);
    for (final table in _runtimeTables) {
      expect(await rowsFor(table, demo.id!), before[table], reason: table);
    }
  });
}
