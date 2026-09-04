import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite file. Nothing leaves the device.
abstract final class AppDatabase {
  static const _fileName = 'remind_me.db';
  static const _version = 4;

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
    await _createOccurrenceIndex(db);
    await _createSettings(db);
  }

  /// Version 1 knew nothing of repeating tasks. Version 2 had nowhere to keep
  /// a setting. Version 3 held one day of the month per rule.
  static Future<void> upgradeSchema(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute('ALTER TABLE todos ADD COLUMN recurrence_id INTEGER');
      await db.execute(
        'ALTER TABLE todos ADD COLUMN hidden INTEGER NOT NULL DEFAULT 0',
      );
      // Made fresh in today's shape, so it needs no rebuilding below.
      await _createRecurrences(db);
      await _createOccurrenceIndex(db);
    } else if (from < 4) {
      await _moveToMonthDays(db);
    }
    if (from < 3) await _createSettings(db);
  }

  /// Turns the single `month_day` into the `month_days` set. A day every
  /// month has becomes its own bit; the 29th, 30th and 31st, which the
  /// chooser no longer offers, become the last day of the month, the closest
  /// thing to what they used to mean. SQLite cannot drop a column on every
  /// device this app runs on, so the table is rebuilt.
  static Future<void> _moveToMonthDays(Database db) async {
    // The index would follow the table under its old name, so it goes first
    // and comes back with the new table.
    await db.execute('DROP INDEX recurrences_start_idx');
    await db.execute('ALTER TABLE recurrences RENAME TO recurrences_old');
    await _createRecurrences(db);
    await db.execute('''
INSERT INTO recurrences
  (id, title, kind, weekdays, month_days, start_day, end_day, position)
SELECT id, title, kind, weekdays,
  CASE WHEN month_day BETWEEN 1 AND 28 THEN 1 << (month_day - 1)
       ELSE ${1 << 31} END,
  start_day, end_day, position
FROM recurrences_old''');
    await db.execute('DROP TABLE recurrences_old');
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
  month_days INTEGER NOT NULL DEFAULT 0,
  start_day INTEGER NOT NULL,
  end_day INTEGER,
  position INTEGER NOT NULL
)''');
    await db.execute(
      'CREATE INDEX recurrences_start_idx ON recurrences (start_day)',
    );
  }

  /// A rule writes down at most one occurrence per day.
  static Future<void> _createOccurrenceIndex(Database db) => db.execute(
    'CREATE UNIQUE INDEX todos_occurrence_idx ON todos (recurrence_id, day) '
    'WHERE recurrence_id IS NOT NULL',
  );
}
