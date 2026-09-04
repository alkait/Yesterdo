@TestOn('mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:remind_me/data/app_database.dart';
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

void main() {
  setUpAll(sqfliteFfiInit);

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
        version: 3,
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
      'month_day': 1,
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
        version: 3,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(db.close);

    expect(await db.query('recurrences'), hasLength(1));
    expect(await db.query('settings'), isEmpty);
    await db.insert('settings', <String, Object?>{
      'key': 'theme',
      'value': 'forest',
    });
    expect(await db.query('settings'), hasLength(1));
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
        version: 3,
        onCreate: AppDatabase.createSchema,
      ),
    );
    addTearDown(fresh.close);

    final upgradedPath = p.join(directory.path, 'upgraded.db');
    var upgraded = await databaseFactoryFfi.openDatabase(
      upgradedPath,
      options: OpenDatabaseOptions(version: 1, onCreate: createVersionOne),
    );
    await upgraded.close();
    upgraded = await databaseFactoryFfi.openDatabase(
      upgradedPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: AppDatabase.createSchema,
        onUpgrade: AppDatabase.upgradeSchema,
      ),
    );
    addTearDown(upgraded.close);

    expect(await columnsOf(upgraded, 'todos'), await columnsOf(fresh, 'todos'));
    expect(
      await columnsOf(upgraded, 'recurrences'),
      await columnsOf(fresh, 'recurrences'),
    );
    expect(
      await columnsOf(upgraded, 'settings'),
      await columnsOf(fresh, 'settings'),
    );
  });
}
