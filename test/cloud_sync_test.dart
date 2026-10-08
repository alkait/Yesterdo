import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/data/sync_record.dart';
import 'package:remind_me/data/todo.dart';
import 'package:remind_me/sync/cloud_sync.dart';

import 'support/memory_cloud.dart';
import 'support/memory_todo_store.dart';

/// Two devices on one iCloud account: each a store, a transport and the
/// sync between them, with a clock of its own that a test turns by hand.
class Device {
  Device(this.cloud, {DateTime? at})
    : clock = at ?? DateTime(2026, 10, 8, 9),
      transport = MemoryCloudTransport(cloud) {
    store = MemoryTodoStore(clock: () => clock);
    sync = CloudSync(store, transport)..onPulled = () => pulled++;
  }

  final MemoryCloud cloud;
  final MemoryCloudTransport transport;
  late final MemoryTodoStore store;
  late final CloudSync sync;
  DateTime clock;
  int pulled = 0;

  /// Time passes on this device.
  void later([Duration by = const Duration(minutes: 1)]) =>
      clock = clock.add(by);

  Future<List<String>> titlesOn(int day) async =>
      (await store.todosOn(day)).map((todo) => todo.title).toList();
}

void main() {
  final day = DateTime(2026, 10, 8).epochDay;
  late MemoryCloud cloud;
  late Device a;
  late Device b;

  setUp(() {
    cloud = MemoryCloud();
    a = Device(cloud);
    b = Device(cloud);
  });

  test('a task written on one device shows up on the other', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    await b.sync.refresh();

    expect(await b.titlesOn(day), ['Buy milk']);
    expect(b.pulled, 1);
    // Nothing of B's to send, and nothing more of A's.
    expect(b.transport.pushes, 0);
    expect(a.store.pendingUids, isEmpty);
  });

  test(
    'a second sync with nothing new pulls nothing and says nothing',
    () async {
      await a.store.insert(day: day, title: 'Buy milk');
      await a.sync.refresh();
      await b.sync.refresh();
      await b.sync.refresh();

      expect(b.pulled, 1);
      expect(b.transport.pushes, 0);
    },
  );

  test('without an iCloud account nothing is sent or asked for', () async {
    a.transport.signedIn = false;
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();

    expect(a.transport.pulls, 0);
    expect(a.transport.pushes, 0);
    expect(a.store.pendingUids, hasLength(1));
  });

  test(
    'an edit on either side reaches the other, and keeps the row one',
    () async {
      final written = await a.store.insert(day: day, title: 'Buy milk');
      await a.sync.refresh();
      await b.sync.refresh();

      final onB = (await b.store.todosOn(day)).single;
      b.later();
      await b.store.save(onB.renamed('Buy oat milk'));
      await b.sync.refresh();
      await a.sync.refresh();

      final onA = (await a.store.todosOn(day)).single;
      expect(onA.title, 'Buy oat milk');
      // The same row, under the id it had here.
      expect(onA.id, written.id);
      expect(onA.uid, written.uid);
    },
  );

  test('the latest write wins when both edit while apart', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    await b.sync.refresh();

    a.later(const Duration(minutes: 1));
    await a.store.save((await a.store.todosOn(day)).single.renamed('Milk, 2l'));
    b.later(const Duration(minutes: 5));
    await b.store.save((await b.store.todosOn(day)).single.renamed('Oat milk'));

    // A syncs first, B's later write still overrides it.
    await a.sync.refresh();
    await b.sync.refresh();
    await a.sync.refresh();

    expect(await a.titlesOn(day), ['Oat milk']);
    expect(await b.titlesOn(day), ['Oat milk']);
  });

  test('the earlier write loses even when it is sent last', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    await b.sync.refresh();

    a.later(const Duration(minutes: 5));
    await a.store.save((await a.store.todosOn(day)).single.renamed('Milk, 2l'));
    b.later(const Duration(minutes: 1));
    await b.store.save((await b.store.todosOn(day)).single.renamed('Oat milk'));

    await a.sync.refresh();
    // B pulls A's later write before pushing, so its own is let go.
    await b.sync.refresh();
    await a.sync.refresh();

    expect(await b.titlesOn(day), ['Milk, 2l']);
    expect(await a.titlesOn(day), ['Milk, 2l']);
  });

  test('a removal beats an edit, whichever side removed', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.store.insert(day: day, title: 'Call mum');
    await a.sync.refresh();
    await b.sync.refresh();

    // A removes the first and edits the second; B does the reverse.
    final onA = await a.store.todosOn(day);
    final onB = await b.store.todosOn(day);
    a.later();
    b.later(const Duration(minutes: 10));
    await a.store.remove(
      day: day,
      todo: onA.firstWhere((t) => t.title == 'Buy milk'),
    );
    await a.store.save(
      onA.firstWhere((t) => t.title == 'Call mum').renamed('Call dad'),
    );
    await b.store.save(
      onB.firstWhere((t) => t.title == 'Buy milk').renamed('Buy cream'),
    );
    await b.store.remove(
      day: day,
      todo: onB.firstWhere((t) => t.title == 'Call mum'),
    );

    await a.sync.refresh();
    await b.sync.refresh();
    await a.sync.refresh();

    expect(await a.titlesOn(day), isEmpty);
    expect(await b.titlesOn(day), isEmpty);
    expect(cloud.records, isEmpty);
  });

  test(
    'a repeating task crosses as its rule, and a showing acted on is one row',
    () async {
      await a.store.insertSeries(
        day: day,
        title: 'Stretch',
        rule: RepeatRule.daily(day),
        due: const Due(minute: 8 * 60),
      );
      await a.sync.refresh();
      await b.sync.refresh();

      expect(await b.titlesOn(day + 3), ['Stretch']);
      expect((await b.store.todosOn(day + 3)).single.due?.minute, 8 * 60);

      // Both devices tick the same showing while apart.
      final onA = (await a.store.todosOn(day + 1)).single;
      final onB = (await b.store.todosOn(day + 1)).single;
      a.later();
      b.later(const Duration(minutes: 2));
      final writtenA = await a.store.materialize(day: day + 1, todo: onA);
      await a.store.save(writtenA.toggled(a.clock.millisecondsSinceEpoch));
      final writtenB = await b.store.materialize(day: day + 1, todo: onB);
      await b.store.save(writtenB.withPinned(true));

      await a.sync.refresh();
      await b.sync.refresh();
      await a.sync.refresh();

      // One row for the day on each side, B's later write standing.
      final rowsA = await a.store.storedTodosOn(day + 1);
      final rowsB = await b.store.storedTodosOn(day + 1);
      expect(rowsA, hasLength(1));
      expect(rowsB, hasLength(1));
      expect(rowsA.single.pinned, isTrue);
      expect(rowsA.single.done, isFalse);
      expect(rowsA.single.uid, rowsB.single.uid);
      expect(rowsA.single.recurrenceId, isNotNull);
      // The other days are still the rule's.
      expect(await a.titlesOn(day + 2), ['Stretch']);
    },
  );

  test(
    'removing a series on one device takes it off the other, showings and all',
    () async {
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
      expect(await b.titlesOn(day), ['Stretch']);
      expect(await b.store.storedTodosOn(day), hasLength(1));

      await a.store.removeSeries(id);
      await a.sync.refresh();
      await b.sync.refresh();

      expect(await b.titlesOn(day), isEmpty);
      expect(await b.store.storedTodosOn(day), isEmpty);
      expect(cloud.records, isEmpty);
    },
  );

  test(
    'a series edit on one device rewrites the showings on the other',
    () async {
      final id = await a.store.insertSeries(
        day: day,
        title: 'Stretch',
        rule: RepeatRule.daily(day),
      );
      await a.sync.refresh();
      await b.sync.refresh();
      final onB = (await b.store.todosOn(day)).single;
      await b.store.save(
        (await b.store.materialize(day: day, todo: onB)).withPinned(true),
      );
      await b.sync.refresh();
      await a.sync.refresh();

      a.later();
      await a.store.saveSeries(
        recurrenceId: id,
        title: 'Stretch well',
        rule: RepeatRule.daily(day),
      );
      await a.sync.refresh();
      await b.sync.refresh();

      expect(await b.titlesOn(day), ['Stretch well']);
      expect(await b.titlesOn(day + 1), ['Stretch well']);
      expect((await b.store.todosOn(day)).single.pinned, isTrue);
    },
  );

  test('a move to another day follows', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    await b.sync.refresh();

    final onA = (await a.store.todosOn(day)).single;
    a.later();
    await a.store.moveToDay(fromDay: day, toDay: day + 2, todo: onA);
    await a.sync.refresh();
    await b.sync.refresh();

    expect(await b.titlesOn(day), isEmpty);
    expect(await b.titlesOn(day + 2), ['Buy milk']);
    expect(await b.store.storedTodosOn(day), isEmpty);
  });

  test('ignoring a rule\'s missed showings crosses with the rule', () async {
    final id = await a.store.insertSeries(
      day: day - 5,
      title: 'Stretch',
      rule: RepeatRule.daily(day - 5),
    );
    await a.sync.refresh();
    await b.sync.refresh();
    a.later();
    await a.store.ignoreMissed(recurrenceId: id, day: day - 1);
    await a.sync.refresh();
    await b.sync.refresh();

    final idOnB = (await b.store.todosOn(day)).single.recurrenceId!;
    expect(await b.store.ignoredMissed(), {idOnB: day - 1});
  });

  test('what each device had before syncing ends up on both', () async {
    await a.store.insert(day: day, title: 'From A');
    await b.store.insert(day: day, title: 'From B');
    await a.sync.refresh();
    await b.sync.refresh();
    await a.sync.refresh();

    expect(await a.titlesOn(day), containsAll(['From A', 'From B']));
    expect(await b.titlesOn(day), containsAll(['From A', 'From B']));
    expect((await a.store.todosOn(day)), hasLength(2));
  });

  test(
    'a push that fails is tried again next time, and nothing is lost',
    () async {
      await a.store.insert(day: day, title: 'Buy milk');
      a.transport.failNextPush = true;
      await a.sync.refresh();
      expect(a.sync.lastError, isNotNull);
      expect(a.store.pendingUids, hasLength(1));
      expect(cloud.records, isEmpty);

      await a.sync.refresh();
      expect(a.sync.lastError, isNull);
      expect(a.store.pendingUids, isEmpty);
      expect(cloud.records, hasLength(1));
    },
  );

  test('a cloud wiped from under the devices is filled again', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    cloud.wipe();
    await a.sync.refresh();

    expect(cloud.records, hasLength(1));
    await b.sync.refresh();
    expect(await b.titlesOn(day), ['Buy milk']);
  });

  test('a nudge during a run is answered by another run', () async {
    await a.store.insert(day: day, title: 'Buy milk');
    final first = a.sync.refresh();
    await a.store.insert(day: day, title: 'Call mum');
    a.sync.nudge();
    await first;
    // The second run is on its way; let it finish.
    await Future<void>.delayed(Duration.zero);
    await a.sync.refresh();

    expect(cloud.records, hasLength(2));
  });

  test('a write from another device is announced to the others', () async {
    b.transport.onChange(() => b.sync.nudge());
    await a.store.insert(day: day, title: 'Buy milk');
    await a.sync.refresh();
    await b.sync.refresh();

    expect(await b.titlesOn(day), ['Buy milk']);
  });

  test(
    'pictures are named by the record, so the device can carry them',
    () async {
      final body = TaskBody([
        Block.paragraph('Receipt'),
        Block.image('abc.jpg'),
      ]);
      await a.store.insert(day: day, body: body);
      final pending = await a.store.pendingChanges();
      expect(pending.changed.single.images, ['abc.jpg']);
      expect(pending.changed.single.toJson()['images'], ['abc.jpg']);
    },
  );

  test('a record survives the trip through JSON', () async {
    await a.store.insert(
      day: day,
      title: 'Buy milk',
      due: const Due(minute: 9 * 60),
    );
    final record = (await a.store.pendingChanges()).changed.single;
    final back = SyncRecord.fromJson(record.toJson());
    expect(back.uid, record.uid);
    expect(back.kind, SyncKind.todo);
    expect(back.updatedAt, record.updatedAt);
    expect(back.fields, record.fields);
    expect(Todo.fromRow({...back.fields, 'id': 1}).title, 'Buy milk');
  });
}
