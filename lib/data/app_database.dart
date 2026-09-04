import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the on-device SQLite file. Nothing leaves the device.
abstract final class AppDatabase {
  static const _fileName = 'remind_me.db';
  static const _version = 7;

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
  hidden INTEGER NOT NULL DEFAULT 0,
  due_time INTEGER,
  reminder INTEGER,
  sound TEXT,
  dismissed INTEGER NOT NULL DEFAULT 0,
  body TEXT
)''');
    await db.execute('CREATE INDEX todos_day_idx ON todos (day)');
    await _createRecurrences(db);
    await _createOccurrenceIndex(db);
    await _createSettings(db);
  }

  /// Version 1 knew nothing of repeating tasks. Version 2 had nowhere to keep
  /// a setting. Version 3 held one day of the month per rule. Version 4 had
  /// no due times. Version 5 held one reminder per task and no sound.
  /// Version 6 held plain words only.
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
    // Every path above that touches `recurrences` makes it afresh, in
    // today's shape, so only a version 4 table still needs its due columns.
    if (from < 5) await _addDueTimes(db, recurrencesToo: from == 4);
    if (from == 5) await _widenReminders(db);
    // As above: a `recurrences` table made afresh already has its body.
    if (from < 7) await _addBodies(db, recurrencesToo: from >= 4);
  }

  /// Version 6 held plain words only. The body column holds them styled;
  /// a row without one is read as its plain title, so nothing is rewritten.
  static Future<void> _addBodies(
    Database db, {
    required bool recurrencesToo,
  }) async {
    await db.execute('ALTER TABLE todos ADD COLUMN body TEXT');
    if (!recurrencesToo) return;
    await db.execute('ALTER TABLE recurrences ADD COLUMN body TEXT');
  }

  /// Version 5 kept a single reminder as minutes before the time. Now the
  /// column is a set, a bit per choice, and a sound sits beside it.
  static Future<void> _widenReminders(Database db) async {
    for (final table in ['todos', 'recurrences']) {
      await db.execute('ALTER TABLE $table ADD COLUMN sound TEXT');
      await db.execute('''
UPDATE $table SET reminder = CASE reminder
  WHEN 0 THEN 1 WHEN 5 THEN 2 WHEN 15 THEN 4 WHEN 30 THEN 8 WHEN 60 THEN 16
  ELSE NULL END''');
    }
  }

  static Future<void> _addDueTimes(
    Database db, {
    required bool recurrencesToo,
  }) async {
    await db.execute('ALTER TABLE todos ADD COLUMN due_time INTEGER');
    await db.execute('ALTER TABLE todos ADD COLUMN reminder INTEGER');
    await db.execute('ALTER TABLE todos ADD COLUMN sound TEXT');
    await db.execute(
      'ALTER TABLE todos ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0',
    );
    if (!recurrencesToo) return;
    await db.execute('ALTER TABLE recurrences ADD COLUMN due_time INTEGER');
    await db.execute('ALTER TABLE recurrences ADD COLUMN reminder INTEGER');
    await db.execute('ALTER TABLE recurrences ADD COLUMN sound TEXT');
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
  position INTEGER NOT NULL,
  due_time INTEGER,
  reminder INTEGER,
  sound TEXT,
  body TEXT
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
