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

  test('a task with a time carries its due moment', () async {
    await store.insert(
      day: today,
      title: 'Call Sam\nabout the invoice',
      due: const Due(minute: 14 * 60 + 30),
    );
    final tasks = await planner.plan(now: nine);
    expect(tasks, hasLength(1));
    expect(tasks.single.key, 't1');
    expect(tasks.single.title, 'Call Sam', reason: 'the first line only');
    expect(
      tasks.single.dueAt,
      DateTime(2026, 9, 4, 14, 30).millisecondsSinceEpoch,
    );
    expect(
      tasks.single.dayStart,
      DateTime(2026, 9, 4).millisecondsSinceEpoch,
    );
    expect(tasks.single.done, isFalse);
    expect(tasks.single.dismissed, isFalse);
  });

  test('a task with no time carries none', () async {
    await store.insert(day: today, title: 'Buy milk');
    final tasks = await planner.plan(now: nine);
    expect(tasks.single.dueAt, isNull);
  });

  test('tomorrow rides along, so midnight needs no app', () async {
    await store.insert(day: today, title: 'Today');
    await store.insert(day: today + 1, title: 'Tomorrow');
    await store.insert(day: today + 2, title: 'Later');
    final tasks = await planner.plan(now: nine);
    expect(tasks.map((task) => task.title), ['Today', 'Tomorrow']);
    expect(
      tasks.last.dayStart,
      DateTime(2026, 9, 5).millisecondsSinceEpoch,
    );
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
    expect(tasks.map((task) => task.key).toSet(), hasLength(1),
        reason: 'the same rule, on two days');
    expect(
      tasks.last.dueAt,
      DateTime(2026, 9, 5, 7, 0).millisecondsSinceEpoch,
    );
  });

  test('a done or waved-away task is carried, and says which', () async {
    final done = await store.insert(day: today, title: 'Done');
    await store.save(done.toggled(nine.millisecondsSinceEpoch));
    final waved = await store.insert(
      day: today,
      title: 'Waved',
      due: const Due(minute: 8 * 60),
    );
    await store.save(waved.dismiss());

    final tasks = await planner.plan(now: nine);
    final byTitle = {for (final task in tasks) task.title: task};
    expect(byTitle['Done']!.done, isTrue);
    expect(byTitle['Waved']!.dismissed, isTrue);
    expect(byTitle['Waved']!.done, isFalse);
  });

  test('a day hands over no more than it can draw', () async {
    for (var index = 0; index < GlancePlanner.perDay + 5; index++) {
      await store.insert(day: today, title: 'Task $index');
    }
    final tasks = await planner.plan(now: nine);
    expect(tasks, hasLength(GlancePlanner.perDay));
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
    final glance =
        jsonDecode(device.glances.single) as Map<String, Object?>;
    expect(glance['accentLight'], '#1F5FBF');
    expect(glance['accentDark'], isA<String>());
    final tasks = glance['tasks']! as List<Object?>;
    expect(tasks, hasLength(1));
    expect((tasks.single! as Map<String, Object?>)['title'], 'Call Sam');
  });

  test('the accent is written as a plain six-digit colour', () {
    expect(
      Glance(tasks: const [], choice: AppThemeChoice.ink).encode(),
      contains('"accentLight":"#000000"'),
    );
  });
}
