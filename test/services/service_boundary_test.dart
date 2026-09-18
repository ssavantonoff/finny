import 'package:finny/app/providers.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'UI-facing providers resolve services without exposing SQLite',
    () async {
      final database = createTestDatabase();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final profiles = container.read(profileRepositoryProvider);
      final games = container.read(gameRepositoryProvider);
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
          walletBalance: 200,
          currentPeriod: 1,
          savedAmount: 0,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final period = await container
          .read(periodServiceProvider)
          .startNextPeriod(profileId: profile.id!);
      await container
          .read(budgetServiceProvider)
          .confirmPlan(profileId: profile.id!, periodId: period!.id!);

      final state = await container
          .read(purchaseServiceProvider)
          .purchase(
            profileId: profile.id!,
            periodId: period.id!,
            operationId: 'service-boundary-purchase',
            item:
                (await container
                        .read(contentRepositoryProvider)
                        .loadShopItems())
                    .first,
          );

      expect(state.walletBalance, 660);
      expect(await games.getTransactions(profile.id!), hasLength(2));
    },
  );

  test('task reward can only be granted once per profile', () async {
    final database = createTestDatabase();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final profiles = container.read(profileRepositoryProvider);
    final games = container.read(gameRepositoryProvider);
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
        walletBalance: 0,
        currentPeriod: 1,
        savedAmount: 0,
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final period = await container
        .read(periodServiceProvider)
        .startNextPeriod(profileId: profile.id!);
    await container
        .read(budgetServiceProvider)
        .confirmPlan(profileId: profile.id!, periodId: period!.id!);
    final service = container.read(taskServiceProvider);

    final first = await service.submitAnswer(
      profileId: profile.id!,
      periodId: period.id!,
      taskId: 'task_need_or_want_01',
      answerId: 'need_lunch',
    );
    final replay = await service.submitAnswer(
      profileId: profile.id!,
      periodId: period.id!,
      taskId: 'task_need_or_want_01',
      answerId: 'need_lunch',
    );
    expect((first as TaskAnswerCompleted).rewardAppliedNow, isTrue);
    expect((replay as TaskAnswerCompleted).wasAlreadyCompleted, isTrue);

    expect((await games.getGameState(profile.id!))?.walletBalance, 550);
    expect(await games.getTransactions(profile.id!), hasLength(2));
  });
}
