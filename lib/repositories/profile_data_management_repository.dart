import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/game_state.dart';
import 'package:finny/models/pet.dart';
import 'package:finny/models/pet_state_rules.dart';
import 'package:finny/models/profile.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class ProfileDataManagementPort {
  Future<void> resetNormalProfile(int profileId);
  Future<void> deleteNormalProfile(int profileId);
}

class SqliteProfileDataManagement implements ProfileDataManagementPort {
  SqliteProfileDataManagement(this._appDatabase);

  static const _starterToothbrushId = 'care_toothbrush';
  static const _resettableRuntimeTables = [
    'pet_action_operations',
    'pet_daily_usage',
    'period_special_actions',
    'campaign_story_events',
    'task_progress',
    'transactions',
    'inventory',
    'game_periods',
    'completed_goals',
    'game_states',
  ];

  final AppDatabase _appDatabase;

  @override
  Future<void> resetNormalProfile(int profileId) async {
    _validateProfileId(profileId);
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _requireNormalProfile(txn, profileId);
      final pet = await _readPet(txn, profileId);

      for (final table in _resettableRuntimeTables) {
        await txn.delete(
          table,
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
      }

      await txn.insert(
        'game_states',
        GameState(
          profileId: profileId,
          walletBalance: 0,
          currentPeriod: 0,
          savedAmount: 0,
          goalChangeUsed: false,
          updatedAt: DateTime.now().toUtc(),
        ).toMap(),
      );

      if (pet != null) {
        final updated = await txn.update(
          'pets',
          {
            'development_stage': 1,
            'growth_points': 0,
            'satiety': PetStateRules.dayOneInitialSatiety,
            'care': PetStateRules.dayOneInitialCare,
            'mood': PetStateRules.dayOneInitialMood,
          },
          where: 'profile_id = ?',
          whereArgs: [profileId],
        );
        if (updated != 1) {
          throw StateError('Pet for profile $profileId is missing.');
        }
      }

      await txn.insert('inventory', {
        'profile_id': profileId,
        'item_id': _starterToothbrushId,
        'quantity': 1,
        'acquired_at': DateTime.now().toUtc().toIso8601String(),
      });
    });
  }

  @override
  Future<void> deleteNormalProfile(int profileId) async {
    _validateProfileId(profileId);
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _requireNormalProfile(txn, profileId);
      final deleted = await txn.delete(
        'profiles',
        where: 'id = ?',
        whereArgs: [profileId],
      );
      if (deleted != 1) {
        throw StateError('Profile $profileId does not exist.');
      }
    });
  }

  Future<void> _requireNormalProfile(DatabaseExecutor db, int profileId) async {
    final rows = await db.query(
      'profiles',
      columns: ['profile_type'],
      where: 'id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Profile $profileId does not exist.');
    }
    if (rows.single['profile_type'] != ProfileType.normal.storageValue) {
      throw StateError('Only NORMAL profiles can use data management.');
    }
  }

  Future<Pet?> _readPet(DatabaseExecutor db, int profileId) async {
    final rows = await db.query(
      'pets',
      where: 'profile_id = ?',
      whereArgs: [profileId],
      limit: 1,
    );
    return rows.isEmpty ? null : Pet.fromMap(rows.single);
  }

  void _validateProfileId(int profileId) {
    if (profileId <= 0) {
      throw ArgumentError.value(profileId, 'profileId', 'Must be positive.');
    }
  }
}
