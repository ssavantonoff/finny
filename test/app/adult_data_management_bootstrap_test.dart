import 'package:finny/app/bootstrap.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_data_management_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late SqliteProfileDataManagement management;
  late ProviderContainer container;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    management = SqliteProfileDataManagement(database);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        profileRepositoryProvider.overrideWithValue(profiles),
        gameRepositoryProvider.overrideWithValue(games),
        profileDataManagementPortProvider.overrideWithValue(management),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<Profile> createNormal() => profiles.create(
    Profile(
      gameName: 'Игрок',
      profileType: ProfileType.normal,
      onboardingCompleted: true,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );

  Future<void> seedNormal(Profile profile) async {
    await games.createInitialState(
      GameState(
        profileId: profile.id!,
        walletBalance: 700,
        currentPeriod: 2,
        activeGoalId: 'goal_bicycle',
        savedAmount: 240,
        goalChangeUsed: true,
        updatedAt: DateTime.utc(2026, 2, 2),
      ),
    );
    await games.savePet(
      Pet(
        profileId: profile.id!,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'dots',
        developmentStage: 3,
        growthPoints: 100,
        satiety: 10,
        care: 20,
        mood: 30,
      ),
    );
  }

  test('reset returns to bootstrap with the same normal Pet profile', () async {
    final profile = await createNormal();
    await seedNormal(profile);
    container
        .read(activeProfileIdProvider.notifier)
        .setActiveProfileId(profile.id!);

    await management.resetNormalProfile(profile.id!);
    container.read(activeProfileIdProvider.notifier).clear();
    await container.read(bootstrapProvider.notifier).initialize();

    expect(
      container.read(bootstrapProvider).phase,
      BootstrapPhase.resolvedWithPet,
    );
    expect(container.read(activeProfileIdProvider), profile.id);
    expect((await profiles.findById(profile.id!))?.gameName, 'Игрок');
    expect((await games.getPet(profile.id!))?.name, 'Финни');
    expect((await games.getPet(profile.id!))?.developmentStage, 1);
    expect((await games.getGameState(profile.id!))?.currentPeriod, 0);
    expect((await games.getGameState(profile.id!))?.walletBalance, 0);
  });

  test(
    'delete returns to normal new-user onboarding through bootstrap',
    () async {
      final profile = await createNormal();
      await seedNormal(profile);
      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(profile.id!);

      await management.deleteNormalProfile(profile.id!);
      container.read(activeProfileIdProvider.notifier).clear();
      await container.read(bootstrapProvider.notifier).initialize();

      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.onboardingNew,
      );
      expect(container.read(activeProfileIdProvider), isNull);
      expect(await profiles.findAll(), isEmpty);
    },
  );
}
