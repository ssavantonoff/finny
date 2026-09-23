import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/campaign_lifecycle.dart';
import 'package:finny/models/content_entry.dart';
import 'package:sqflite/sqflite.dart';

class CampaignLifecycleRepository {
  CampaignLifecycleRepository(this._database);

  final AppDatabase _database;

  Future<bool> hasFivePeriods(int profileId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM game_periods WHERE profile_id = ? AND period_number BETWEEN 1 AND 5',
      [profileId],
    );
    return (rows.single['count'] as int) == 5;
  }

  static Map<int, String> canonicalDays(List<PeriodDefinition> definitions) {
    final days = <int, String>{};
    for (final definition in definitions) {
      if (definition.number >= 1 && definition.number <= 5) {
        if (days.containsKey(definition.number)) {
          throw const FormatException('Duplicate canonical campaign day.');
        }
        days[definition.number] = definition.id;
      }
    }
    if (days.length != 5) {
      throw const FormatException('Canonical Days 1–5 are required.');
    }
    return days;
  }

  static Future<CampaignLifecycleSnapshot> readInTransaction(
    DatabaseExecutor db,
    int profileId,
    List<PeriodDefinition> definitions,
  ) async {
    final periods = await db.query(
      'game_periods',
      columns: ['period_number', 'definition_id', 'status'],
      where: 'profile_id = ? AND period_number BETWEEN 1 AND 5',
      whereArgs: [profileId],
    );
    if (periods.length < 5) {
      return const CampaignLifecycleSnapshot(mode: CampaignMode.campaign);
    }
    final days = canonicalDays(definitions);
    final completed =
        periods.length == 5 &&
        periods.every(
          (period) =>
              days[period['period_number']] == period['definition_id'] &&
              period['status'] == 'completed',
        );
    if (!completed) {
      return const CampaignLifecycleSnapshot(mode: CampaignMode.campaign);
    }
    final rows = await db.query(
      'campaign_completion',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    final row = rows.isEmpty ? null : rows.single;
    final acknowledged = row?['finale_acknowledged_at'] as String?;
    final started = row?['free_play_started_at'] as String?;
    if (started != null && acknowledged == null) {
      throw StateError('Free Play requires an acknowledged finale.');
    }
    return CampaignLifecycleSnapshot(
      mode: started != null
          ? CampaignMode.freePlay
          : acknowledged != null
          ? CampaignMode.campaignFinished
          : CampaignMode.finalePending,
      finaleAcknowledgedAt: acknowledged == null
          ? null
          : DateTime.parse(acknowledged),
      freePlayStartedAt: started == null ? null : DateTime.parse(started),
    );
  }

  Future<CampaignLifecycleSnapshot> load(
    int profileId,
    List<PeriodDefinition> definitions,
  ) async {
    final db = await _database.database;
    return readInTransaction(db, profileId, definitions);
  }

  Future<CampaignLifecycleSnapshot> finishStory(
    int profileId,
    List<PeriodDefinition> definitions,
  ) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final before = await readInTransaction(txn, profileId, definitions);
      if (!before.campaignCompleted) {
        throw StateError('The campaign is not complete.');
      }
      if (before.finaleAcknowledgedAt == null) {
        await txn.rawInsert(
          '''
          INSERT INTO campaign_completion (profile_id, finale_acknowledged_at)
          VALUES (?, ?)
          ON CONFLICT(profile_id) DO UPDATE SET
            finale_acknowledged_at = COALESCE(finale_acknowledged_at, excluded.finale_acknowledged_at)
        ''',
          [profileId, DateTime.now().toUtc().toIso8601String()],
        );
      }
      return readInTransaction(txn, profileId, definitions);
    });
  }

  Future<CampaignLifecycleSnapshot> startFreePlay(
    int profileId,
    List<PeriodDefinition> definitions,
  ) async {
    final db = await _database.database;
    return db.transaction((txn) async {
      final before = await readInTransaction(txn, profileId, definitions);
      if (!before.campaignCompleted) {
        throw StateError('The campaign is not complete.');
      }
      if (before.freePlayStartedAt == null) {
        final now = DateTime.now().toUtc().toIso8601String();
        await txn.rawInsert(
          '''
          INSERT INTO campaign_completion
            (profile_id, finale_acknowledged_at, free_play_started_at)
          VALUES (?, ?, ?)
          ON CONFLICT(profile_id) DO UPDATE SET
            finale_acknowledged_at = COALESCE(finale_acknowledged_at, excluded.finale_acknowledged_at),
            free_play_started_at = COALESCE(free_play_started_at, excluded.free_play_started_at)
        ''',
          [profileId, now, now],
        );
        final changed = await txn.update(
          'game_states',
          {'goal_change_used': 0},
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
        if (changed != 1) throw StateError('Game state is missing.');
      }
      return readInTransaction(txn, profileId, definitions);
    });
  }
}
