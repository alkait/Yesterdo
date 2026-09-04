import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite file. Nothing leaves the device.
abstract final class AppDatabase {
  static const _fileName = 'remind_me.db';
  static const _version = 3;

  static Future<Database> open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: createSchema,
      onUpgrade: upgradeSchema,
    );
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
  completed_at INTEGER,
  recurrence_id INTEGER,
  hidden INTEGER NOT NULL DEFAULT 0
)''');
    await db.execute('CREATE INDEX todos_day_idx ON todos (day)');
    await _createRecurrences(db);
    await _createSettings(db);
  }

  /// Version 1 knew nothing of repeating tasks. Version 2 had nowhere to keep
  /// a setting.
  static Future<void> upgradeSchema(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('ALTER TABLE todos ADD COLUMN recurrence_id INTEGER');
      await db.execute(
        'ALTER TABLE todos ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0',
      );
      await _createRecurrences(db);
    }
    if (from < 3) await _createSettings(db);
  }

  static Future<void> _createSettings(Database db) => db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''');

  static Future<void> _createRecurrences(Database db) async {
    await db.execute('''
CREATE TABLE recurrences (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  kind TEXT NOT NULL,
  weekdays INTEGER NOT NULL DEFAULT 0,
  month_day INTEGER NOT NULL DEFAULT 1,
  start_day INTEGER NOT NULL,
  end_day INTEGER,
  position INTEGER NOT NULL
)''');
    await db.execute(
      'CREATE INDEX recurrences_start_idx ON recurrences (start_day)',
    );
    // A rule writes down at most one occurrence per day.
    await db.execute(
      'CREATE UNIQUE INDEX todos_occurrence_idx ON todos (recurrence_id, day) '
      'WHERE recurrence_id IS NOT NULL',
    );
  }
}
