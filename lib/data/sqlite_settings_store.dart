import 'package:sqflite/sqflite.dart';

import 'settings_store.dart';

/// The shipping settings store: a key-value table in the app's SQLite file.
class SqliteSettingsStore implements SettingsStore {
  const SqliteSettingsStore(this._db);

  static const _settings = 'settings';

  final Database _db;

  @override
  Future<String?> read(String key) async {
    final rows = await _db.query(
      _settings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.single['value'] as String;
  }

  @override
  Future<void> write(String key, String value) => _db.insert(
    _settings,
    <String, Object?>{'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
