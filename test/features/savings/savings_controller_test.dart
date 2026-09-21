import 'dart:async';

import 'package:finny/app/providers.dart';
import 'package:finny/core/database/app_database.dart';
import 'package:finny/features/savings/savings_controller.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/savings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';
import 'savings_core_test.dart' show goals;

class _AmbiguousSavingsService extends SavingsService {
  _AmbiguousSavingsService(super.games, super.content);

  bool loseNextDepositResult = false;
  bool loseNextClaimResult = false;
  final depositOperationIds = <String>[];
  final claimOperationIds = <String>[];
  int? delayedProfileId;
  Completer<void>? loadGate;

  @override
  Future<SavingsSnapshot> loadSnapshot(int profileId) async {
    if (profileId == delayedProfileId && loadGate != null) {
      await loadGate!.future;
    }
    return super.loadSnapshot(profileId);
  }

  @override
  Future<GameState> deposit({
    required int profileId,
    required int periodId,
    required int amount,
    required String operationId,
  }) async {
    depositOperationIds.add(operationId);
    final result = await super.deposit(
      profileId: profileId,
      periodId: periodId,
      amount: amount,
      operationId: operationId,
    );
    if (loseNextDepositResult) {
      loseNextDepositResult = false;
      throw StateError('deposit result lost');
    }
    return result;
  }

  @override
  Future<GameState> claimGoal({
    required int profileId,
    required String goalId,
    required String operationId,
  }) async {
    claimOperationIds.add(operationId);
    final result = await super.claimGoal(
      profileId: profileId,
      goalId: goalId,
      operationId: operationId,
    );
    if (loseNextClaimResult) {
      loseNextClaimResult = false;
      throw StateError('claim result lost');
    }
    return result;
  }
}

void main() {
  late AppDatabase database;
  late TestContentRepository content;
  late ProviderContainer container;

  setUp(() {
    database = createTestDatabase();
    content = TestContentRepository(
      testPeriodDefinitions(count: 1),
      goals: goals,
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        contentRepositoryProvider.overrideWithValue(content),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<int> createPlayer({
    int saved = 0,
    String? activeGoalId,
    ProfileType profileType = ProfileType.normal,
  }) async {
    final games = container.read(gameRepositoryProvider);
    final profile = await container
        .read(profileRepositoryProvider)
        .create(
          Profile(
            gameName: 'Игрок',
            profileType: profileType,
            onboardingCompleted: true,
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await games.createInitialState(
      GameState(
        profileId: profile.id!,
        walletBalance: 500,
        currentPeriod: 0,
        activeGoalId: activeGoalId,
        savedAmount: saved,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    container
        .read(activeProfileIdProvider.notifier)
        .setActiveProfileId(profile.id!);
    return profile.id!;
  }

  test(
    'no profile is explicit and a valid profile loads canonical goals',
    () async {
      final controller = container.read(savingsControllerProvider.notifier);
      await controller.load();
      expect(
        container.read(savingsControllerProvider),
        isA<SavingsNoProfile>(),
      );

      await createPlayer();
      await controller.load();
      final ready = container.read(savingsControllerProvider) as SavingsReady;
      expect(ready.goals, hasLength(3));
      expect(ready.activeGoal, isNull);
    },
  );

  test(
    'content and missing runtime state have separate failure states',
    () async {
      final profileId = await createPlayer();
      final missingProfile = await container
          .read(profileRepositoryProvider)
          .create(
            Profile(
              gameName: 'Демо',
              profileType: ProfileType.demo,
              onboardingCompleted: true,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          );
      final games = container.read(gameRepositoryProvider);

      container.dispose();
      final emptyContent = TestContentRepository(
        testPeriodDefinitions(count: 1),
      );
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(emptyContent),
        ],
      );
      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(profileId);
      await container.read(savingsControllerProvider.notifier).load();
      expect(
        container.read(savingsControllerProvider),
        isA<SavingsContentFailure>(),
      );

      container.dispose();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
        ],
      );
      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(missingProfile.id!);
      await container.read(savingsControllerProvider.notifier).load();
      expect(
        container.read(savingsControllerProvider),
        isA<SavingsRuntimeFailure>(),
      );
    },
  );

  test('controller selects and blocks duplicate deposit submissions', () async {
    final profileId = await createPlayer();
    final periods = PeriodService(
      container.read(gameRepositoryProvider),
      content,
    );
    final started = await periods.startNextPeriod(profileId: profileId);
    await confirmPlanForTest(
      BudgetService(container.read(gameRepositoryProvider)),
      profileId: profileId,
      periodId: started!.id!,
    );
    final controller = container.read(savingsControllerProvider.notifier);
    await controller.load();
    await controller.selectGoal('goal_scooter');

    final first = controller.deposit(100);
    final duplicate = controller.deposit(100);
    await Future.wait([first, duplicate]);
    final ready = container.read(savingsControllerProvider) as SavingsReady;
    expect(ready.gameState.savedAmount, 100);
    expect(ready.period?.actualSavings, 100);
    expect(
      await container
          .read(gameRepositoryProvider)
          .getTransactions(profileId, periodId: started.id),
      hasLength(2),
    );
  });

  test('typed deposit failure clears pending operation', () async {
    final profileId = await createPlayer(
      activeGoalId: 'goal_scooter',
      saved: 550,
    );
    final period = await PeriodService(
      container.read(gameRepositoryProvider),
      content,
    ).startNextPeriod(profileId: profileId);
    await confirmPlanForTest(
      BudgetService(container.read(gameRepositoryProvider)),
      profileId: profileId,
      periodId: period!.id!,
    );
    final controller = container.read(savingsControllerProvider.notifier);
    await controller.load();
    await controller.deposit(51);
    final ready = container.read(savingsControllerProvider) as SavingsReady;
    expect(ready.pendingOperation, isNull);
    expect(ready.message, isNotNull);
    expect(ready.gameState.savedAmount, 550);
  });

  test('ambiguous deposit and claim retry the same operation IDs', () async {
    container.dispose();
    final games = SqliteGameRepository(database);
    final ambiguous = _AmbiguousSavingsService(games, content);
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        savingsServiceProvider.overrideWithValue(ambiguous),
      ],
    );
    final profileId = await createPlayer(activeGoalId: 'goal_night_light');
    final started = await PeriodService(
      games,
      content,
    ).startNextPeriod(profileId: profileId);
    await confirmPlanForTest(
      BudgetService(games),
      profileId: profileId,
      periodId: started!.id!,
    );
    final controller = container.read(savingsControllerProvider.notifier);
    await controller.load();

    ambiguous.loseNextDepositResult = true;
    await controller.deposit(400);
    var ready = container.read(savingsControllerProvider) as SavingsReady;
    expect(ready.pendingOperation, isA<PendingSavingsDeposit>());
    await controller.retryPendingOperation();
    ready = container.read(savingsControllerProvider) as SavingsReady;
    expect(ready.pendingOperation, isNull);
    expect(ready.gameState.savedAmount, 400);
    expect(ambiguous.depositOperationIds, hasLength(2));
    expect(ambiguous.depositOperationIds.toSet(), hasLength(1));

    ambiguous.loseNextClaimResult = true;
    await controller.claimGoal();
    ready = container.read(savingsControllerProvider) as SavingsReady;
    expect(ready.pendingOperation, isA<PendingSavingsClaim>());
    await controller.retryPendingOperation();
    ready = container.read(savingsControllerProvider) as SavingsReady;
    expect(ready.pendingOperation, isNull);
    expect(ready.gameState.savedAmount, 0);
    expect(ambiguous.claimOperationIds, hasLength(2));
    expect(ambiguous.claimOperationIds.toSet(), hasLength(1));
  });

  test(
    'late load from an old profile cannot replace the new profile',
    () async {
      container.dispose();
      final games = SqliteGameRepository(database);
      final controlled = _AmbiguousSavingsService(games, content);
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          gameRepositoryProvider.overrideWithValue(games),
          contentRepositoryProvider.overrideWithValue(content),
          savingsServiceProvider.overrideWithValue(controlled),
        ],
      );
      final profileA = await createPlayer();
      final profileB = await createPlayer(profileType: ProfileType.demo);
      final controller = container.read(savingsControllerProvider.notifier);
      controlled.delayedProfileId = profileA;
      controlled.loadGate = Completer<void>();
      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(profileA);
      final oldLoad = controller.load();

      container
          .read(activeProfileIdProvider.notifier)
          .setActiveProfileId(profileB);
      await controller.load();
      controlled.loadGate!.complete();
      await oldLoad;

      final ready = container.read(savingsControllerProvider) as SavingsReady;
      expect(ready.profileId, profileB);
    },
  );
}
