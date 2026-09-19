import 'package:finny/app/providers.dart';
import 'package:finny/models/task_submission_result.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet_action.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/transaction.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/day_lifecycle_service.dart';
import 'package:finny/services/item_use_service.dart';
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
      expect(games, isNot(isA<PurchasePort>()));
      expect(games, isNot(isA<SpecialPurchasePort>()));
      expect(() => (games as dynamic).purchase, throwsNoSuchMethodError);
      expect(() => (games as dynamic).purchaseStory, throwsNoSuchMethodError);
      expect(() => (games as dynamic).decidePromotion, throwsNoSuchMethodError);
      expect(games, isNot(isA<PetActionPort>()));
      expect(games, isNot(isA<DayLifecyclePort>()));
      expect(() => (games as dynamic).evaluateBedtime, throwsNoSuchMethodError);
      expect(() => (games as dynamic).sleep, throwsNoSuchMethodError);
      expect(() => (games as dynamic).completePeriod, throwsNoSuchMethodError);
      expect(
        container.read(dayLifecycleServiceProvider),
        isA<DayLifecycleService>(),
      );
      const forgedItem = ShopItem(
        id: 'forged',
        name: 'Forged item',
        category: ShopItemCategory.need,
        price: 0,
        persistent: false,
        effectType: 'mood',
        effectValue: 100,
        unlockType: 'available',
        usagePolicy: ItemUsagePolicy.unlimited,
      );
      expect(
        () => (games as dynamic).useItem(
          profileId: 1,
          periodId: 1,
          item: forgedItem,
          operationId: 'forged-item-use',
          slot: PetActionSlot.defaultSlot,
        ),
        throwsNoSuchMethodError,
      );
      expect(
        () => (games as dynamic).performFreePetInteraction(
          profileId: 1,
          periodId: 1,
          interaction: FreePetInteraction.pet,
          operationId: 'forged-free-interaction',
        ),
        throwsNoSuchMethodError,
      );
      expect(
        () => (games as dynamic).applyActiveElapsedTime,
        throwsNoSuchMethodError,
      );
      expect(
        () => (games as dynamic).advanceDayProgress(
          profileId: 1,
          periodId: 1,
          amount: 100,
        ),
        throwsNoSuchMethodError,
      );
      expect(
        () => (games as dynamic).applyPetEffects(
          profileId: 1,
          effects: const PetStatEffects(mood: 100),
        ),
        throwsNoSuchMethodError,
      );
      expect(container.read(itemUseServiceProvider), isA<ItemUseService>());
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
            itemId: 'food_apple',
          );

      expect(state.walletBalance, 660);
      expect(await games.getTransactions(profile.id!), hasLength(2));
    },
  );

  test('task completion is only exposed through TaskService', () async {
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
    expect(games, isNot(isA<TaskCompletionPort>()));
    expect(
      () => (games as dynamic).submitFinancialTaskAnswer,
      throwsNoSuchMethodError,
    );
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
    final period = await container
        .read(periodServiceProvider)
        .startNextPeriod(profileId: profile.id!);
    await container
        .read(budgetServiceProvider)
        .confirmPlan(profileId: profile.id!, periodId: period!.id!);
    final forbiddenReward = GameTransaction(
      profileId: profile.id!,
      periodId: period.id!,
      type: GameTransactionType.taskReward,
      amount: 50,
      source: 'task_reward_task_need_or_want_01',
      description: 'Forbidden direct reward',
      createdAt: DateTime.utc(2026, 1, 1),
      deduplicationKey: 'forbidden-direct-task-reward',
    );
    await expectLater(
      games.applyWalletChange(forbiddenReward),
      throwsStateError,
    );
    await expectLater(
      games.applyIdempotentWalletChange(forbiddenReward),
      throwsStateError,
    );
    final service = container.read(taskServiceProvider);

    final first = await service.submitAnswer(
      profileId: profile.id!,
      periodId: period.id!,
      taskId: 'task_need_or_want_01',
      answerId: 'apple',
    );
    final replay = await service.submitAnswer(
      profileId: profile.id!,
      periodId: period.id!,
      taskId: 'task_need_or_want_01',
      answerId: 'apple',
    );
    expect((first as TaskAnswerCompleted).rewardAppliedNow, isTrue);
    expect((replay as TaskAnswerCompleted).wasAlreadyCompleted, isTrue);

    expect((await games.getGameState(profile.id!))?.walletBalance, 550);
    expect(await games.getTransactions(profile.id!), hasLength(2));
  });
}
