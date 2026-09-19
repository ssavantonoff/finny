import 'dart:io';

import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/virtual_day_rules.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../helpers/test_database.dart';

void main() {
  test('Day 1 initial values and next-morning rules are distinct', () {
    expect(
      (
        PetStateRules.dayOneInitialSatiety,
        PetStateRules.dayOneInitialCare,
        PetStateRules.dayOneInitialMood,
      ),
      (55, 80, 80),
    );
    expect(PetStateRules.initialValue, 40);
    expect(PetStateRules.nextMorningValue(100), 40);
    expect(PetStateRules.nextMorningValue(70), 35);
  });

  test('virtual progress has canonical phases and cumulative decay', () {
    const expected = <int, (int, int, int)>{
      0: (0, 0, 0),
      10: (6, 2, 1),
      35: (21, 7, 4),
      70: (42, 14, 8),
      76: (45, 15, 9),
      100: (60, 20, 12),
    };
    for (final entry in expected.entries) {
      expect((
        VirtualDayRules.satietyDecayAt(entry.key),
        VirtualDayRules.careDecayAt(entry.key),
        VirtualDayRules.moodDecayAt(entry.key),
      ), entry.value);
    }
    expect(VirtualDayRules.phaseAt(0), VirtualDayPhase.morning);
    expect(VirtualDayRules.phaseAt(34), VirtualDayPhase.morning);
    expect(VirtualDayRules.phaseAt(35), VirtualDayPhase.daytime);
    expect(VirtualDayRules.phaseAt(69), VirtualDayPhase.daytime);
    expect(VirtualDayRules.phaseAt(70), VirtualDayPhase.evening);
    expect(VirtualDayRules.bedtimeReached(75), isFalse);
    expect(VirtualDayRules.bedtimeReached(76), isTrue);

    final tenThenTwenty =
        VirtualDayRules.decayDelta(
          oldProgress: 0,
          newProgress: 10,
          maximum: VirtualDayRules.maxSatietyDecay,
        ) +
        VirtualDayRules.decayDelta(
          oldProgress: 10,
          newProgress: 20,
          maximum: VirtualDayRules.maxSatietyDecay,
        );
    expect(
      tenThenTwenty,
      VirtualDayRules.decayDelta(
        oldProgress: 0,
        newProgress: 20,
        maximum: VirtualDayRules.maxSatietyDecay,
      ),
    );
  });

  test(
    'natural decay is applied before an action effect and progress caps',
    () {
      const pet = Pet(
        profileId: 1,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'plain',
        developmentStage: 1,
        growthPoints: 0,
        satiety: 50,
        care: 80,
        mood: 80,
      );
      final feeding = VirtualDayRules.applyAction(
        pet: pet,
        oldProgress: 0,
        timeCost: 8,
        satietyEffect: 50,
      );
      expect(feeding.progress, 8);
      expect(feeding.pet.satiety, 96);

      final capped = VirtualDayRules.applyAction(
        pet: pet,
        oldProgress: 96,
        timeCost: 30,
      );
      expect(capped.progress, 100);
      expect(capped.pet.satiety, 47);
    },
  );

  test(
    'persisted progress survives restart without wall-clock decay',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('finny_virtual_');
      final path = '${directory.path}/finny.sqlite';
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });
      final first = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final profiles = SqliteProfileRepository(first);
      final games = SqliteGameRepository(first);
      final profile = await profiles.create(
        Profile(
          gameName: 'Игрок',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await games.ensureInitialState(profile.id!);
      await games.savePet(
        Pet(
          profileId: profile.id!,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'plain',
          developmentStage: 1,
          growthPoints: 0,
          satiety: 55,
          care: 80,
          mood: 80,
        ),
      );
      final planning = await games.startPeriod(
        profileId: profile.id!,
        definitionId: 'period_1',
        periodNumber: 1,
        baseIncome: 500,
        requiredCheckpoints: const ['financial_task'],
        createdAt: DateTime.utc(2026),
      );
      final active = await games.confirmBudget(
        profileId: profile.id!,
        periodId: planning.id!,
      );
      final afterConfirm = await games.getPet(profile.id!);
      expect(active.dayProgress, 10);
      expect(
        (afterConfirm?.satiety, afterConfirm?.care, afterConfirm?.mood),
        (49, 78, 79),
      );
      await first.close();

      final reopened = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      addTearDown(reopened.close);
      final restored = SqliteGameRepository(reopened);
      expect(
        (await restored.getPeriodById(profile.id!, planning.id!))?.dayProgress,
        10,
      );
      final unchanged = await restored.getPet(profile.id!);
      expect(
        (unchanged?.satiety, unchanged?.care, unchanged?.mood),
        (49, 78, 79),
      );
      expect(
        () => (restored as dynamic).applyActiveElapsedTime,
        throwsNoSuchMethodError,
      );
    },
  );

  test('profile and period progress remain isolated', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final profiles = SqliteProfileRepository(database);
    final games = SqliteGameRepository(database);
    Future<(int, GamePeriod)> create(ProfileType type) async {
      final profile = await profiles.create(
        Profile(
          gameName: type.name,
          profileType: type,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await games.ensureInitialState(profile.id!);
      await games.savePet(
        Pet(
          profileId: profile.id!,
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
      final period = await games.startPeriod(
        profileId: profile.id!,
        definitionId: 'period_${profile.id}',
        periodNumber: 1,
        baseIncome: 0,
        requiredCheckpoints: const ['done'],
        createdAt: DateTime.utc(2026),
      );
      return (profile.id!, period);
    }

    final normal = await create(ProfileType.normal);
    final demo = await create(ProfileType.demo);
    await games.confirmBudget(profileId: normal.$1, periodId: normal.$2.id!);
    expect(
      (await games.getPeriodById(normal.$1, normal.$2.id!))?.dayProgress,
      10,
    );
    expect((await games.getPeriodById(demo.$1, demo.$2.id!))?.dayProgress, 0);
    await expectLater(
      games.confirmBudget(profileId: normal.$1, periodId: demo.$2.id!),
      throwsStateError,
    );
  });
}
