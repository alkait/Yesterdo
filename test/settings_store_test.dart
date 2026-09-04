@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/sqlite_settings_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late SqliteSettingsStore store;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: AppDatabase.createSchema,
      ),
    );
    store = SqliteSettingsStore(db);
  });

  tearDown(() => db.close());

  test('a setting never written reads as nothing', () async {
    expect(await store.read('theme'), isNull);
  });

  test('a written setting reads back and a rewrite replaces it', () async {
    await store.write('theme', 'ocean');
    expect(await store.read('theme'), 'ocean');

    await store.write('theme', 'forest');
    expect(await store.read('theme'), 'forest');
    expect(await db.query('settings'), hasLength(1));
  });
}
