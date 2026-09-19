import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/models/shop_item.dart';
import 'package:finny/models/savings_goal.dart';
import 'package:finny/models/savings_exception.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_content_repository.dart';
import '../helpers/test_database.dart';

const persistentItem = ShopItem(
  id: 'test_ball',
  name: 'Мяч',
  category: ShopItemCategory.want,
  price: 120,
  persistent: true,
  effectType: 'mood',
  effectValue: 8,
  unlockType: 'available',
);

const savingsGoal = SavingsGoal(
  id: 'goal_test',
  name: 'Тестовая цель',
  price: 600,
  description: 'Описание',
  rewardAssetId: 'reward_test',
);

void main() {
  late AppDatabase database;
  late SqliteProfileRepository profiles;
  late SqliteGameRepository games;
  late PeriodService periods;
  late BudgetService budgets;
  late PurchaseService purchases;
  late TaskService tasks;

  setUp(() {
    database = createTestDatabase();
    profiles = SqliteProfileRepository(database);
    games = SqliteGameRepository(database);
    final content = TestContentRepository(
      testPeriodDefinitions(count: 1),
      shopItems: const [persistentItem],
    );
    periods = PeriodService(games, content);
    budgets = BudgetService(games);
    purchases = PurchaseService(SqlitePurchasePort(database), content);
    tasks = TaskService(games, SqliteTaskCompletionPort(database), content);
  });

  tearDown(() => database.close());

  Future<({int profileId, int periodId})> createActivePlayer() async {
    final profile = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await games.ensureInitialState(profile.id!);
    final started = await periods.startNextPeriod(profileId: profile.id!);
    final active = await budgets.confirmPlan(
      profileId: profile.id!,
      periodId: started!.id!,
    );
    return (profileId: profile.id!, periodId: active.id!);
  }

  Future<void> completePlayerPeriod(
    ({int profileId, int periodId}) player,
  ) async {
    await tasks.submitAnswer(
      profileId: player.profileId,
      periodId: player.periodId,
      taskId: 'task_period_1',
      answerId: 'apple',
    );
    for (final checkpointId in const ['savings_decision']) {
      await periods.resolveCheckpoint(
        profileId: player.profileId,
        periodId: player.periodId,
        checkpointId: checkpointId,
      );
    }
    await periods.completePeriod(
      profileId: player.profileId,
      periodId: player.periodId,
    );
  }

  test('purchase replay succeeds after period completion', () async {
    final player = await createActivePlayer();

    final first = await purchases.purchase(
      profileId: player.profileId,
      periodId: player.periodId,
      itemId: persistentItem.id,
      operationId: 'purchase-retry',
    );
    expect(first.walletBalance, 380);

    await completePlayerPeriod(player);

    final replay = await purchases.purchase(
      profileId: player.profileId,
      periodId: player.periodId,
      itemId: persistentItem.id,
      operationId: 'purchase-retry',
    );

    expect(replay.walletBalance, 430);
    expect(
      await games.getInventoryQuantity(player.profileId, persistentItem.id),
      1,
    );
    expect(
      await games.getTransactions(player.profileId, periodId: player.periodId),
      hasLength(3),
    );

    await expectLater(
      purchases.purchase(
        profileId: player.profileId,
        periodId: player.periodId,
        itemId: persistentItem.id,
        operationId: 'purchase-new-after-complete',
      ),
      throwsStateError,
    );
  });

  test('explicit income replay succeeds after period completion', () async {
    final player = await createActivePlayer();

    final first = await periods.addExplicitIncome(
      profileId: player.profileId,
      periodId: player.periodId,
      amount: 50,
      operationId: 'income-retry',
      source: 'task_reward',
      description: 'Награда за задание',
    );
    expect(first.walletBalance, 550);

    await completePlayerPeriod(player);

    final replay = await periods.addExplicitIncome(
      profileId: player.profileId,
      periodId: player.periodId,
      amount: 50,
      operationId: 'income-retry',
      source: 'task_reward',
      description: 'Награда за задание',
    );

    expect(replay.walletBalance, 600);
    expect(
      await games.getTransactions(player.profileId, periodId: player.periodId),
      hasLength(3),
    );

    await expectLater(
      periods.addExplicitIncome(
        profileId: player.profileId,
        periodId: player.periodId,
        amount: 50,
        operationId: 'income-new-after-complete',
        source: 'task_reward',
        description: 'Новая награда',
      ),
      throwsStateError,
    );
  });

  test('savings replay succeeds after period completion', () async {
    final player = await createActivePlayer();
    await games.selectSavingsGoal(
      profileId: player.profileId,
      goal: savingsGoal,
    );

    final first = await games.depositSavings(
      profileId: player.profileId,
      periodId: player.periodId,
      goal: savingsGoal,
      amount: 100,
      operationId: 'savings-retry',
    );
    expect(first.walletBalance, 400);
    expect(first.savedAmount, 100);

    await completePlayerPeriod(player);

    final replay = await games.depositSavings(
      profileId: player.profileId,
      periodId: player.periodId,
      goal: savingsGoal,
      amount: 100,
      operationId: 'savings-retry',
    );

    expect(replay.walletBalance, 450);
    expect(replay.savedAmount, 100);
    expect(
      await games.getTransactions(player.profileId, periodId: player.periodId),
      hasLength(3),
    );

    await expectLater(
      games.depositSavings(
        profileId: player.profileId,
        periodId: player.periodId,
        goal: savingsGoal,
        amount: 100,
        operationId: 'savings-new-after-complete',
      ),
      throwsA(isA<SavingsPeriodNotAvailableException>()),
    );
  });
}
