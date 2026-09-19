import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_period.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppDatabase createTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
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
