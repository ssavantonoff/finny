import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:finny/services/budget_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppDatabase createTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
}

Future<GamePeriod> confirmBudgetForTest(
  GameRepository games, {
  required int profileId,
  required int periodId,
}) async {
  final period = await games.getPeriodById(profileId, periodId);
  if (period == null) {
    throw StateError('Test fixture period $periodId does not exist.');
  }
  if (period.status == GamePeriodStatus.planning) {
    await games.saveBudget(
      profileId: profileId,
      periodId: periodId,
      plannedNeed: GamePeriod.minimumBudgetCategoryAllocation,
      plannedWant: GamePeriod.minimumBudgetCategoryAllocation,
      plannedSavings: GamePeriod.minimumBudgetCategoryAllocation,
    );
  }
  return games.confirmBudget(profileId: profileId, periodId: periodId);
}

Future<GamePeriod> confirmPlanForTest(
  BudgetService budgets, {
  required int profileId,
  required int periodId,
}) async {
  await budgets.saveDraft(
    profileId: profileId,
    periodId: periodId,
    allocation: const BudgetAllocation(
      need: GamePeriod.minimumBudgetCategoryAllocation,
      want: GamePeriod.minimumBudgetCategoryAllocation,
      savings: GamePeriod.minimumBudgetCategoryAllocation,
    ),
  );
  return budgets.confirmPlan(profileId: profileId, periodId: periodId);
}

Future<GamePeriod> completePeriodForTest(
  AppDatabase database, {
  required int profileId,
  required int periodId,
}) async {
  final db = await database.database;
  return db.transaction((transaction) async {
    final periodRows = await transaction.query(
      'game_periods',
      where: 'id = ? AND profile_id = ?',
      whereArgs: [periodId, profileId],
      limit: 1,
    );
    if (periodRows.isEmpty) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    final period = GamePeriod.fromMap(periodRows.single);
    if (period.status != GamePeriodStatus.readyToFinish) {
      throw StateError('Test fixture requires a ready-to-finish period.');
    }

    final stateRows = await transaction.query(
      'game_states',
      columns: ['wallet_balance'],
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (stateRows.isEmpty) {
      throw StateError('Game state for profile $profileId is missing.');
    }
    final completed = period.copyWith(
      endWalletBalance: stateRows.single['wallet_balance']! as int,
      status: GamePeriodStatus.completed,
      completedAt: DateTime.utc(2026, 1, 1),
    );
    final values = completed.toMap()..remove('id');
    final updated = await transaction.update(
      'game_periods',
      values,
      where: 'id = ? AND profile_id = ?',
      whereArgs: [periodId, profileId],
    );
    if (updated != 1) {
      throw StateError('Test fixture failed to complete period $periodId.');
    }
    return completed;
  });
}

Future<GamePeriod> resolveCheckpointForTest(
  AppDatabase database, {
  required int profileId,
  required int periodId,
  required String checkpointId,
}) async {
  final db = await database.database;
  return db.transaction((transaction) async {
    final rows = await transaction.query(
      'game_periods',
      where: 'id = ? AND profile_id = ?',
      whereArgs: [periodId, profileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'Period $periodId does not exist for profile $profileId.',
      );
    }
    final period = GamePeriod.fromMap(rows.single);
    if (!period.requiredCheckpoints.contains(checkpointId)) {
      throw StateError('Checkpoint $checkpointId is not required.');
    }
    if (period.resolvedCheckpoints.contains(checkpointId)) return period;
    final resolved = [
      for (final required in period.requiredCheckpoints)
        if (required == checkpointId ||
            period.resolvedCheckpoints.contains(required))
          required,
    ];
    final updated = period.copyWith(
      resolvedCheckpoints: List.unmodifiable(resolved),
      status: resolved.length == period.requiredCheckpoints.length
          ? GamePeriodStatus.readyToFinish
          : GamePeriodStatus.active,
    );
    final values = updated.toMap()..remove('id');
    await transaction.update(
      'game_periods',
      values,
      where: 'id = ? AND profile_id = ?',
      whereArgs: [periodId, profileId],
    );
    return updated;
  });
}
