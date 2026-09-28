import 'dart:convert';

import 'package:path/path.dart' as path_util;
import 'package:sqflite/sqflite.dart' as sqflite;

class AppDatabase {
  AppDatabase({sqflite.DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? sqflite.databaseFactory;

  static const schemaVersion = 14;

  final sqflite.DatabaseFactory _factory;
  final String? databasePath;
  sqflite.Database? _database;

  Future<sqflite.Database> get database async {
    final openDatabase = _database;
    if (openDatabase != null) return openDatabase;

    final resolvedPath =
        databasePath ??
        path_util.join(await sqflite.getDatabasesPath(), 'finny.sqlite');
    _database = await _factory.openDatabase(
      resolvedPath,
      options: sqflite.OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    return _database!;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  static Future<void> _createSchema(sqflite.Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_name TEXT NOT NULL,
        profile_type TEXT NOT NULL CHECK (profile_type IN ('NORMAL', 'DEMO')),
        onboarding_completed INTEGER NOT NULL DEFAULT 0 CHECK (onboarding_completed IN (0, 1)),
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pets (
        profile_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        color_id TEXT NOT NULL,
        pattern_id TEXT NOT NULL,
        development_stage INTEGER NOT NULL DEFAULT 1 CHECK (development_stage >= 0),
        growth_points INTEGER NOT NULL DEFAULT 0 CHECK (growth_points >= 0),
        satiety INTEGER NOT NULL DEFAULT 40 CHECK (satiety BETWEEN 0 AND 100),
        care INTEGER NOT NULL DEFAULT 40 CHECK (care BETWEEN 0 AND 100),
        mood INTEGER NOT NULL DEFAULT 40 CHECK (mood BETWEEN 0 AND 100),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE game_states (
        profile_id INTEGER PRIMARY KEY,
        wallet_balance INTEGER NOT NULL DEFAULT 0 CHECK (wallet_balance >= 0),
        current_period INTEGER NOT NULL DEFAULT 0 CHECK (current_period >= 0),
        active_goal_id TEXT,
        saved_amount INTEGER NOT NULL DEFAULT 0 CHECK (saved_amount >= 0),
        goal_change_used INTEGER NOT NULL DEFAULT 0 CHECK (goal_change_used IN (0, 1)),
        updated_at TEXT NOT NULL,
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE game_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        definition_id TEXT NOT NULL,
        period_number INTEGER NOT NULL CHECK (period_number > 0),
        start_wallet_balance INTEGER NOT NULL CHECK (start_wallet_balance >= 0),
        base_income INTEGER NOT NULL DEFAULT 0 CHECK (base_income >= 0),
        extra_income INTEGER NOT NULL DEFAULT 0 CHECK (extra_income >= 0),
        planned_need INTEGER NOT NULL DEFAULT 0 CHECK (planned_need >= 0),
        planned_want INTEGER NOT NULL DEFAULT 0 CHECK (planned_want >= 0),
        planned_savings INTEGER NOT NULL DEFAULT 0 CHECK (planned_savings >= 0),
        planned_free INTEGER NOT NULL DEFAULT 0 CHECK (planned_free >= 0),
        actual_need INTEGER NOT NULL DEFAULT 0 CHECK (actual_need >= 0),
        actual_want INTEGER NOT NULL DEFAULT 0 CHECK (actual_want >= 0),
        actual_savings INTEGER NOT NULL DEFAULT 0 CHECK (actual_savings >= 0),
        required_checkpoints TEXT NOT NULL DEFAULT '[]',
        resolved_checkpoints TEXT NOT NULL DEFAULT '[]',
        end_wallet_balance INTEGER CHECK (end_wallet_balance >= 0),
        growth_points_earned INTEGER NOT NULL DEFAULT 0 CHECK (growth_points_earned >= 0),
        day_progress INTEGER NOT NULL DEFAULT 0
          CHECK (day_progress BETWEEN 0 AND 100),
        active_elapsed_milliseconds INTEGER NOT NULL DEFAULT 0
          CHECK (active_elapsed_milliseconds BETWEEN 0 AND 360000),
        satiety_decay_applied INTEGER NOT NULL DEFAULT 0
          CHECK (satiety_decay_applied BETWEEN 0 AND 15),
        care_decay_applied INTEGER NOT NULL DEFAULT 0
          CHECK (care_decay_applied BETWEEN 0 AND 10),
        mood_decay_applied INTEGER NOT NULL DEFAULT 0
          CHECK (mood_decay_applied BETWEEN 0 AND 12),
        status TEXT NOT NULL CHECK (status IN ('planning', 'active', 'readyToFinish', 'completed')),
        created_at TEXT NOT NULL,
        completed_at TEXT,
        UNIQUE (profile_id, period_number),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        profile_id INTEGER NOT NULL,
        period_id INTEGER,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL CHECK (amount != 0),
        source TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deduplication_key TEXT,
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
        FOREIGN KEY (period_id) REFERENCES game_periods(id) ON DELETE SET NULL,
        UNIQUE (profile_id, deduplication_key)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory (
        profile_id INTEGER NOT NULL,
        item_id TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        acquired_at TEXT NOT NULL,
        PRIMARY KEY (profile_id, item_id),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');

    await _createTaskProgressTable(db);

    await _createCompletedGoalsTable(db);

    await db.execute(
      'CREATE INDEX idx_periods_profile_status ON game_periods(profile_id, status)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_profile_created ON transactions(profile_id, created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_transactions_period ON transactions(profile_id, period_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX idx_periods_profile_id_id ON game_periods(profile_id, id)',
    );
    await _createPetDailyUsageTable(db);
    await _createPetActionOperationsTable(db);
    await _createPeriodSpecialActionsTable(db);
    await _createCampaignStoryEventsTable(db);
    await _createDayFiveSaleAssignmentsTable(db);
    await _createPostCampaignTables(db);
  }

  static Future<void> _upgradeSchema(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE game_periods ADD COLUMN definition_id TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE game_periods ADD COLUMN required_checkpoints TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE game_periods ADD COLUMN resolved_checkpoints TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute('''
        UPDATE game_periods
        SET
          definition_id = CASE period_number
            WHEN 1 THEN 'period_1_needs_vs_wants'
            WHEN 2 THEN 'period_2_saving'
            WHEN 3 THEN 'period_3_plans_changed'
            WHEN 4 THEN 'period_4_discount'
            WHEN 5 THEN 'period_5_independent'
            ELSE 'legacy_period_' || period_number
          END,
          required_checkpoints = CASE period_number
            WHEN 1 THEN '["financial_task","mandatory_need","savings_decision"]'
            WHEN 2 THEN '["financial_task","mandatory_need","savings_decision"]'
            WHEN 3 THEN '["financial_task","mandatory_need","savings_decision","changed_circumstance"]'
            WHEN 4 THEN '["financial_task","mandatory_need","savings_decision","discount_decision"]'
            WHEN 5 THEN '["financial_task","mandatory_need","savings_decision"]'
            ELSE '[]'
          END
        WHERE definition_id = ''
      ''');
      await db.execute(
        'CREATE INDEX idx_transactions_period ON transactions(profile_id, period_id)',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE game_states ADD COLUMN goal_change_used INTEGER NOT NULL DEFAULT 0 CHECK (goal_change_used IN (0, 1))',
      );
      await _createCompletedGoalsTable(db);
    }
    if (oldVersion < 4) {
      await _createTaskProgressTable(db);
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        table: 'pets',
        column: 'care',
        definition:
            'INTEGER NOT NULL DEFAULT 40 CHECK (care BETWEEN 0 AND 100)',
      );
      await _addColumnIfMissing(
        db,
        table: 'game_periods',
        column: 'active_elapsed_milliseconds',
        definition: 'INTEGER NOT NULL DEFAULT 0 CHECK (active_elapsed_milliseconds BETWEEN 0 AND 360000)',
      );
      await _addColumnIfMissing(
        db,
        table: 'game_periods',
        column: 'satiety_decay_applied',
        definition: 'INTEGER NOT NULL DEFAULT 0 CHECK (satiety_decay_applied BETWEEN 0 AND 15)',
      );
      await _addColumnIfMissing(
        db,
        table: 'game_periods',
        column: 'care_decay_applied',
        definition: 'INTEGER NOT NULL DEFAULT 0 CHECK (care_decay_applied BETWEEN 0 AND 10)',
      );
      await _addColumnIfMissing(
        db,
        table: 'game_periods',
        column: 'mood_decay_applied',
        definition: 'INTEGER NOT NULL DEFAULT 0 CHECK (mood_decay_applied BETWEEN 0 AND 12)',
      );
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_periods_profile_id_id ON game_periods(profile_id, id)',
      );
      await _createPetDailyUsageTable(db);
    }
    if (oldVersion < 6) {
      await _createPetActionOperationsTable(db);
    }
    if (oldVersion < 7) {
      await _createPeriodSpecialActionsTable(db);
    }
    if (oldVersion < 8) {
      await _migrateDayLifecycleV8(db);
    }
    if (oldVersion < 9) {
      await _migrateVirtualDayV9(db);
    }
    if (oldVersion < 10) {
      await _createCampaignStoryEventsTable(db);
    }
    if (oldVersion < 11) {
      await _migrateDay4V11(db);
    }
    if (oldVersion < 12) {
      await _createDayFiveSaleAssignmentsTable(db);
    }
    if (oldVersion < 13) {
      await _createPostCampaignTables(db);
    }
    // Earlier schemas create this table above with the current constraint.
    if (oldVersion == 13) {
      await _migrateAccessorySlotsV14(db);
    }
  }

  static Future<void> _migrateAccessorySlotsV14(
    sqflite.DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE free_play_equipped_accessories_v14 (
        profile_id INTEGER NOT NULL,
        slot TEXT NOT NULL CHECK (slot IN ('head', 'neck', 'back')),
        item_id TEXT NOT NULL,
        PRIMARY KEY (profile_id, slot),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
        FOREIGN KEY (profile_id, item_id)
          REFERENCES inventory(profile_id, item_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      INSERT INTO free_play_equipped_accessories_v14 (profile_id, slot, item_id)
      SELECT profile_id,
        CASE WHEN item_id = 'accessory_hat' THEN 'back' ELSE slot END,
        item_id
      FROM free_play_equipped_accessories
    ''');
    await db.execute('DROP TABLE free_play_equipped_accessories');
    await db.execute('''
      ALTER TABLE free_play_equipped_accessories_v14
      RENAME TO free_play_equipped_accessories
    ''');
  }

  static Future<void> _createPostCampaignTables(
    sqflite.DatabaseExecutor db,
  ) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS campaign_completion (
        profile_id INTEGER PRIMARY KEY,
        finale_acknowledged_at TEXT,
        free_play_started_at TEXT,
        CHECK (free_play_started_at IS NULL OR finale_acknowledged_at IS NOT NULL),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS free_play_pet_operations (
        profile_id INTEGER NOT NULL,
        operation_id TEXT NOT NULL CHECK (length(trim(operation_id)) > 0),
        action_id TEXT NOT NULL CHECK (length(trim(action_id)) > 0),
        created_at TEXT NOT NULL,
        PRIMARY KEY (profile_id, operation_id),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS free_play_equipped_accessories (
        profile_id INTEGER NOT NULL,
        slot TEXT NOT NULL CHECK (slot IN ('head', 'neck', 'back')),
        item_id TEXT NOT NULL,
        PRIMARY KEY (profile_id, slot),
        FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
        FOREIGN KEY (profile_id, item_id)
          REFERENCES inventory(profile_id, item_id) ON DELETE CASCADE
      )
    ''');
  }

  static Future<void> _migrateDay4V11(sqflite.DatabaseExecutor db) async {
    final periodColumns = await db.rawQuery('PRAGMA table_info(game_periods)');
    final periodColumnNames = periodColumns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();
    if (!periodColumnNames.containsAll({
      'id',
      'profile_id',
      'period_number',
      'status',
      'required_checkpoints',
      'resolved_checkpoints',
    })) {
      return;
    }
    final periods = await db.query(
      'game_periods',
      where: "period_number = 4 AND status != 'completed'",
    );
    for (final row in periods) {
      final required = _decodeCheckpointList(row['required_checkpoints'])
          .where((id) => id != 'discount_decision')
          .toList(growable: false);
      final resolved = _decodeCheckpointList(row['resolved_checkpoints'])
          .where((id) => id != 'discount_decision')
          .toList(growable: false);
      final status = row['status'] as String;
      await db.update(
        'game_periods',
        {
          'required_checkpoints': jsonEncode(required),
          'resolved_checkpoints': jsonEncode(resolved),
          'status': status == 'active' && required.every(resolved.contains)
              ? 'readyToFinish'
              : status,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      await db.delete(
        'period_special_actions',
        where: "profile_id = ? AND period_id = ? AND action_id = ? AND outcome = 'skipped'",
        whereArgs: [row['profile_id'], row['id'], 'day4_treat_discount'],
      );
    }

    final progressTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'task_progress'",
    );
    if (progressTable.isEmpty) return;
    final oldProgress = await db.query(
      'task_progress',
      where: 'task_id = ? AND status = ? AND reward_claimed = 1',
      whereArgs: ['task_discount_04', 'completed'],
    );
    for (final progress in oldProgress) {
      final profileId = progress['profile_id'] as int;
      final periodRows = await db.query(
        'game_periods',
        where: 'profile_id = ? AND period_number = 4',
        whereArgs: [profileId],
      );
      if (periodRows.length != 1) continue;
      final period = periodRows.single;
      final periodId = period['id'] as int;
      final resolved = _decodeCheckpointList(period['resolved_checkpoints']);
      final oldKey = 'task_reward_${periodId}_task_discount_04';
      final rewardRows = await db.query(
        'transactions',
        where: 'profile_id = ? AND period_id = ? AND source = ? AND deduplication_key = ?',
        whereArgs: [
          profileId,
          periodId,
          'task_reward_task_discount_04',
          oldKey,
        ],
      );
      if (!resolved.contains('financial_task') ||
          rewardRows.length != 1 ||
          rewardRows.single['type'] != 'task_reward' ||
          rewardRows.single['amount'] != 50) {
        continue;
      }
      final oldState = jsonDecode(progress['scenario_state'] as String);
      if (oldState is! Map ||
          oldState.length != 1 ||
          oldState['answerId'] != 'consider') {
        continue;
      }
      await db.update(
        'transactions',
        {
          'source': 'task_reward_task_shopping_trip_04',
          'deduplication_key': 'task_reward_${periodId}_task_shopping_trip_04',
        },
        where: 'id = ?',
        whereArgs: [rewardRows.single['id']],
      );
      await db.update(
        'task_progress',
        {
          'task_id': 'task_shopping_trip_04',
          'scenario_state': jsonEncode({
            'type': 'legacy_day4_discount',
            'legacyTaskId': 'task_discount_04',
          }),
        },
        where: 'profile_id = ? AND task_id = ?',
        whereArgs: [profileId, 'task_discount_04'],
      );
    }
  }

  static Future<void> _migrateVirtualDayV9(sqflite.DatabaseExecutor db) async {
    final periodColumns = await db.rawQuery('PRAGMA table_info(game_periods)');
    final hadDayProgress = periodColumns.any(
      (column) => column['name'] == 'day_progress',
    );
    await _addColumnIfMissing(
      db,
      table: 'game_periods',
      column: 'day_progress',
      definition:
          'INTEGER NOT NULL DEFAULT 0 CHECK (day_progress BETWEEN 0 AND 100)',
    );
    if (!hadDayProgress) {
      final hasElapsed = periodColumns.any(
        (column) => column['name'] == 'active_elapsed_milliseconds',
      );
      final activeProgress = hasElapsed
          ? 'MIN(69, CAST(active_elapsed_milliseconds * 69 / 360000 AS INTEGER))'
          : '0';
      await db.execute('''
        UPDATE game_periods
        SET day_progress = CASE status
          WHEN 'planning' THEN 0
          WHEN 'readyToFinish' THEN 76
          WHEN 'completed' THEN 100
          WHEN 'active' THEN $activeProgress
          ELSE 0
        END
      ''');
    }
    final inventoryTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'inventory'",
    );
    if (inventoryTable.isNotEmpty) {
      await db.execute('''
        INSERT OR IGNORE INTO inventory (
          profile_id, item_id, quantity, acquired_at
        )
        SELECT id, 'care_toothbrush', 1, created_at
        FROM profiles
      ''');
    }
  }

  static Future<void> _migrateDayLifecycleV8(
    sqflite.DatabaseExecutor db,
  ) async {
    final periodColumns = await db.rawQuery('PRAGMA table_info(game_periods)');
    final periodColumnNames = periodColumns
        .map((column) => column['name'])
        .whereType<String>()
        .toSet();
    if (!periodColumnNames.containsAll({
      'id',
      'required_checkpoints',
      'resolved_checkpoints',
      'status',
    })) {
      return;
    }
    final periods = await db.query(
      'game_periods',
      columns: ['id', 'required_checkpoints', 'resolved_checkpoints', 'status'],
    );
    for (final row in periods) {
      final required = _decodeCheckpointList(row['required_checkpoints'])
          .where((value) => value != 'mandatory_need')
          .toList(growable: false);
      final resolved = _decodeCheckpointList(row['resolved_checkpoints'])
          .where((value) => value != 'mandatory_need')
          .toList(growable: false);
      final oldStatus = row['status'] as String;
      final newStatus =
          oldStatus == 'active' && required.every(resolved.contains)
          ? 'readyToFinish'
          : oldStatus;
      await db.update(
        'game_periods',
        {
          'required_checkpoints': jsonEncode(required),
          'resolved_checkpoints': jsonEncode(resolved),
          'status': newStatus,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    final petColumns = await db.rawQuery('PRAGMA table_info(pets)');
    if (petColumns.any((column) => column['name'] == 'development_stage')) {
      await db.update('pets', {
        'development_stage': 1,
      }, where: 'development_stage = 0');
    }
  }

  static List<String> _decodeCheckpointList(Object? source) {
    if (source is! String) {
      throw const FormatException('Checkpoint snapshot must be JSON text.');
    }
    final decoded = jsonDecode(source);
    if (decoded is! List || decoded.any((value) => value is! String)) {
      throw const FormatException('Checkpoint snapshot must be a string list.');
    }
    return decoded.cast<String>();
  }

  static Future<void> _createPeriodSpecialActionsTable(
    sqflite.DatabaseExecutor db,
  ) => db.execute('''
    CREATE TABLE IF NOT EXISTS period_special_actions (
      profile_id INTEGER NOT NULL,
      period_id INTEGER NOT NULL,
      action_id TEXT NOT NULL CHECK (length(trim(action_id)) > 0),
      outcome TEXT NOT NULL CHECK (outcome IN ('purchased', 'skipped')),
      operation_id TEXT NOT NULL CHECK (length(trim(operation_id)) > 0),
      created_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, period_id, action_id),
      UNIQUE (profile_id, operation_id),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY (profile_id, period_id)
        REFERENCES game_periods(profile_id, id) ON DELETE CASCADE
    )
  ''');

  static Future<void> _createCampaignStoryEventsTable(
    sqflite.DatabaseExecutor db,
  ) => db.execute('''
    CREATE TABLE IF NOT EXISTS campaign_story_events (
      profile_id INTEGER NOT NULL,
      story_id TEXT NOT NULL CHECK (length(trim(story_id)) > 0),
      origin_period_id INTEGER NOT NULL,
      threshold INTEGER NOT NULL CHECK (threshold IN (1, 2)),
      status TEXT NOT NULL CHECK (status IN ('armed', 'postponed', 'purchased')),
      armed_at TEXT NOT NULL,
      postponed_at TEXT,
      purchased_at TEXT,
      decision_operation_id TEXT,
      decision_kind TEXT CHECK (decision_kind IN ('postpone', 'purchase_wallet', 'purchase_savings')),
      purchase_period_id INTEGER,
      savings_used INTEGER NOT NULL DEFAULT 0 CHECK (savings_used >= 0),
      PRIMARY KEY (profile_id, story_id),
      UNIQUE (profile_id, decision_operation_id),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY (profile_id, origin_period_id)
        REFERENCES game_periods(profile_id, id) ON DELETE CASCADE,
      FOREIGN KEY (profile_id, purchase_period_id)
        REFERENCES game_periods(profile_id, id) ON DELETE SET NULL
    )
  ''');

  static Future<void> _createTaskProgressTable(sqflite.DatabaseExecutor db) =>
      db.execute('''
    CREATE TABLE IF NOT EXISTS task_progress (
      profile_id INTEGER NOT NULL,
      task_id TEXT NOT NULL,
      status TEXT NOT NULL,
      reward_claimed INTEGER NOT NULL DEFAULT 0 CHECK (reward_claimed IN (0, 1)),
      scenario_state TEXT NOT NULL DEFAULT '{}',
      updated_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, task_id),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
  ''');

  static Future<void> _createDayFiveSaleAssignmentsTable(
    sqflite.DatabaseExecutor db,
  ) => db.execute('''
    CREATE TABLE IF NOT EXISTS day5_sale_assignments (
      profile_id INTEGER NOT NULL,
      period_id INTEGER NOT NULL,
      item_id TEXT NOT NULL CHECK (length(trim(item_id)) > 0),
      discount_amount INTEGER NOT NULL CHECK (discount_amount > 0),
      purchase_operation_id TEXT,
      purchased_at TEXT,
      PRIMARY KEY (profile_id, period_id, item_id),
      UNIQUE (profile_id, purchase_operation_id),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY (profile_id, period_id)
        REFERENCES game_periods(profile_id, id) ON DELETE CASCADE
    )
  ''');

  static Future<void> _createCompletedGoalsTable(sqflite.DatabaseExecutor db) =>
      db.execute('''
    CREATE TABLE completed_goals (
      profile_id INTEGER NOT NULL,
      goal_id TEXT NOT NULL,
      reward_asset_id TEXT NOT NULL,
      price_paid INTEGER NOT NULL CHECK (price_paid > 0),
      completed_at TEXT NOT NULL,
      claim_operation_id TEXT NOT NULL,
      PRIMARY KEY (profile_id, goal_id),
      UNIQUE (profile_id, claim_operation_id),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE
    )
  ''');

  static Future<void> _createPetDailyUsageTable(sqflite.DatabaseExecutor db) =>
      db.execute('''
    CREATE TABLE IF NOT EXISTS pet_daily_usage (
      profile_id INTEGER NOT NULL,
      period_id INTEGER NOT NULL,
      action_id TEXT NOT NULL CHECK (length(trim(action_id)) > 0),
      usage_slot TEXT NOT NULL DEFAULT 'default'
        CHECK (length(trim(usage_slot)) > 0),
      usage_count INTEGER NOT NULL DEFAULT 1 CHECK (usage_count > 0),
      updated_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, period_id, action_id, usage_slot),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY (profile_id, period_id)
        REFERENCES game_periods(profile_id, id) ON DELETE CASCADE
    )
  ''');

  static Future<void> _createPetActionOperationsTable(
    sqflite.DatabaseExecutor db,
  ) => db.execute('''
    CREATE TABLE IF NOT EXISTS pet_action_operations (
      profile_id INTEGER NOT NULL,
      operation_id TEXT NOT NULL CHECK (length(trim(operation_id)) > 0),
      period_id INTEGER NOT NULL,
      action_id TEXT NOT NULL CHECK (length(trim(action_id)) > 0),
      usage_slot TEXT NOT NULL CHECK (length(trim(usage_slot)) > 0),
      created_at TEXT NOT NULL,
      PRIMARY KEY (profile_id, operation_id),
      FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE,
      FOREIGN KEY (profile_id, period_id)
        REFERENCES game_periods(profile_id, id) ON DELETE CASCADE
    )
  ''');

  static Future<void> _addColumnIfMissing(
    sqflite.DatabaseExecutor db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.isEmpty) {
      throw StateError('Cannot migrate missing table $table.');
    }
    if (columns.any((row) => row['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
