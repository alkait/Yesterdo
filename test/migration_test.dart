@TestOn('mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/sqlite_todo_store.dart';
import 'package:remind_me/data/todo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The schema as version 1 shipped it, kept here so the upgrade is tested
/// against what is actually on people's phones.
Future<void> createVersionOne(Database db, int version) async {
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

/// The schema as version 2 shipped it: repeating tasks, nowhere for a
/// setting.
Future<void> createVersionTwo(Database db, int version) async {
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
  await db.execute(
    'CREATE UNIQUE INDEX todos_occurrence_idx ON todos (recurrence_id, day) '
    'WHERE recurrence_id IS NOT NULL',
  );
}

/// The schema as version 3 shipped it: one day of the month per rule, and
/// the settings table.
Future<void> createVersionThree(Database db, int version) async {
  await createVersionTwo(db, version);
  await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''');
}

/// The schema as version 4 shipped it: a set of days per rule, no due times.
Future<void> createVersionFour(Database db, int version) async {
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
  await db.execute(
    'CREATE UNIQUE INDEX todos_occurrence_idx ON todos (recurrence_id, day) '
    'WHERE recurrence_id IS NOT NULL',
  );
  await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)''');
}

/// The schema as version 5 shipped it: one reminder per task, as minutes
/// before its time, and no sound.
Future<void> createVersionFive(Database db, int version) async {
  await createVersionFour(db, version);
  for (final table in ['todos', 'recurrences']) {
    await db.execute('ALTER TABLE $table ADD COLUMN due_time INTEGER');
    await db.execute('ALTER TABLE $table ADD COLUMN reminder INTEGER');
  }
  await db.execute(
    'ALTER TABLE todos ADD COLUMN dismissed INTEGER NOT NULL DEFAULT 0',
  );
}

/// The schema as version 6 shipped it: reminder sets and sounds, plain
/// words only.
Future<void> createVersionSix(Database db, int version) async {
  await createVersionFive(db, version);
  for (final table in ['todos', 'recurrences']) {
    await db.execute('ALTER TABLE $table ADD COLUMN sound TEXT');
  }
}

/// The schema as version 7 shipped it: bodies, no custom repeats.
Future<void> createVersionSeven(Database db, int version) async {
  await createVersionSix(db, version);
  for (final table in ['todos', 'recurrences']) {
    await db.execute('ALTER TABLE $table ADD COLUMN body TEXT');
  }
}

/// The schema as version 8 shipped it: custom repeats, and every missed
/// showing of a rule raised.
Future<void> createVersionEight(Database db, int version) async {
  await createVersionSeven(db, version);
  await db.execute('ALTER TABLE recurrences ADD COLUMN days TEXT');
}

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'a version 8 rule keeps going and gains room for ignored days',
    () async {
      final directory = await Directory.systemTemp.createTemp('remind_me_test');
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'remind_me.db');

      var db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 8, onCreate: createVersionEight),
      );
      await db.insert('recurrences', <String, Object?>{
        'title': 'Stretch',
        'kind': 'daily',
        'weekdays': 0,
        'month_days': 0,
        'start_day': 20699,
        'position': 0,
      });
      await db.close();

      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: AppDatabase.createSchema,
          onUpgrade: AppDatabase.upgradeSchema,
        ),
      );
      addTearDown(db.close);

      final store = SqliteTodoStore(db);
      expect(
        await store.ignoredMissed(),
        isEmpty,
        reason: 'nothing ignored yet',
      );
      final rule = Recurrence.fromRow((await db.query('recurrences')).single);
      expect(rule.rule.kind, RepeatKind.daily);
      await store.ignoreMissed(recurrenceId: rule.id, day: 20702);
      expect(await store.ignoredMissed(), {rule.id: 20702});
    },
  );

  test('a version 7 rule keeps going and gains room for chosen days', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'remind_me.db');

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 7, onCreate: createVersionSeven),
    );
    await db.insert('recurrences', <String, Object?>{
      'title': 'Take the pills',
      'kind': 'daily',
      'weekdays': 0,
      'month_days': 0,
      'start_day': 20699,
      'position': 0,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    final rule = Recurrence.fromRow((await db.query('recurrences')).single);
    expect(rule.rule.kind, RepeatKind.daily);
    expect(rule.rule.days, isEmpty);
    await db.update('recurrences', <String, Object?>{'days': '20700,20703'});
    final custom = Recurrence.fromRow((await db.query('recurrences')).single);
    expect(custom.rule.days, {20700, 20703});
  });

  test('a version 6 task keeps its plain words and gains a body', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'remind_me.db');

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 6, onCreate: createVersionSix),
    );
    await db.insert('todos', <String, Object?>{
      'day': 20699,
      'title': 'Buy milk\nand bread',
      'done': 0,
      'position': 0,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    final row = (await db.query('todos')).single;
    expect(row['title'], 'Buy milk\nand bread');
    expect(row['body'], isNull, reason: 'read as plain words until rewritten');
    final todo = Todo.fromRow(row);
    expect(todo.body.blocks, hasLength(2));
    expect(todo.title, 'Buy milk\nand bread');

    await db.update('todos', Todo.bodyColumns(todo.body));
    expect((await db.query('todos')).single['body'], isNotNull);
    expect((await db.query('recurrences')), isEmpty);
    await db.insert('recurrences', <String, Object?>{
      'title': 'x',
      'kind': 'daily',
      'weekdays': 0,
      'month_days': 0,
      'start_day': 20699,
      'position': 0,
      'body': '[]',
    });
  });

  test(
    'a version 5 reminder becomes a set of them, and gains a sound',
    () async {
      final directory = await Directory.systemTemp.createTemp('remind_me_test');
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'remind_me.db');

      var db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 5, onCreate: createVersionFive),
      );
      Map<String, Object?> task(String title, int? reminder) =>
          <String, Object?>{
            'day': 20699,
            'title': title,
            'done': 0,
            'position': 0,
            'due_time': 570,
            'reminder': reminder,
          };
      await db.insert('todos', task('At the time', 0));
      await db.insert('todos', task('Quarter hour', 15));
      await db.insert('todos', task('An hour', 60));
      await db.insert('todos', task('No reminder', null));
      await db.insert('recurrences', <String, Object?>{
        'title': 'Take the pills',
        'kind': 'daily',
        'weekdays': 0,
        'month_days': 0,
        'start_day': 20699,
        'position': 1,
        'due_time': 600,
        'reminder': 5,
      });
      await db.close();

      db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: AppDatabase.createSchema,
          onUpgrade: AppDatabase.upgradeSchema,
        ),
      );
      addTearDown(db.close);

      final rows = await db.query('todos', orderBy: 'id');
      expect(rows.map((row) => row['reminder']), [1, 4, 16, null]);
      expect(rows.map((row) => row['sound']), everyElement(isNull));
      final rule = (await db.query('recurrences')).single;
      expect(rule['reminder'], 2);
      expect(rule['sound'], isNull);

      await db.update('todos', <String, Object?>{'sound': 'bell'});
      expect((await db.query('todos')).first['sound'], 'bell');
    },
  );

  test('a version 4 database keeps everything and gains due times', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'remind_me.db');

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 4, onCreate: createVersionFour),
    );
    await db.insert('recurrences', <String, Object?>{
      'title': 'Take the pills',
      'kind': 'daily',
      'weekdays': 0,
      'month_days': 0,
      'start_day': 20699,
      'position': 0,
    });
    await db.insert('todos', <String, Object?>{
      'day': 20699,
      'title': 'Take the pills',
      'done': 1,
      'position': 0,
      'recurrence_id': 1,
      'hidden': 0,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    final todo = (await db.query('todos')).single;
    expect(todo['title'], 'Take the pills');
    expect(todo['due_time'], isNull, reason: 'an old task has no time');
    expect(todo['reminder'], isNull);
    expect(todo['dismissed'], 0);
    final rule = (await db.query('recurrences')).single;
    expect(rule['due_time'], isNull);
    expect(rule['reminder'], isNull);

    // And the new columns take values.
    await db.update('todos', <String, Object?>{
      'due_time': 570,
      'reminder': 15,
      'dismissed': 1,
    });
    await db.update('recurrences', <String, Object?>{'due_time': 570});
    expect((await db.query('todos')).single['due_time'], 570);
    expect((await db.query('recurrences')).single['due_time'], 570);
  });

  test('a version 1 database keeps its tasks and gains repeating ones and settings', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'remind_me.db');

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1, onCreate: createVersionOne),
    );
    await db.insert('todos', <String, Object?>{
      'day': 20699,
      'title': 'Buy milk',
      'done': 1,
      'position': 0,
      'completed_at': 1788460000000,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    final rows = await db.query('todos');
    expect(rows, hasLength(1), reason: 'the old task survives the upgrade');
    expect(rows.single['title'], 'Buy milk');
    expect(rows.single['done'], 1);
    expect(
      rows.single['recurrence_id'],
      isNull,
      reason: 'an old task repeats never',
    );
    expect(rows.single['hidden'], 0);

    // The new table is there and usable.
    await db.insert('recurrences', <String, Object?>{
      'title': 'Take the pills',
      'kind': 'daily',
      'weekdays': 0,
      'month_days': 0,
      'start_day': 20699,
      'position': 1,
    });
    expect(await db.query('recurrences'), hasLength(1));

    await db.insert('settings', <String, Object?>{
      'key': 'theme',
      'value': 'ocean',
    });
    expect(await db.query('settings'), hasLength(1));
  });

  test('a version 2 database keeps its rules and gains settings', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'remind_me.db');

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 2, onCreate: createVersionTwo),
    );
    await db.insert('recurrences', <String, Object?>{
      'title': 'Take the pills',
      'kind': 'daily',
      'weekdays': 0,
      'month_day': 1,
      'start_day': 20699,
      'position': 0,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    final rule = (await db.query('recurrences')).single;
    expect(rule['title'], 'Take the pills');
    expect(rule['month_days'], 1, reason: 'the 1st became bit 0');
    expect(await db.query('settings'), isEmpty);
    await db.insert('settings', <String, Object?>{
      'key': 'theme',
      'value': 'forest',
    });
    expect(await db.query('settings'), hasLength(1));
  });

  test('a version 3 rule on one day becomes a set of days', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));
    final path = p.join(directory.path, 'remind_me.db');

    var db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 3, onCreate: createVersionThree),
    );
    Map<String, Object?> rule(String title, int monthDay) => <String, Object?>{
      'title': title,
      'kind': 'monthly',
      'weekdays': 0,
      'month_day': monthDay,
      'start_day': 20699,
      'end_day': 20800,
      'position': 0,
    };
    await db.insert('recurrences', rule('Pay the rent', 1));
    await db.insert('recurrences', rule('Mid month', 15));
    await db.insert('recurrences', rule('Month end', 31));
    await db.insert('recurrences', rule('Nearly month end', 29));
    // A written-down occurrence keeps pointing at its rule.
    await db.insert('todos', <String, Object?>{
      'day': 20699,
      'title': 'Pay the rent',
      'done': 1,
      'position': 0,
      'recurrence_id': 1,
      'hidden': 0,
    });
    await db.close();

    db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    final rows = await db.query('recurrences', orderBy: 'id');
    expect(rows.map((row) => row['title']), [
      'Pay the rent',
      'Mid month',
      'Month end',
      'Nearly month end',
    ]);
    expect(rows[0]['month_days'], RepeatRule.monthDayBit(1));
    expect(rows[1]['month_days'], RepeatRule.monthDayBit(15));
    expect(
      rows[2]['month_days'],
      RepeatRule.lastDayOfMonthBit,
      reason: 'the 31st is no longer offered; the last day is what it meant',
    );
    expect(rows[3]['month_days'], RepeatRule.lastDayOfMonthBit);
    expect(rows[0]['id'], 1, reason: 'ids survive, so occurrences still point');
    expect(
      rows[0]['end_day'],
      20800,
      reason: 'every other column carries over',
    );

    // The old column is gone, and the index came back with the table.
    final columns = await db.rawQuery('PRAGMA table_info(recurrences)');
    expect(columns.map((c) => c['name']), isNot(contains('month_day')));
    final indexes = await db.rawQuery('PRAGMA index_list(recurrences)');
    expect(indexes.map((i) => i['name']), contains('recurrences_start_idx'));

    // And the rebuilt table still takes new rules.
    await db.insert('recurrences', <String, Object?>{
      'title': 'Team sync',
      'kind': 'weekly',
      'weekdays': 2,
      'month_days': 0,
      'start_day': 20699,
      'position': 4,
    });
    expect(await db.query('recurrences'), hasLength(5));
  });

  test('a fresh database and an upgraded one end up the same shape', () async {
    final directory = await Directory.systemTemp.createTemp('remind_me_test');
    addTearDown(() => directory.delete(recursive: true));

    Future<Set<String>> columnsOf(Database db, String table) async {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      return {for (final column in info) column['name']! as String};
    }

    final fresh = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'fresh.db'),
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: AppDatabase.createSchema,
      ),
    );
    addTearDown(fresh.close);

    // Every version that ever shipped, so no upgrade path is left untried.
    final shipped = <int, OnDatabaseCreateFn>{
      1: createVersionOne,
      2: createVersionTwo,
      3: createVersionThree,
      4: createVersionFour,
      5: createVersionFive,
      6: createVersionSix,
      7: createVersionSeven,
      8: createVersionEight,
    };
    for (final MapEntry(key: version, value: create) in shipped.entries) {
      final upgradedPath = p.join(directory.path, 'upgraded_$version.db');
      var upgraded = await databaseFactoryFfi.openDatabase(
        upgradedPath,
        options: OpenDatabaseOptions(version: version, onCreate: create),
      );
      await upgraded.close();
      upgraded = await databaseFactoryFfi.openDatabase(
        upgradedPath,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: AppDatabase.createSchema,
          onUpgrade: AppDatabase.upgradeSchema,
        ),
      );
      addTearDown(upgraded.close);

      for (final table in ['todos', 'recurrences', 'settings']) {
        expect(
          await columnsOf(upgraded, table),
          await columnsOf(fresh, table),
          reason: '$table from version $version',
        );
      }
    }
  });
}
