import '../../helpers/campaign_only_lifecycle_service.dart';

import 'package:finny/app/providers.dart';
import 'package:finny/features/shop/shop_controller.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/profile.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/repositories/profile_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:finny/services/period_service.dart';
import 'package:finny/services/purchase_service.dart';
import 'package:finny/services/task_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_content_repository.dart';
import '../../helpers/test_database.dart';
import 'shop_test_support.dart' show ball;

class LostReplyPurchase extends PurchaseService {
  LostReplyPurchase(super.port, super.content);
  bool loseReply = true;
  final ids = <String>[];
  @override
  Future<GameState> purchase({
    required int profileId,
    required int periodId,
    required String itemId,
    required String operationId,
  }) async {
    ids.add(operationId);
    final result = await super.purchase(
      profileId: profileId,
      periodId: periodId,
      itemId: itemId,
      operationId: operationId,
    );
    if (loseReply) {
      loseReply = false;
      throw StateError('response lost after commit');
    }
    return result;
  }
}

void main() {
  test('feature replays committed purchase after completed period without duplicate or DEMO mutation', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final games = SqliteGameRepository(database);
    final profiles = SqliteProfileRepository(database);
    final content = TestContentRepository(
      testPeriodDefinitions(count: 1),
      shopItems: [ball],
    );
    final normal = await profiles.create(
      Profile(
        gameName: 'Игрок',
        profileType: ProfileType.normal,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    final demo = await profiles.create(
      Profile(
        gameName: 'Демо',
        profileType: ProfileType.demo,
        onboardingCompleted: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    await games.ensureInitialState(normal.id!);
    final demoBefore = await games.ensureInitialState(demo.id!);
    final periods = PeriodService(games, content);
    final started = (await periods.startNextPeriod(profileId: normal.id!))!;
    await confirmPlanForTest(
      BudgetService(games),
      profileId: normal.id!,
      periodId: started.id!,
    );
    final service = LostReplyPurchase(SqlitePurchasePort(database), content);
    final container = ProviderContainer(
      overrides: [
        campaignLifecycleServiceProvider.overrideWithValue(
          CampaignOnlyLifecycleService(),
        ),
        appDatabaseProvider.overrideWithValue(database),
        gameRepositoryProvider.overrideWithValue(games),
        contentRepositoryProvider.overrideWithValue(content),
        purchaseServiceProvider.overrideWithValue(service),
        shopControllerProvider.overrideWith(
          () => ShopController(operationIdFactory: (_, _) => 'stable-replay'),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(activeProfileIdProvider.notifier)
        .setActiveProfileId(normal.id!);
    final controller = container.read(shopControllerProvider.notifier);
    await controller.load();
    await controller.buy(ball.id, profileId: normal.id!, periodId: started.id!);
    expect(container.read(shopControllerProvider).pending, isNotNull);
    for (final checkpoint in started.requiredCheckpoints) {
      if (checkpoint == 'financial_task') {
        await TaskService(
          games,
          SqliteTaskCompletionPort(database),
          content,
        ).submitAnswer(
          profileId: normal.id!,
          periodId: started.id!,
          taskId: 'task_period_1',
          answerId: 'apple',
        );
      } else {
        await resolveCheckpointForTest(
          database,
          profileId: normal.id!,
          periodId: started.id!,
          checkpointId: checkpoint,
        );
      }
    }
    await completePeriodForTest(
      database,
      profileId: normal.id!,
      periodId: started.id!,
    );
    await controller.load();
    expect(container.read(shopControllerProvider).period, isNull);
    await controller.retry();
    expect(service.ids, ['stable-replay', 'stable-replay']);
    final result = container.read(shopControllerProvider);
    expect(result.result?.kind, ShopResultKind.success);
    expect(result.pending, isNull);
    expect(result.gameState?.walletBalance, 430);
    expect(await games.getInventoryQuantity(normal.id!, ball.id), 1);
    expect(await games.getTransactions(normal.id!), hasLength(3));
    expect((await games.getGameState(demo.id!))!.toMap(), demoBefore.toMap());
    expect(await games.getInventoryQuantity(demo.id!, ball.id), 0);
    expect(await games.getTransactions(demo.id!), isEmpty);
  });
}
