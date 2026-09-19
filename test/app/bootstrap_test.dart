import 'package:finny/app/bootstrap.dart';
import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/onboarding/profile_name.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

Profile profile({
  ProfileType type = ProfileType.normal,
  bool complete = true,
  String name = 'Игрок',
}) => Profile(
  gameName: name,
  profileType: type,
  onboardingCompleted: complete,
  createdAt: DateTime.utc(2026, 1, 1),
);

class FailingProfiles extends SqliteProfileRepository {
  FailingProfiles(super.database);

  bool failRead = false;
  bool failCreate = false;
  bool failCreateAfterPersist = false;
  bool failUpdate = false;
  bool failUpdateAfterPersist = false;
  int creates = 0;

  @override
  Future<List<Profile>> findAll() {
    if (failRead) throw StateError('read failed');
    return super.findAll();
  }

  @override
  Future<Profile> create(Profile profile) async {
    creates++;
    if (failCreate) throw StateError('create failed');
    final created = await super.create(profile);
    if (failCreateAfterPersist) throw StateError('response failed');
    return created;
  }

  @override
  Future<void> update(Profile profile) async {
    if (failUpdate) throw StateError('update failed');
    await super.update(profile);
    if (failUpdateAfterPersist) throw StateError('response failed');
  }
}

class FailingGames extends SqliteGameRepository {
  FailingGames(super.database);

  bool failEnsure = false;
  bool failPetRead = false;
  int ensures = 0;
  int petReads = 0;

  @override
  Future<GameState> ensureInitialState(int profileId) async {
    ensures++;
    if (failEnsure) throw StateError('ensure failed');
    return super.ensureInitialState(profileId);
  }

  @override
  Future<Pet?> getPet(int profileId) {
    petReads++;
    if (failPetRead) throw StateError('pet read failed');
    return super.getPet(profileId);
  }
}

ProviderContainer createContainer(
  AppDatabase database,
  FailingProfiles profiles,
  FailingGames games,
) => ProviderContainer(
  overrides: [
    appDatabaseProvider.overrideWithValue(database),
    profileRepositoryProvider.overrideWithValue(profiles),
    gameRepositoryProvider.overrideWithValue(games),
  ],
);

void main() {
  late AppDatabase database;
  late FailingProfiles profiles;
  late FailingGames games;
  late ProviderContainer container;

  setUp(() {
    database = createTestDatabase();
    profiles = FailingProfiles(database);
    games = FailingGames(database);
    container = createContainer(database, profiles, games);
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('NORMAL create rejects sequential duplicate', () async {
    final first = await profiles.create(profile());
    await expectLater(
      profiles.create(profile()),
      throwsA(isA<NormalProfileAlreadyExists>()),
    );
    expect(first.id, greaterThan(0));
    expect(await profiles.findAll(), hasLength(1));
  });

  test('concurrent NORMAL create inserts exactly one', () async {
    Future<(bool, Object?)> attempt() async {
      try {
        await profiles.create(profile());
        return (true, null);
      } catch (error) {
        return (false, error);
      }
    }

    final results = await Future.wait([attempt(), attempt()]);
    expect(
      results.where((result) => result.$1),
      hasLength(1),
      reason: '$results',
    );
    expect(await profiles.findAll(), hasLength(1));
  });

  test('DEMO does not block NORMAL and remains separate', () async {
    await profiles.create(profile(type: ProfileType.demo));
    await profiles.create(profile(type: ProfileType.demo));
    final controller = container.read(bootstrapProvider.notifier);
    await controller.initialize();
    expect(
      container.read(bootstrapProvider).phase,
      BootstrapPhase.onboardingNew,
    );
    await controller.submitName('  Игра  ');
    final all = await profiles.findAll();
    expect(all.where((p) => p.profileType == ProfileType.normal), hasLength(1));
    expect(all.where((p) => p.profileType == ProfileType.demo), hasLength(2));
    expect(container.read(activeProfileIdProvider), all.last.id);
  });

  test(
    'legacy multiple NORMAL is conflict without selecting or modifying',
    () async {
      final db = await database.database;
      await db.insert('profiles', profile(name: 'А').toMap());
      await db.insert('profiles', profile(name: 'Б').toMap());
      await container.read(bootstrapProvider.notifier).initialize();
      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.profileConflict,
      );
      expect(container.read(activeProfileIdProvider), isNull);
      expect((await profiles.findAll()).map((p) => p.gameName), ['А', 'Б']);
    },
  );

  test('name validation uses trimmed runes and existing semantics', () {
    expect(const ProfileName('').isValid, isFalse);
    expect(const ProfileName('   ').error, 'Напиши игровое имя');
    expect(const ProfileName('  Да  ').trimmed, 'Да');
    expect(ProfileName('А' * 20).isValid, isTrue);
    expect(ProfileName('А' * 21).isValid, isFalse);
  });

  test(
    'new profile is created only on submit and restart reuses state',
    () async {
      final controller = container.read(bootstrapProvider.notifier);
      await controller.initialize();
      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.onboardingNew,
      );
      expect(await profiles.findAll(), isEmpty);

      await controller.submitName('  Игрок  ');
      final created = (await profiles.findAll()).single;
      expect(created.gameName, 'Игрок');
      expect(created.onboardingCompleted, isTrue);
      expect(container.read(activeProfileIdProvider), created.id);
      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.resolvedWithoutPet,
      );
      expect(await games.getGameState(created.id!), isNotNull);
      expect(
        await games.getInventoryQuantity(created.id!, 'care_toothbrush'),
        1,
      );
      await games.ensureInitialState(created.id!);
      expect(
        await games.getInventoryQuantity(created.id!, 'care_toothbrush'),
        1,
      );
      final oldState = (await games.getGameState(created.id!))!.toMap();
      await games.savePet(
        Pet(
          profileId: created.id!,
          name: 'Финни',
          colorId: 'blue',
          patternId: 'plain',
          developmentStage: 0,
          growthPoints: 0,
          satiety: 100,
          care: 100,
          mood: 100,
        ),
      );

      container.dispose();
      container = createContainer(database, profiles, games);
      await container.read(bootstrapProvider.notifier).initialize();
      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.resolvedWithPet,
      );
      expect(container.read(activeProfileIdProvider), created.id);
      expect((await profiles.findAll()).single.id, created.id);
      expect((await games.getGameState(created.id!))!.toMap(), oldState);
      expect((await games.getPet(created.id!))?.name, 'Финни');
      expect(
        await games.getInventoryQuantity(created.id!, 'care_toothbrush'),
        1,
      );
    },
  );

  test('existing incomplete profile is updated in place', () async {
    final original = await profiles.create(profile(complete: false));
    final controller = container.read(bootstrapProvider.notifier);
    await controller.initialize();
    expect(
      container.read(bootstrapProvider).phase,
      BootstrapPhase.onboardingExisting,
    );
    expect(container.read(bootstrapProvider).profile?.gameName, 'Игрок');
    expect(container.read(activeProfileIdProvider), isNull);
    await controller.submitName('  Новое имя  ');
    final updated = (await profiles.findAll()).single;
    expect(updated.id, original.id);
    expect(updated.gameName, 'Новое имя');
    expect(updated.profileType, original.profileType);
    expect(updated.createdAt, original.createdAt);
    expect(updated.onboardingCompleted, isTrue);
    expect(
      container.read(bootstrapProvider).phase,
      BootstrapPhase.resolvedWithoutPet,
    );
  });

  test(
    'read error and create/update errors do not navigate or assign ID',
    () async {
      final controller = container.read(bootstrapProvider.notifier);
      profiles.failRead = true;
      await controller.initialize();
      expect(container.read(bootstrapProvider).phase, BootstrapPhase.error);
      expect(profiles.creates, 0);
      profiles.failRead = false;
      await controller.initialize();
      profiles.failCreate = true;
      await controller.submitName('Игрок');
      expect(container.read(bootstrapProvider).saveFailed, isTrue);
      expect(container.read(activeProfileIdProvider), isNull);
      expect(await profiles.findAll(), isEmpty);

      profiles.failCreate = false;
      await profiles.create(profile(complete: false));
      await controller.initialize();
      profiles.failUpdate = true;
      await controller.submitName('Новое имя');
      expect(container.read(bootstrapProvider).saveFailed, isTrue);
      expect(container.read(activeProfileIdProvider), isNull);
      expect((await profiles.findAll()).single.onboardingCompleted, isFalse);
    },
  );

  test('ensure failure after create retries without second NORMAL', () async {
    await container.read(bootstrapProvider.notifier).initialize();
    games.failEnsure = true;
    await container.read(bootstrapProvider.notifier).submitName('Игрок');
    expect(container.read(bootstrapProvider).phase, BootstrapPhase.error);
    expect(container.read(activeProfileIdProvider), isNull);
    expect((await profiles.findAll()).single.onboardingCompleted, isTrue);
    games.failEnsure = false;
    await container.read(bootstrapProvider.notifier).initialize();
    expect((await profiles.findAll()), hasLength(1));
    expect(profiles.creates, 1);
    expect(
      container.read(bootstrapProvider).phase,
      BootstrapPhase.resolvedWithoutPet,
    );
  });

  test(
    'retry after ambiguous create failure rereads persisted NORMAL',
    () async {
      final controller = container.read(bootstrapProvider.notifier);
      await controller.initialize();
      profiles.failCreateAfterPersist = true;
      await controller.submitName('Игрок');
      expect(container.read(bootstrapProvider).saveFailed, isTrue);
      expect(container.read(activeProfileIdProvider), isNull);
      final persisted = (await profiles.findAll()).single;
      profiles.failCreateAfterPersist = false;

      await controller.retryName('Игрок');
      expect(profiles.creates, 1);
      expect((await profiles.findAll()).single.id, persisted.id);
      expect(container.read(activeProfileIdProvider), persisted.id);
      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.resolvedWithoutPet,
      );
    },
  );

  test('retry after ambiguous update failure keeps existing ID', () async {
    final original = await profiles.create(profile(complete: false));
    final controller = container.read(bootstrapProvider.notifier);
    await controller.initialize();
    profiles.failUpdateAfterPersist = true;
    await controller.submitName('Новое имя');
    expect(container.read(bootstrapProvider).saveFailed, isTrue);
    expect(container.read(activeProfileIdProvider), isNull);
    profiles.failUpdateAfterPersist = false;

    await controller.retryName('Новое имя');
    expect((await profiles.findAll()).single.id, original.id);
    expect((await profiles.findAll()).single.gameName, 'Новое имя');
    expect(container.read(activeProfileIdProvider), original.id);
  });

  test(
    'ensure failure after incomplete update reuses the same profile',
    () async {
      final original = await profiles.create(profile(complete: false));
      final controller = container.read(bootstrapProvider.notifier);
      await controller.initialize();
      games.failEnsure = true;
      await controller.submitName('Другое имя');
      expect(container.read(bootstrapProvider).phase, BootstrapPhase.error);
      expect(container.read(activeProfileIdProvider), isNull);
      expect((await profiles.findAll()).single.onboardingCompleted, isTrue);
      games.failEnsure = false;
      await controller.initialize();
      final restored = (await profiles.findAll()).single;
      expect(restored.id, original.id);
      expect(restored.gameName, 'Другое имя');
      expect(container.read(activeProfileIdProvider), original.id);
    },
  );

  test(
    'existing state survives ensure, Pet error retains active profile',
    () async {
      final existing = await profiles.create(profile());
      await games.ensureInitialState(existing.id!);
      final db = await database.database;
      await db.update(
        'game_states',
        {
          'wallet_balance': 37,
          'current_period': 2,
          'saved_amount': 5,
          'updated_at': DateTime.utc(2026, 2, 1).toIso8601String(),
        },
        where: 'profile_id = ?',
        whereArgs: [existing.id],
      );
      final before = (await games.getGameState(existing.id!))!;
      games.failPetRead = true;
      await container.read(bootstrapProvider.notifier).initialize();
      expect(container.read(bootstrapProvider).phase, BootstrapPhase.error);
      expect(container.read(activeProfileIdProvider), existing.id);
      expect((await games.getGameState(existing.id!))!.toMap(), before.toMap());
      expect(before.walletBalance, 37);
      expect(before.savedAmount, 5);
      games.failPetRead = false;
      await container.read(bootstrapProvider.notifier).initialize();
      expect(
        container.read(bootstrapProvider).phase,
        BootstrapPhase.resolvedWithoutPet,
      );
      expect((await games.getGameState(existing.id!))!.toMap(), before.toMap());
    },
  );
}
