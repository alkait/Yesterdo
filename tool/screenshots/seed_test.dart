@TestOn('mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/rich/styled_text.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/data/sqlite_todo_store.dart';
import 'package:remind_me/data/todo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Writes the store screenshots are taken from, through the real store,
/// to the file named by SEED_DB. Run by tool/screenshots.sh, never by the
/// test suite: it lives outside test/.
void main() {
  setUpAll(sqfliteFfiInit);

  test('seed', () async {
    final path = Platform.environment['SEED_DB'];
    if (path == null) return;
    final file = File(path);
    if (file.existsSync()) file.deleteSync();

    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 13,
        onCreate: AppDatabase.createSchema,
      ),
    );
    final store = SqliteTodoStore(db);
    final now = DateTime.now();
    final today = now.epochDay;

    TaskBody checklist(String title, List<(String, bool)> items) => TaskBody([
      Block.paragraph(title),
      for (final (words, ticked) in items)
        Block(kind: BlockKind.check, content: StyledText(words), checked: ticked),
    ]);
    Due at(int hour, int minute) =>
        Due(minute: hour * 60 + minute, reminders: const {0});

    Future<void> finish(Todo todo) =>
        store.save(todo.toggled(now.millisecondsSinceEpoch));

    // Inserted from the foot up: each insert goes to the head of its day.
    await finish(await store.insert(day: today, title: 'Read 20 pages'));
    await finish(
      await store.insert(day: today, title: 'Pay the electricity bill'),
    );
    await store.insert(
      day: today,
      body: TaskBody([
        Block.paragraph('Plan the weekend in the mountains'),
        Block.paragraph('Leave Friday after lunch, back Sunday evening.'),
        Block(kind: BlockKind.check, content: StyledText('Book the cabin')),
        Block(kind: BlockKind.check, content: StyledText('Check the forecast')),
        Block(kind: BlockKind.check, content: StyledText('Pack the boots')),
      ]),
    );
    await store.insert(
      day: today,
      title: 'Book a dentist appointment',
      carryOver: true,
    );
    await store.insertSeries(
      day: today,
      title: 'Water the plants',
      rule: RepeatRule.weekly(today, RepeatRule.weekdayBit(now.weekday)),
    );
    await store.insert(
      day: today,
      body: checklist('Groceries', [
        ('Oat milk', false),
        ('Eggs', false),
        ('Basil', false),
        ('Sourdough', false),
        ('Lemons', true),
      ]),
      due: at(17, 30),
    );
    await store.insert(
      day: today,
      title: 'Send the invoice to Studio North',
      due: at(now.hour, 0),
    );
    await store.insert(
      day: today,
      title: 'Call Mum about Sunday lunch',
      due: at(19, 0),
      pinned: true,
    );
    final run = await store.insertSeries(
      day: today,
      title: 'Morning run, 5 km',
      rule: RepeatRule.daily(today),
      due: at(7, 0),
    );
    final showing = (await store.todosOn(today))
        .firstWhere((todo) => todo.recurrenceId == run);
    await finish(await store.materialize(day: today, todo: showing));

    await store.insert(day: today - 1, title: 'Return the library books');
    await store.insert(day: today - 1, title: 'Reply to Sara about the quote');
    await store.insert(day: today + 1, title: 'Team standup', due: at(9, 30));
    await store.insert(day: today + 1, title: 'Pick up the dry cleaning');

    await db.insert('settings', {'key': 'theme', 'value': 'ink'});
    await db.close();
  });
}
