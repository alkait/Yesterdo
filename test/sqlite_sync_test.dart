@TestOn('mac-os')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/app_database.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/sqlite_todo_store.dart';
import 'package:remind_me/data/sync_record.dart';
import 'package:remind_me/sync/cloud_sync.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/memory_cloud.dart';

/// Two phones on one account, each with a SQLite file of its own.
class Phone {
  Phone(this.db, MemoryCloud cloud) : transport = MemoryCloudTransport(cloud) {
    store = SqliteTodoStore(db, clock: () => clock);
    sync = CloudSync(store, transport);
  }

  static Future<Phone> open(MemoryCloud cloud) async => Phone(
    await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      // Two phones are two files: without this, a second open of the
      // in-memory path hands back the first.
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: AppDatabase.createSchema,
        singleInstance: false,
      ),
    ),
    cloud,
  );

  final Database db;
  final MemoryCloudTransport transport;
  late final SqliteTodoStore store;
  late final CloudSync sync;
  DateTime clock = DateTime(2026, 10, 8, 9);

  void later([Duration by = const Duration(minutes: 1)]) =>
      clock = clock.add(by);

  Future<List<String>> titlesOn(int day) async =>
      (await store.todosOn(day)).map((todo) => todo.title).toList();

  Future<Set<String>> get logged async => {
    for (final row in await db.query('sync_changes')) row['uid']! as String,
  };
}

void main() {
  setUpAll(sqfliteFfiInit);

  final day = DateTime(2026, 10, 8).epochDay;
  late MemoryCloud cloud;
  late Phone a;
  late Phone b;

  setUp(() async {
    cloud = MemoryCloud();
    a = await Phone.open(cloud);
    b = await Phone.open(cloud);
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('every write is logged, and a send clears the log', () async {
    final todo = await a.store.insert(day: day, title: 'Buy milk');
    expect(await a.logged, {todo.uid});
    await a.sync.refresh();
    expect(await a.logged, isEmpty);

    await a.store.save(todo.renamed('Buy oat milk'));
    expect(await a.logged, {todo.uid});
    await a.store.remove(day: day, todo: todo);
    final row = (await a.db.query('sync_changes')).single;
    expect(row['deleted'], 1);
    await a.sync.refresh();
    expect(await a.logged, isEmpty);
    expect(cloud.records, isEmpty);
  });

  test('a write that lands during a send stays logged', () async {
    final todo = await a.store.insert(day: day, title: 'Buy milk');
    final pending = await a.store.pendingChanges();
    a.later();
    await a.store.save(todo.renamed('Buy oat milk'));
    await a.store.clearPending(pending);
    expect(await a.logged, {todo.uid});
  });

  test('a task crosses between two phones and keeps one uid', () async {
    final written = await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    await b.sync.refresh();

    final onB = (await b.store.todosOn(day)).single;
    expect(onB.title, 'Buy milk');
    expect(onB.uid, written.uid);
    expect(await b.logged, isEmpty);

    b.later();
    await b.store.save(onB.renamed('Buy oat milk'));
    await b.sync.refresh();
    await a.sync.refresh();
    expect(await a.titlesOn(day), ['Buy oat milk']);
    expect((await a.store.todosOn(day)).single.id, written.id);
  });

  test('the latest write wins and a removal beats an edit', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.store.insert(day: day, title: 'Call mum');
    await a.sync.refresh();
    await b.sync.refresh();

    final onA = await a.store.todosOn(day);
    final onB = await b.store.todosOn(day);
    a.later(const Duration(minutes: 1));
    b.later(const Duration(minutes: 5));
    await a.store.save(
      onA.firstWhere((t) => t.title == 'Buy milk').renamed('Milk'),
    );
    await b.store.save(
      onB.firstWhere((t) => t.title == 'Buy milk').renamed('Oat milk'),
    );
    await a.store.remove(
      day: day,
      todo: onA.firstWhere((t) => t.title == 'Call mum'),
    );
    await b.store.save(
      onB.firstWhere((t) => t.title == 'Call mum').renamed('Call dad'),
    );

    await a.sync.refresh();
    await b.sync.refresh();
    await a.sync.refresh();

    expect(await a.titlesOn(day), ['Oat milk']);
    expect(await b.titlesOn(day), ['Oat milk']);
  });

  test('a rule crosses, and a showing acted on by both is one row', () async {
    await a.store.insertSeries(
      day: day,
      title: 'Stretch',
      rule: RepeatRule.daily(day),
    );
    await a.sync.refresh();
    await b.sync.refresh();
    expect(await b.titlesOn(day + 4), ['Stretch']);

    final onA = (await a.store.todosOn(day + 1)).single;
    final onB = (await b.store.todosOn(day + 1)).single;
    a.later();
    b.later(const Duration(minutes: 2));
    await a.store.save(
      (await a.store.materialize(day: day + 1, todo: onA)).toggled(1),
    );
    await b.store.save(
      (await b.store.materialize(day: day + 1, todo: onB)).withPinned(true),
    );
    await a.sync.refresh();
    await b.sync.refresh();
    await a.sync.refresh();

    final rowsA = await a.store.storedTodosOn(day + 1);
    expect(rowsA, hasLength(1));
    expect(rowsA.single.pinned, isTrue);
    expect(rowsA.single.done, isFalse);
    expect(
      rowsA.single.uid,
      occurrenceUid(rowsA.single.recurrenceUid!, day + 1),
    );
    expect(await b.store.storedTodosOn(day + 1), hasLength(1));
  });

  test('removing a series takes its showings off the other phone', () async {
    final id = await a.store.insertSeries(
      day: day,
      title: 'Stretch',
      rule: RepeatRule.daily(day),
    );
    final onA = (await a.store.todosOn(day)).single;
    await a.store.save(
      (await a.store.materialize(day: day, todo: onA)).toggled(1),
    );
    await a.sync.refresh();
    await b.sync.refresh();
    expect(await b.store.storedTodosOn(day), hasLength(1));

    await a.store.removeSeries(id);
    await a.sync.refresh();
    await b.sync.refresh();
    expect(await b.titlesOn(day), isEmpty);
    expect(await b.store.storedTodosOn(day), isEmpty);
    expect(await b.db.query('recurrences'), isEmpty);
  });

  test(
    'cutting a series short crosses as the rule and the rows gone',
    () async {
      final id = await a.store.insertSeries(
        day: day,
        title: 'Stretch',
        rule: RepeatRule.daily(day),
      );
      await a.sync.refresh();
      await b.sync.refresh();
      final onB = (await b.store.todosOn(day + 3)).single;
      await b.store.save(
        (await b.store.materialize(day: day + 3, todo: onB)).toggled(1),
      );
      await b.sync.refresh();
      await a.sync.refresh();
      expect(await a.store.storedTodosOn(day + 3), hasLength(1));

      a.later();
      await a.store.endSeriesFrom(recurrenceId: id, day: day + 2);
      await a.sync.refresh();
      await b.sync.refresh();
      expect(await b.titlesOn(day + 1), ['Stretch']);
      expect(await b.titlesOn(day + 3), isEmpty);
      expect(await b.store.storedTodosOn(day + 3), isEmpty);
    },
  );

  test('a showing whose rule is not held is left out', () async {
    await a.store.insertSeries(
      day: day,
      title: 'Stretch',
      rule: RepeatRule.daily(day),
    );
    final onA = (await a.store.todosOn(day)).single;
    await a.store.save(
      (await a.store.materialize(day: day, todo: onA)).toggled(1),
    );
    final pending = await a.store.pendingChanges();
    final showing = pending.changed.firstWhere((r) => r.kind == SyncKind.todo);

    expect(await b.store.applyRemote(SyncBatch(changed: [showing])), isFalse);
    expect(await b.store.storedTodosOn(day), isEmpty);
  });

  test('the token is kept between runs', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    // The pull comes before the push, so the token is from before it.
    expect(await a.store.syncToken(), '0');
    await b.sync.refresh();
    await b.sync.refresh();
    expect(b.transport.pulls, 2);
    expect(await b.store.syncToken(), '1');
    // What came back of its own is nothing new.
    await a.sync.refresh();
    expect(await a.store.syncToken(), '1');
    expect(await a.logged, isEmpty);
  });

  test('a wiped cloud puts everything back in the log', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.store.insertSeries(
      day: day,
      title: 'Stretch',
      rule: RepeatRule.daily(day),
    );
    await a.sync.refresh();
    expect(await a.logged, isEmpty);
    cloud.wipe();
    await a.sync.refresh();
    expect(cloud.records, hasLength(2));
    expect(await a.logged, isEmpty);
  });
}
