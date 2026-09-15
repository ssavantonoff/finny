import 'package:finny/core/database/app_database.dart';
import 'package:finny/models/profile.dart';

abstract interface class ProfileRepository {
  Future<Profile> create(Profile profile);
  Future<Profile?> findById(int id);
  Future<List<Profile>> findAll();
  Future<void> update(Profile profile);
}

class SqliteProfileRepository implements ProfileRepository {
  SqliteProfileRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  @override
  Future<Profile> create(Profile profile) async {
    if (profile.id != null) {
      throw ArgumentError('A new profile must not already have an id.');
    }
    final db = await _appDatabase.database;
    final id = await db.insert('profiles', profile.toMap());
    return profile.copyWith(id: id);
  }

  @override
  Future<Profile?> findById(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Profile.fromMap(rows.single);
  }

  @override
  Future<List<Profile>> findAll() async {
    final db = await _appDatabase.database;
    final rows = await db.query('profiles', orderBy: 'created_at ASC');
    return rows.map(Profile.fromMap).toList(growable: false);
  }

  @override
  Future<void> update(Profile profile) async {
    final id = profile.id;
    if (id == null) {
      throw ArgumentError('Cannot update a profile without an id.');
    }
    final db = await _appDatabase.database;
    final count = await db.update(
      'profiles',
      profile.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('Profile $id does not exist.');
  }
}
