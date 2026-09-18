import 'package:path/path.dart' as path_util;
import 'package:sqflite/sqflite.dart' as sqflite;

class AppDatabase {
  AppDatabase({sqflite.DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? sqflite.databaseFactory;

  static const schemaVersion = 4;

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
        development_stage INTEGER NOT NULL DEFAULT 0 CHECK (development_stage >= 0),
        growth_points INTEGER NOT NULL DEFAULT 0 CHECK (growth_points >= 0),
        satiety INTEGER NOT NULL DEFAULT 100 CHECK (satiety BETWEEN 0 AND 100),
        mood INTEGER NOT NULL DEFAULT 100 CHECK (mood BETWEEN 0 AND 100),
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
  }

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
}
