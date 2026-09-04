@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/reminder_sound.dart';
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
        version: 5,
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

  group('a due time', () {
    const due = Due(
      minute: 9 * 60 + 30,
      reminders: {15, 60},
      sound: ReminderSound.bell,
    );

    test('is kept on a one-off', () async {
      await store.insert(day: day, title: 'Call Sam', due: due);
      final read = (await store.todosOn(day)).single;
      expect(read.due, due);
      expect(read.dismissed, isFalse);
    });

    test('is kept on a rule and carried by every showing', () async {
      await store.insertSeries(
        day: day,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
        due: due,
      );
      expect((await store.todosOn(day)).single.due, due);
      expect((await store.todosOn(day + 3)).single.due, due);
    });

    test('a snooze and a wave-away are written for the day alone', () async {
      await store.insertSeries(
        day: day,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
        due: due,
      );
      final projected = (await store.todosOn(day)).single;
      final written = await store.materialize(day: day, todo: projected);
      await store.save(written.snoozed(nowMinute: 10 * 60));
      expect(
        (await store.todosOn(day)).single.due,
        const Due(
          minute: 10 * 60 + 10,
          reminders: {0},
          sound: ReminderSound.bell,
        ),
      );
      expect((await store.todosOn(day + 1)).single.due, due);

      await store.save(written.dismiss());
      expect((await store.todosOn(day)).single.dismissed, isTrue);
      expect((await store.todosOn(day + 1)).single.dismissed, isFalse);
    });

    test('rewriting the series gives every showing the new time', () async {
      final id = await startDaily();
      final projected = (await store.todosOn(day)).single;
      final written = await store.materialize(day: day, todo: projected);
      await store.save(written.dismiss());

      await store.saveSeries(
        recurrenceId: id,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
        due: due,
      );
      final today = (await store.todosOn(day)).single;
      expect(today.due, due);
      expect(today.dismissed, isFalse, reason: 'a new time is a new call');
      expect((await store.todosOn(day + 1)).single.due, due);

      await store.saveSeries(
        recurrenceId: id,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
      );
      expect((await store.todosOn(day)).single.due, isNull);
    });

    test('brings a task whose time has come to the top', () async {
      await store.insert(day: day, title: 'Buy milk');
      await store.insert(day: day, title: 'Call Sam', due: due);
      expect(await titlesOn(day), ['Buy milk', 'Call Sam']);
      final ten = DateTime(2026, 9, 4, 10);
      final atTen = await store.todosOn(day, now: ten);
      expect(atTen.map((t) => t.title), ['Call Sam', 'Buy milk']);
    });
  });

  group('not today', () {
    test('a one-off changes day and joins the end of that day', () async {
      await store.insert(day: day + 3, title: 'Already there');
      final milk = await store.insert(
        day: day,
        title: 'Buy milk',
        due: const Due(minute: 600, reminders: {5}),
      );
      await store.save(milk.dismiss());
      await store.moveToDay(fromDay: day, toDay: day + 3, todo: milk);

      expect(await titlesOn(day), isEmpty);
      final moved = await store.todosOn(day + 3);
      expect(moved.map((t) => t.title), ['Already there', 'Buy milk']);
      expect(moved.last.id, milk.id, reason: 'the same row, moved');
      expect(moved.last.due, milk.due, reason: 'the time comes along');
      expect(moved.last.dismissed, isFalse, reason: 'a new day is a new call');
    });

    test('a showing of a rule is hidden here and copied there', () async {
      await store.insertSeries(
        day: day,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
        due: const Due(minute: 600),
      );
      final showing = (await store.todosOn(day)).single;
      await store.moveToDay(fromDay: day, toDay: day + 2, todo: showing);

      expect(await titlesOn(day), isEmpty);
      expect(await titlesOn(day + 1), ['Take the pills'], reason: 'the rule');
      final there = await store.todosOn(day + 2);
      expect(there, hasLength(2), reason: 'the rule and the copy');
      expect(there.where((t) => t.repeats), hasLength(1));
      final copy = there.singleWhere((t) => !t.repeats);
      expect(copy.due, const Due(minute: 600));
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
