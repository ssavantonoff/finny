import 'package:finny/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppDatabase createTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
}
