import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/pet_state_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

Future<(int, GamePeriod)> createActiveDay(
  AppDatabase database, {
  ProfileType profileType = ProfileType.normal,
  int satiety = 40,
  int care = 40,
  int mood = 40,
}) async {
  final profiles = SqliteProfileRepository(database);
  final games = SqliteGameRepository(database);
  final profile = await profiles.create(
    Profile(
      gameName: profileType == ProfileType.normal ? 'Player' : 'Demo',
      profileType: profileType,
      onboardingCompleted: true,
      createdAt: DateTime.utc(2026, 9, 18),
    ),
  );
  final profileId = profile.id!;
  await games.ensureInitialState(profileId);
  await games.savePet(
    Pet(
      profileId: profileId,
      name: 'Finny',
      colorId: 'blue',
      patternId: 'plain',
      developmentStage: 0,
      growthPoints: 0,
      satiety: satiety,
      care: care,
      mood: mood,
    ),
  );
  final planning = await games.startPeriod(
    profileId: profileId,
    definitionId: 'period_1_needs_vs_wants',
    periodNumber: 1,
    baseIncome: 500,
    requiredCheckpoints: const ['financial_task'],
    createdAt: DateTime.utc(2026, 9, 18),
  );
  final active = await games.confirmBudget(
    profileId: profileId,
    periodId: planning.id!,
  );
  return (profileId, active);
}

void main() {
  test('canonical initial values and next-morning rules are deterministic', () {
    expect(PetStateRules.initialValue, 40);
    expect(PetStateRules.clampStat(-1), 0);
    expect(PetStateRules.clampStat(101), 100);
    for (final entry in <int, int>{
      0: 35,
      69: 35,
      70: 35,
      71: 35,
      72: 36,
      73: 36,
      74: 37,
      75: 37,
      76: 38,
      77: 38,
      78: 39,
      79: 39,
      80: 40,
      100: 40,
    }.entries) {
      expect(
        PetStateRules.nextMorningValue(entry.key),
        entry.value,
        reason: 'evening value ${entry.key}',
      );
    }
    final morning = PetStateService(_UnusedGameRepository())
        .calculateNextMorning(
          const Pet(
            profileId: 1,
            name: 'Finny',
            colorId: 'blue',
            patternId: 'plain',
            developmentStage: 1,
            growthPoints: 20,
            satiety: 71,
            care: 75,
            mood: 82,
          ),
        );
    expect((morning.satiety, morning.care, morning.mood), (35, 37, 40));
    expect(morning.developmentStage, 1);
    expect(morning.growthPoints, 20);
  });

  test(
    'active time applies incremental decay once and caps daily totals',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final games = SqliteGameRepository(database);
      final service = PetStateService(games);
      final (profileId, period) = await createActiveDay(database);

      final halfway = await service.applyActiveElapsedTime(
        profileId: profileId,
        periodId: period.id!,
        elapsed: const Duration(minutes: 3),
      );
      expect((halfway.satiety, halfway.care, halfway.mood), (33, 35, 34));

      final full = await service.applyActiveElapsedTime(
        profileId: profileId,
        periodId: period.id!,
        elapsed: const Duration(minutes: 20),
      );
      expect((full.satiety, full.care, full.mood), (25, 30, 28));
      final persisted = await games.getPeriodById(profileId, period.id!);
      expect(persisted?.activeElapsedMilliseconds, 360000);
      expect(persisted?.satietyDecayApplied, 15);
      expect(persisted?.careDecayApplied, 10);
      expect(persisted?.moodDecayApplied, 12);

      final capped = await service.applyActiveElapsedTime(
        profileId: profileId,
        periodId: period.id!,
        elapsed: const Duration(minutes: 6),
      );
      expect((capped.satiety, capped.care, capped.mood), (25, 30, 28));
    },
  );

  test('decay clamps every state at zero', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final (profileId, period) = await createActiveDay(
      database,
      satiety: 5,
      care: 4,
      mood: 3,
    );
    final pet = await PetStateService(SqliteGameRepository(database))
        .applyActiveElapsedTime(
          profileId: profileId,
          periodId: period.id!,
          elapsed: const Duration(minutes: 6),
        );
    expect((pet.satiety, pet.care, pet.mood), (0, 0, 0));
  });

  test('concurrent elapsed updates do not lose time or double decay', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = SqliteGameRepository(database);
    final service = PetStateService(games);
    final (profileId, period) = await createActiveDay(database);

    await Future.wait([
      service.applyActiveElapsedTime(
        profileId: profileId,
        periodId: period.id!,
        elapsed: const Duration(minutes: 3),
      ),
      service.applyActiveElapsedTime(
        profileId: profileId,
        periodId: period.id!,
        elapsed: const Duration(minutes: 3),
      ),
    ]);

    final pet = await games.getPet(profileId);
    final persisted = await games.getPeriodById(profileId, period.id!);
    expect((pet?.satiety, pet?.care, pet?.mood), (25, 30, 28));
    expect(persisted?.activeElapsedMilliseconds, 360000);
    expect(persisted?.satietyDecayApplied, 15);
    expect(persisted?.careDecayApplied, 10);
    expect(persisted?.moodDecayApplied, 12);
  });

  test(
    'planning and completed periods reject decay without partial state',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final profiles = SqliteProfileRepository(database);
      final games = SqliteGameRepository(database);
      final profile = await profiles.create(
        Profile(
          gameName: 'Player',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 9, 18),
        ),
      );
      final profileId = profile.id!;
      await games.ensureInitialState(profileId);
      await games.savePet(
        const Pet(
          profileId: 1,
          name: 'Finny',
          colorId: 'blue',
          patternId: 'plain',
          developmentStage: 0,
          growthPoints: 0,
          satiety: 40,
          care: 40,
          mood: 40,
        ),
      );
      final planning = await games.startPeriod(
        profileId: profileId,
        definitionId: 'period_1_needs_vs_wants',
        periodNumber: 1,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task'],
        createdAt: DateTime.utc(2026, 9, 18),
      );
      final service = PetStateService(games);

      await expectLater(
        service.applyActiveElapsedTime(
          profileId: profileId,
          periodId: planning.id!,
          elapsed: const Duration(minutes: 1),
        ),
        throwsStateError,
      );
      expect((await games.getPet(profileId))?.satiety, 40);

      final db = await database.database;
      await db.update(
        'game_periods',
        {'status': GamePeriodStatus.completed.name},
        where: 'id = ?',
        whereArgs: [planning.id],
      );
      await expectLater(
        service.applyActiveElapsedTime(
          profileId: profileId,
          periodId: planning.id!,
          elapsed: const Duration(minutes: 1),
        ),
        throwsStateError,
      );
      final unchanged = await games.getPet(profileId);
      expect(
        (unchanged?.satiety, unchanged?.care, unchanged?.mood),
        (40, 40, 40),
      );
    },
  );

  test('ready-to-finish remains part of active game time', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = SqliteGameRepository(database);
    final (profileId, period) = await createActiveDay(database);
    final db = await database.database;
    await db.update(
      'game_periods',
      {'status': GamePeriodStatus.readyToFinish.name},
      where: 'id = ?',
      whereArgs: [period.id],
    );

    final pet = await PetStateService(games).applyActiveElapsedTime(
      profileId: profileId,
      periodId: period.id!,
      elapsed: const Duration(minutes: 6),
    );
    expect((pet.satiety, pet.care, pet.mood), (25, 30, 28));
  });

  test('period ownership and profile state stay isolated', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = SqliteGameRepository(database);
    final normal = await createActiveDay(database);
    final demo = await createActiveDay(
      database,
      profileType: ProfileType.demo,
      satiety: 80,
      care: 80,
      mood: 80,
    );
    final service = PetStateService(games);

    await expectLater(
      service.applyActiveElapsedTime(
        profileId: normal.$1,
        periodId: demo.$2.id!,
        elapsed: const Duration(minutes: 6),
      ),
      throwsStateError,
    );
    expect((await games.getPet(normal.$1))?.satiety, 40);
    expect((await games.getPet(demo.$1))?.satiety, 80);

    await service.applyActiveElapsedTime(
      profileId: demo.$1,
      periodId: demo.$2.id!,
      elapsed: const Duration(minutes: 6),
    );
    expect((await games.getPet(normal.$1))?.satiety, 40);
    expect((await games.getPet(demo.$1))?.satiety, 65);

    await expectLater(
      (await database.database).insert('pet_daily_usage', {
        'profile_id': normal.$1,
        'period_id': demo.$2.id,
        'action_id': 'item:comb',
        'usage_slot': 'default',
        'usage_count': 1,
        'updated_at': DateTime.utc(2026, 9, 18).toIso8601String(),
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'restart and inactive time do not add decay; daily usage persists',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'finny_pet_state_',
      );
      final path = '${directory.path}/finny.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final first = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final (profileId, period) = await createActiveDay(first);
      final service = PetStateService(SqliteGameRepository(first));
      await service.applyActiveElapsedTime(
        profileId: profileId,
        periodId: period.id!,
        elapsed: const Duration(minutes: 2),
      );
      final firstDb = await first.database;
      await firstDb.insert('pet_daily_usage', {
        'profile_id': profileId,
        'period_id': period.id,
        'action_id': 'free:pet',
        'usage_slot': 'default',
        'usage_count': 1,
        'updated_at': DateTime.utc(2026, 9, 18).toIso8601String(),
      });
      await first.close();

      final reopened = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(reopened.close);
      final games = SqliteGameRepository(reopened);
      expect((await games.getPet(profileId))?.satiety, 35);
      expect(
        (await games.getPeriodById(
          profileId,
          period.id!,
        ))?.activeElapsedMilliseconds,
        120000,
      );
      expect(
        await (await reopened.database).query('pet_daily_usage'),
        hasLength(1),
      );

      final unchanged = await games.getPet(profileId);
      expect(
        (unchanged?.satiety, unchanged?.care, unchanged?.mood),
        (35, 37, 36),
      );
    },
  );

  test(
    'pet and period updates roll back together on storage failure',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final games = SqliteGameRepository(database);
      final (profileId, period) = await createActiveDay(database);
      final db = await database.database;
      await db.execute('''
      CREATE TRIGGER reject_pet_decay_period_update
      BEFORE UPDATE OF active_elapsed_milliseconds ON game_periods
      BEGIN
        SELECT RAISE(ABORT, 'forced period failure');
      END
    ''');

      await expectLater(
        PetStateService(games).applyActiveElapsedTime(
          profileId: profileId,
          periodId: period.id!,
          elapsed: const Duration(minutes: 6),
        ),
        throwsA(anything),
      );
      final pet = await games.getPet(profileId);
      final persistedPeriod = await games.getPeriodById(profileId, period.id!);
      expect((pet?.satiety, pet?.care, pet?.mood), (40, 40, 40));
      expect(persistedPeriod?.activeElapsedMilliseconds, 0);
      expect(persistedPeriod?.satietyDecayApplied, 0);
    },
  );
}

class _UnusedGameRepository implements GameRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
