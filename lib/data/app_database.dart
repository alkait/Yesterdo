import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite file. Nothing leaves the device.
abstract final class AppDatabase {
  static const _fileName = 'remind_me.db';
  static const _version = 1;

  static Future<Database> open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(path, version: _version, onCreate: createSchema);
  }

  /// Exposed so tests can build the same schema over an in-memory database.
  static Future<void> createSchema(Database db, int version) async {
    await db.execute('''
CREATE TABLE todos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  day INTEGER NOT NULL,
  title TEXT NOT NULL,
  done INTEGER NOT NULL DEFAULT 0,
  position INTEGER NOT NULL,
  completed_at INTEGER
)''');
    await db.execute('CREATE INDEX todos_day_idx ON todos (day)');
  }
}
