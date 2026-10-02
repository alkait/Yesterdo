@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/reminder_sound.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/data/rich/task_body.dart';
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
      await store.insert(day: day, title: 'Call Sam', due: due);
      await store.insert(day: day, title: 'Buy milk');
      expect(await titlesOn(day), [
        'Buy milk',
        'Call Sam',
      ], reason: 'newest on top');
      final ten = DateTime(2026, 9, 4, 10);
      final atTen = await store.todosOn(day, now: ten);
      expect(atTen.map((t) => t.title), ['Call Sam', 'Buy milk']);
    });
  });

  test('a custom rule keeps its days through the database', () async {
    await store.insertSeries(
      day: day,
      title: 'Dentist',
      rule: RepeatRule.custom({day + 2, day + 5}),
    );
    expect(await titlesOn(day), isEmpty);
    expect(await titlesOn(day + 2), ['Dentist']);
    expect(await titlesOn(day + 3), isEmpty);
    expect(await titlesOn(day + 5), ['Dentist']);
    final rule = (await store.recurrencesFor(day + 2)).single;
    expect(rule.rule.days, {day + 2, day + 5});

    await store.endSeriesFrom(recurrenceId: rule.id, day: day + 5);
    expect(await titlesOn(day + 5), isEmpty);
    expect(await titlesOn(day + 2), ['Dentist']);
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

    test('a task can be put on top of the day it goes to', () async {
      await store.insert(day: day + 3, title: 'Already there');
      final milk = await store.insert(day: day, title: 'Buy milk');
      await store.moveToDay(
        fromDay: day,
        toDay: day + 3,
        todo: milk,
        toTop: true,
      );
      expect(await titlesOn(day + 3), ['Buy milk', 'Already there']);

      await store.insertSeries(
        day: day,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
      );
      final showing = (await store.todosOn(day)).single;
      await store.moveToDay(
        fromDay: day,
        toDay: day + 3,
        todo: showing,
        toTop: true,
      );
      expect((await titlesOn(day + 3)).first, 'Take the pills');
    });

    test('a rule holds no tick, and a showing keeps its own', () async {
      Block item(String text, {bool checked = false}) => Block(
        kind: BlockKind.check,
        content: StyledText(text),
        checked: checked,
      );
      final id = await store.insertSeries(
        day: day,
        body: TaskBody([item('Milk', checked: true), item('Bread')]),
        rule: RepeatRule.daily(day),
      );
      final shown = (await store.todosOn(day)).single;
      expect(shown.body.checklistProgress, (0, 2), reason: 'a rule is open');

      // Ticked on the day, then the series is given new words, ticks and
      // all, the way the old editor could.
      final written = await store.materialize(day: day, todo: shown);
      await store.save(written.withBody(written.body.ticked(1)));
      await store.saveSeries(
        recurrenceId: id,
        body: TaskBody([
          item('Milk', checked: true),
          item('Bread'),
          item('Jam'),
        ]),
        rule: RepeatRule.daily(day),
      );

      final today = (await store.todosOn(day)).single.body;
      expect(today.blocks.map((b) => b.text), ['Milk', 'Jam', 'Bread']);
      expect(today.checklistProgress, (1, 3), reason: 'its own tick, kept');
      final tomorrow = (await store.todosOn(day + 1)).single.body;
      expect(tomorrow.blocks.map((b) => b.text), ['Milk', 'Bread', 'Jam']);
      expect(tomorrow.checklistProgress, (0, 3));
    });

    test('a pin is kept, and goes with a task to another day', () async {
      final milk = await store.insert(day: day, title: 'Buy milk');
      await store.save(milk.withPinned(true));
      final pinned = (await store.todosOn(day)).single;
      expect(pinned.pinned, isTrue);
      await store.moveToDay(fromDay: day, toDay: day + 3, todo: pinned);
      expect((await store.todosOn(day + 3)).single.pinned, isTrue);

      await store.insertSeries(
        day: day,
        title: 'Take the pills',
        rule: RepeatRule.daily(day),
      );
      final showing = await store.materialize(
        day: day,
        todo: (await store.todosOn(day)).single.withPinned(true),
      );
      await store.moveToDay(fromDay: day, toDay: day + 1, todo: showing);
      final there = await store.todosOn(day + 1);
      expect(there.singleWhere((t) => !t.repeats).pinned, isTrue);
      expect(there.singleWhere((t) => t.repeats).pinned, isFalse);
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
  test('a series is read back with its written-down showings by day', () async {
    final id = await startDaily();
    final showing = (await store.todosOn(day + 1)).single;
    final written = await store.materialize(day: day + 1, todo: showing);
    await store.save(written.toggled(1));

    final series = await store.readSeries(id);
    expect(series!.recurrence.title, 'Take the pills');
    expect(series.byDay.keys, [day + 1]);
    expect(series.byDay[day + 1]!.done, isTrue);
    expect(await store.readSeries(id + 1), isNull);
  });

  group('search', () {
    test('finds one-offs and rules alike, case aside, latest first', () async {
      await store.insert(day: day - 3, title: 'Book the DENTIST');
      await store.insert(day: day + 5, title: 'Dentist at ten');
      await store.insert(day: day, title: 'Buy milk');
      await store.insertSeries(
        day: day - 10,
        title: 'Floss like the dentist said',
        rule: RepeatRule.daily(day - 10),
      );

      final hits = await store.search('dentist', today: day);
      expect(
        [for (final hit in hits) '${hit.day - day}:${hit.todo.title}'],
        [
          '5:Dentist at ten',
          '0:Floss like the dentist said',
          '-3:Book the DENTIST',
        ],
      );
      expect(hits[1].rule, isNotNull);
    });

    test('a wildcard in the words is looked for as itself', () async {
      await store.insert(day: day, title: 'Give 100% today');
      await store.insert(day: day, title: 'Give 100 today');
      final hits = await store.search('100%', today: day);
      expect(hits.single.todo.title, 'Give 100% today');
    });

    test('a hidden showing and a written-down showing stay quiet', () async {
      final id = await startDaily();
      final showing = (await store.todosOn(day + 1)).single;
      await store.materialize(day: day + 1, todo: showing);
      await store.remove(
        day: day + 2,
        todo: (await store.todosOn(day + 2)).single,
      );
      final gone = await store.insert(day: day, title: 'Pills for the dog');
      await store.remove(day: day, todo: gone);

      final hits = await store.search('pills', today: day);
      expect(hits.single.todo.recurrenceId, id);
    });
  });
}
