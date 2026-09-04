@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/sqlite_todo_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late SqliteTodoStore store;
  final day = DateTime(2026, 9, 4).epochDay;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: AppDatabase.createSchema,
      ),
    );
    store = SqliteTodoStore(db);
  });

  tearDown(() => db.close());

  Future<int> startDaily() async {
    await store.insertSeries(
      day: day,
      title: 'Take the pills',
      rule: RepeatRule.daily(day),
    );
    return (await store.todosOn(day)).single.recurrenceId!;
  }

  Future<List<String>> titlesOn(int on) async =>
      (await store.todosOn(on)).map((todo) => todo.title).toList();

  group('a monthly rule', () {
    test('lands on each chosen day and the last day of every month', () async {
      final january = DateTime(2026, 1, 15).epochDay;
      await store.insertSeries(
        day: january,
        title: 'Pay the rent',
        rule: RepeatRule.monthly(
          january,
          RepeatRule.monthDayBit(15) | RepeatRule.lastDayOfMonthBit,
        ),
      );

      expect(await titlesOn(january), ['Pay the rent']);
      expect(await titlesOn(DateTime(2026, 1, 31).epochDay), ['Pay the rent']);
      expect(await titlesOn(DateTime(2026, 2, 15).epochDay), ['Pay the rent']);
      expect(await titlesOn(DateTime(2026, 2, 28).epochDay), ['Pay the rent']);
      expect(await titlesOn(DateTime(2026, 3, 28).epochDay), isEmpty);
      expect(await titlesOn(DateTime(2026, 3, 31).epochDay), ['Pay the rent']);

      // The set survives a round trip through the table.
      final row = (await db.query('recurrences')).single;
      expect(
        row['month_days'],
        RepeatRule.monthDayBit(15) | RepeatRule.lastDayOfMonthBit,
      );
    });
  });

  group('ending a run', () {
    test('cutting later days keeps the earlier ones', () async {
      final id = await startDaily();
      await store.endSeriesFrom(recurrenceId: id, day: day + 3);

      expect(await titlesOn(day + 2), ['Take the pills']);
      expect(await titlesOn(day + 3), isEmpty);
      expect(await titlesOn(day + 40), isEmpty);
    });

    test('cutting at the start removes the rule outright', () async {
      final id = await startDaily();
      await store.endSeriesFrom(recurrenceId: id, day: day);

      expect(await db.query('recurrences'), isEmpty);
      expect(await titlesOn(day), isEmpty);
    });

    test('written-down days after the cut go with it', () async {
      final id = await startDaily();
      final later = (await store.todosOn(day + 5)).single;
      await store.materialize(day: day + 5, todo: later);
      expect(await db.query('todos'), hasLength(1));

      await store.endSeriesFrom(recurrenceId: id, day: day + 3);
      expect(await db.query('todos'), isEmpty);
    });
  });

  group('starting a run later', () {
    test('cutting earlier days keeps the later ones', () async {
      final id = await startDaily();
      await store.startSeriesAfter(recurrenceId: id, day: day + 2);

      expect(await titlesOn(day), isEmpty);
      expect(await titlesOn(day + 2), isEmpty);
      expect(await titlesOn(day + 3), ['Take the pills']);
    });

    test('cutting at or past the end removes the rule outright', () async {
      final id = await startDaily();
      await store.endSeriesFrom(recurrenceId: id, day: day + 3);
      await store.startSeriesAfter(recurrenceId: id, day: day + 2);

      expect(await db.query('recurrences'), isEmpty);
    });

    test('written-down days before the cut go with it', () async {
      final id = await startDaily();
      final early = (await store.todosOn(day)).single;
      await store.materialize(day: day, todo: early);
      expect(await db.query('todos'), hasLength(1));

      await store.startSeriesAfter(recurrenceId: id, day: day + 2);
      expect(await db.query('todos'), isEmpty);
    });
  });

  test('cutting both ends can leave a single day standing', () async {
    final id = await startDaily();
    await store.endSeriesFrom(recurrenceId: id, day: day + 3);
    await store.startSeriesAfter(recurrenceId: id, day: day + 1);

    expect(await titlesOn(day), isEmpty);
    expect(await titlesOn(day + 1), isEmpty);
    expect(await titlesOn(day + 2), ['Take the pills']);
    expect(await titlesOn(day + 3), isEmpty);
  });
}
