import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/task_progress.dart';
import 'package:finny/repositories/game_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

Future<void> expectTaskProgressV4Schema(
  AppDatabase database, {
  required int profileId,
}) async {
  final db = await database.database;
  expect(
    (await db.rawQuery('PRAGMA user_version')).single['user_version'],
    AppDatabase.schemaVersion,
  );

  final columns = await db.rawQuery('PRAGMA table_info(task_progress)');
  expect(columns.map((row) => row['name']), [
    'profile_id',
    'task_id',
    'status',
    'reward_claimed',
    'scenario_state',
    'updated_at',
  ]);
  expect(columns.first['pk'], 1);
  expect(columns[1]['pk'], 2);
  expect(columns[3]['dflt_value'], '0');
  expect(columns[4]['dflt_value'], "'{}'");
  expect(columns.every((row) => row['notnull'] == 1), isTrue);

  final foreignKeys = await db.rawQuery(
    'PRAGMA foreign_key_list(task_progress)',
  );
  expect(
    foreignKeys.any(
      (row) =>
          row['table'] == 'profiles' &&
          row['from'] == 'profile_id' &&
          row['to'] == 'id' &&
          row['on_delete'] == 'CASCADE',
    ),
    isTrue,
  );

  const taskId = 'schema_probe_claimed';
  final now = DateTime.utc(2026, 9, 18);
  await db.insert(
    'task_progress',
    TaskProgress(
      profileId: profileId,
      taskId: taskId,
      status: TaskProgressStatus.completed,
      rewardClaimed: true,
      scenarioState: const {'answerId': 'apple'},
      updatedAt: now,
    ).toMap(),
  );
  final progress = await SqliteGameRepository(database)
      .getTaskProgress(profileId, taskId);
  expect(progress?.profileId, profileId);
  expect(progress?.taskId, taskId);
  expect(progress?.status, TaskProgressStatus.completed);
  expect(progress?.rewardClaimed, isTrue);
  expect(progress?.scenarioState, {'answerId': 'apple'});
  expect(progress?.updatedAt, now);

  await expectLater(
    db.insert(
      'task_progress',
      TaskProgress(
        profileId: profileId,
        taskId: taskId,
        status: TaskProgressStatus.completed,
        rewardClaimed: true,
        scenarioState: const {'answerId': 'apple'},
        updatedAt: now,
      ).toMap(),
    ),
    throwsA(isA<DatabaseException>()),
  );
  await expectLater(
    db.insert('task_progress', {
      'profile_id': profileId,
      'task_id': 'schema_probe_invalid_claim',
      'status': 'completed',
      'reward_claimed': 2,
      'updated_at': now.toIso8601String(),
    }),
    throwsA(isA<DatabaseException>()),
  );
  await expectLater(
    db.insert('task_progress', {
      'profile_id': -1,
      'task_id': 'schema_probe_foreign',
      'status': 'completed',
      'updated_at': now.toIso8601String(),
    }),
    throwsA(isA<DatabaseException>()),
  );

  await db.insert('task_progress', {
    'profile_id': profileId,
    'task_id': 'schema_probe_default',
    'status': 'completed',
    'updated_at': now.toIso8601String(),
  });
  final defaultRows = await db.query(
    'task_progress',
    where: 'profile_id = ? AND task_id = ?',
    whereArgs: [profileId, 'schema_probe_default'],
  );
  expect(defaultRows.single['reward_claimed'], 0);
  expect(defaultRows.single['scenario_state'], '{}');
}
