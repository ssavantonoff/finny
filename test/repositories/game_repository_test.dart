import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late AppDatabase database;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
  });

  tearDown(() => database.close());

  Future<Profile> createProfile(String name) => profiles.create(
    Profile(
      gameName: name,
      profileType: ProfileType.normal,
      onboardingCompleted: false,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );

  test('ensureInitialState creates canonical state when missing', () async {
    final profile = await createProfile('Новый игрок');

    final state = await games.ensureInitialState(profile.id!);

    expect(state.profileId, profile.id);
    expect(state.walletBalance, 0);
    expect(state.currentPeriod, 0);
    expect(state.activeGoalId, isNull);
    expect(state.savedAmount, 0);
    expect(state.updatedAt.isUtc, isTrue);
    expect((await games.getGameState(profile.id!))?.toMap(), state.toMap());
  });

  test('ensureInitialState returns existing state unchanged', () async {
    final profile = await createProfile('Текущий игрок');
    final existing = GameState(
      profileId: profile.id!,
      walletBalance: 725,
      currentPeriod: 3,
      activeGoalId: 'goal_bicycle',
      savedAmount: 240,
      updatedAt: DateTime.utc(2026, 2, 3, 4, 5),
    );
    await games.createInitialState(existing);

    final state = await games.ensureInitialState(profile.id!);

    expect(state.toMap(), existing.toMap());
    expect((await games.getGameState(profile.id!))?.toMap(), existing.toMap());
  });

  test('ensureInitialState is idempotent on repeat calls', () async {
    final profile = await createProfile('Повторный вызов');

    final first = await games.ensureInitialState(profile.id!);
    final second = await games.ensureInitialState(profile.id!);
    final db = await database.database;
    final rows = await db.query(
      'game_states',
      columns: ['profile_id'],
      where: 'profile_id = ?',
      whereArgs: [profile.id],
    );

    expect(second.toMap(), first.toMap());
    expect(rows, hasLength(1));
  });

  test('concurrent ensureInitialState calls create one state', () async {
    final profile = await createProfile('Конкурентный вызов');

    final states = await Future.wait([
      for (var call = 0; call < 20; call++)
        games.ensureInitialState(profile.id!),
    ]);
    final db = await database.database;
    final rows = await db.query(
      'game_states',
      columns: ['profile_id'],
      where: 'profile_id = ?',
      whereArgs: [profile.id],
    );

    expect(rows, hasLength(1));
    expect(
      states.map((state) => state.toMap()),
      everyElement(states.first.toMap()),
    );
  });

  test('persists a profile, game state, and pet', () async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final profileId = profile.id!;
    await games.createInitialState(
      GameState(
        profileId: profileId,
        walletBalance: 500,
        currentPeriod: 1,
        activeGoalId: 'goal_scooter',
        savedAmount: 100,
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await games.savePet(
      Pet(
        profileId: profileId,
        name: 'Финни',
        colorId: 'blue',
        patternId: 'dots',
        developmentStage: 0,
        growthPoints: 10,
        satiety: 90,
        mood: 95,
      ),
    );

    final restoredProfile = await profiles.findById(profileId);
    final restoredState = await games.getGameState(profileId);
    final restoredPet = await games.getPet(profileId);

    expect(restoredProfile?.gameName, 'Игрок');
    expect(restoredState?.walletBalance, 500);
    expect(restoredState?.savedAmount, 100);
    expect(restoredPet?.name, 'Финни');
    expect(restoredPet?.growthPoints, 10);
  });

  test('DEMO reset never changes NORMAL runtime state', () async {
    final normal = await profiles.create(
      Profile(
        gameName: 'Обычная игра',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final demo = await profiles.create(
      Profile(
        gameName: 'Демо',
        profileType: ProfileType.demo,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    for (final entry in [(normal.id!, 700), (demo.id!, 300)]) {
      await games.createInitialState(
        GameState(
          profileId: entry.$1,
          walletBalance: entry.$2,
          currentPeriod: 1,
          savedAmount: 0,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
    }

    await games.applyWalletChange(
      GameTransaction(
        profileId: demo.id!,
        type: 'task_reward',
        amount: 50,
        source: 'task_reward_demo',
        description: 'Демо-награда',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await games.clearDemoRuntimeData(demo.id!);

    expect((await games.getGameState(normal.id!))?.walletBalance, 700);
    expect(await games.getGameState(demo.id!), isNull);
    expect(await profiles.findById(normal.id!), isNotNull);
    expect(await profiles.findById(demo.id!), isNotNull);
    await expectLater(games.clearDemoRuntimeData(normal.id!), throwsStateError);
  });

  test('wallet change creates a traceable transaction', () async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await games.createInitialState(
      GameState(
        profileId: profile.id!,
        walletBalance: 500,
        currentPeriod: 1,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await games.applyWalletChange(
      GameTransaction(
        profileId: profile.id!,
        type: 'purchase',
        amount: -150,
        source: 'purchase_food',
        description: 'Покупка еды',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final transactions = await games.getTransactions(profile.id!);
    expect(transactions, hasLength(1));
    expect(transactions.single.amount, -150);
    expect(transactions.single.source, 'purchase_food');
    expect(transactions.single.profileId, profile.id);
    expect((await games.getGameState(profile.id!))?.walletBalance, 350);
  });

  test(
    'wallet cannot be overdrawn and failed change is not recorded',
    () async {
      final profile = await profiles.create(
        Profile(
          gameName: 'Игрок',
          profileType: ProfileType.normal,
          onboardingCompleted: true,
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await games.createInitialState(
        GameState(
          profileId: profile.id!,
          walletBalance: 100,
          currentPeriod: 1,
          savedAmount: 0,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      await expectLater(
        games.applyWalletChange(
          GameTransaction(
            profileId: profile.id!,
            type: 'purchase',
            amount: -150,
            source: 'purchase_too_expensive',
            description: 'Слишком дорогая покупка',
            createdAt: DateTime.utc(2026, 1, 2),
          ),
        ),
        throwsStateError,
      );

      expect((await games.getGameState(profile.id!))?.walletBalance, 100);
      expect(await games.getTransactions(profile.id!), isEmpty);
    },
  );
}
