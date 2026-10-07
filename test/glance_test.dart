import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/glance/glance.dart';
import 'package:remind_me/glance/glance_planner.dart';
import 'package:remind_me/glance/glance_sync.dart';

import 'support/memory_device_bridge.dart';
import 'support/memory_todo_store.dart';

void main() {
  final today = DateTime(2026, 9, 4).epochDay;
  final nine = DateTime(2026, 9, 4, 9, 0);
  late MemoryTodoStore store;
  late GlancePlanner planner;

  setUp(() {
    store = MemoryTodoStore();
    planner = GlancePlanner(store);
  });

  test('a task with a time carries when it calls and when it is due', () async {
    await store.insert(
      day: today,
      title: 'Call Sam\nabout the invoice',
      due: const Due(minute: 14 * 60 + 30, reminders: {15}),
    );
    final tasks = await planner.plan(now: nine);
    expect(tasks, hasLength(1));
    expect(tasks.single.key, 't1');
    expect(tasks.single.title, 'Call Sam', reason: 'the first line only');
    expect(tasks.single.day, today);
    expect(tasks.single.payload, '$today:t1');
    expect(
      tasks.single.dueAt,
      DateTime(2026, 9, 4, 14, 30).millisecondsSinceEpoch,
    );
    expect(
      tasks.single.callsAt,
      DateTime(2026, 9, 4, 14, 15).millisecondsSinceEpoch,
      reason: 'its earliest reminder on the day, as a card would',
    );
  });

  test('a task with no time is no use to a widget', () async {
    await store.insert(day: today, title: 'Buy milk');
    expect(await planner.plan(now: nine), isEmpty);
  });

  test('a done or waved-away task never crosses', () async {
    final done = await store.insert(
      day: today,
      title: 'Done',
      due: const Due(minute: 8 * 60),
    );
    await store.save(done.toggled(nine.millisecondsSinceEpoch));
    final waved = await store.insert(
      day: today,
      title: 'Waved',
      due: const Due(minute: 8 * 60),
    );
    await store.save(waved.dismiss());

    expect(await planner.plan(now: nine), isEmpty);
  });

  test('a task left calling on an earlier day is still carried', () async {
    await store.insert(
      day: today - 1,
      title: 'Yesterday',
      due: const Due(minute: 9 * 60),
    );
    await store.insert(
      day: today - GlancePlanner.daysBehind,
      title: 'Weeks ago',
      due: const Due(minute: 9 * 60),
    );
    await store.insert(
      day: today - GlancePlanner.daysBehind - 1,
      title: 'Older than the backlog',
      due: const Due(minute: 9 * 60),
    );

    final titles = [
      for (final task in await planner.plan(now: nine)) task.title,
    ];
    expect(titles, containsAll(<String>['Yesterday', 'Weeks ago']));
    expect(titles, isNot(contains('Older than the backlog')));
  });

  test('tomorrow rides along, so midnight needs no app', () async {
    await store.insert(
      day: today + 1,
      title: 'Tomorrow',
      due: const Due(minute: 9 * 60),
    );
    await store.insert(
      day: today + 2,
      title: 'Later',
      due: const Due(minute: 9 * 60),
    );
    final titles = [
      for (final task in await planner.plan(now: nine)) task.title,
    ];
    expect(titles, ['Tomorrow']);
  });

  test('a repeating task is carried on every day it shows', () async {
    await store.insertSeries(
      day: today,
      title: 'Stretch',
      rule: RepeatRule(kind: RepeatKind.daily, startDay: today),
      due: const Due(minute: 7 * 60),
    );
    final tasks = await planner.plan(now: nine);
    expect(tasks.map((task) => task.title), ['Stretch', 'Stretch']);
    expect(
      tasks.map((task) => task.key).toSet(),
      hasLength(1),
      reason: 'the same rule, on two days',
    );
    expect(tasks.map((task) => task.day), [
      today + 1,
      today,
    ], reason: 'newest first');
  });

  test('a missed showing that was let go is not raised again', () async {
    await store.insertSeries(
      day: today - 3,
      title: 'Stretch',
      rule: RepeatRule(kind: RepeatKind.daily, startDay: today - 3),
      due: const Due(minute: 7 * 60),
    );
    final before = await planner.plan(now: nine);
    expect(before.where((task) => task.day < today), isNotEmpty);

    await store.ignoreMissed(recurrenceId: 1, day: today - 1);
    final after = await planner.plan(now: nine);
    expect(
      after.where((task) => task.day < today),
      isEmpty,
      reason: 'left where they are, and passed over',
    );
    expect(after.where((task) => task.day >= today), isNotEmpty);
  });

  test('no more is carried than the widgets can hold', () async {
    for (var index = 0; index < GlancePlanner.cap + 10; index++) {
      await store.insert(
        day: today,
        title: 'Task $index',
        due: const Due(minute: 9 * 60),
      );
    }
    expect(await planner.plan(now: nine), hasLength(GlancePlanner.cap));
  });

  test('the sync hands the widgets the whole thing, with the accent', () async {
    await store.insert(
      day: today,
      title: 'Call Sam',
      due: const Due(minute: 14 * 60 + 30),
    );
    final device = MemoryDeviceBridge();
    await GlanceSync(planner, device, AppThemeChoice.ocean).refresh(now: nine);

    expect(device.glances, hasLength(1));
    final glance = jsonDecode(device.glances.single) as Map<String, Object?>;
    expect(glance['accentLight'], '#1F5FBF');
    expect(glance['accentDark'], isA<String>());
    final tasks = glance['tasks']! as List<Object?>;
    expect(tasks, hasLength(1));
    expect((tasks.single! as Map<String, Object?>)['title'], 'Call Sam');
  });

  test('pinned tasks of today and tomorrow cross, time or no time', () async {
    final plain = await store.insert(day: today, title: 'Plain');
    await store.save(plain.withPinned(true));
    final timed = await store.insert(
      day: today + 1,
      title: 'Timed',
      due: const Due(minute: 9 * 60),
    );
    await store.save(timed.withPinned(true));
    final later = await store.insert(day: today + 2, title: 'Later');
    await store.save(later.withPinned(true));
    final earlier = await store.insert(day: today - 1, title: 'Earlier');
    await store.save(earlier.withPinned(true));
    await store.insert(day: today, title: 'Not pinned');

    final pinned = await planner.pinned(now: nine);
    expect(pinned.map((pin) => pin.title), ['Plain', 'Timed']);
    expect(pinned.first.payload, '$today:t1');
    expect(pinned.first.dueAt, isNull);
    expect(
      pinned.first.toJson()['dayAt'],
      DateTime(2026, 9, 4).millisecondsSinceEpoch,
    );
    expect(
      pinned.last.dueAt,
      DateTime(2026, 9, 5, 9, 0).millisecondsSinceEpoch,
    );
  });

  test('a pinned task that carries itself over is on tomorrow too', () async {
    final todo = await store.insert(
      day: today,
      title: 'Carries',
      carryOver: true,
    );
    await store.save(todo.withPinned(true));
    final plain = await store.insert(day: today, title: 'Plain');
    await store.save(plain.withPinned(true));

    final pinned = await planner.pinned(now: nine);
    expect(pinned.map((pin) => '${pin.day - today} ${pin.title}'), [
      '0 Plain',
      '0 Carries',
      '1 Carries',
    ]);
  });

  test('a pinned task marked done no longer crosses', () async {
    final todo = await store.insert(day: today, title: 'Plain');
    await store.save(todo.withPinned(true));
    expect(await planner.pinned(now: nine), hasLength(1));
    final pinned = (await store.todosOn(today)).single;
    await store.save(pinned.toggled(nine.millisecondsSinceEpoch));
    expect(await planner.pinned(now: nine), isEmpty);
  });

  test('the sync hands the pinned tasks over with the rest', () async {
    final todo = await store.insert(day: today, title: 'Plain');
    await store.save(todo.withPinned(true));
    final device = MemoryDeviceBridge();
    await GlanceSync(planner, device, AppThemeChoice.ocean).refresh(now: nine);
    final glance = jsonDecode(device.glances.single) as Map<String, Object?>;
    final pinned = glance['pinned']! as List<Object?>;
    expect((pinned.single! as Map<String, Object?>)['title'], 'Plain');
  });

  test('the accent is written as a plain six-digit colour', () {
    expect(
      Glance(tasks: const [], choice: AppThemeChoice.ink).encode(),
      contains('"accentLight":"#000000"'),
    );
  });
}
