import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/reminder_sound.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/reminders/reminder_planner.dart';
import 'package:remind_me/reminders/reminder_sync.dart';

import 'support/memory_device_bridge.dart';
import 'support/memory_reminder_scheduler.dart';
import 'support/memory_todo_store.dart';

void main() {
  final today = DateTime(2026, 9, 4).epochDay;
  final nine = DateTime(2026, 9, 4, 9, 0);
  late MemoryTodoStore store;
  late ReminderPlanner planner;

  setUp(() {
    store = MemoryTodoStore();
    planner = ReminderPlanner(store);
  });

  test('a task with a reminder is planned ahead of its time', () async {
    await store.insert(
      day: today,
      title: 'Call Sam\nabout the invoice',
      due: const Due(minute: 14 * 60 + 30, reminders: {15}),
    );
    final plan = await planner.plan(now: nine);
    expect(plan, hasLength(1));
    expect(plan.single.fireAt, DateTime(2026, 9, 4, 14, 15));
    expect(plan.single.title, 'Call Sam', reason: 'the first line only');
    expect(plan.single.dueLabel, 'Due 2:30 PM');
    expect(plan.single.day, today);
    expect(plan.single.key, 't1');
    expect(plan.single.before, 15);
    expect(plan.single.sound, ReminderSound.system);
  });

  test(
    'several reminders on one task each get their own notification',
    () async {
      await store.insert(
        day: today,
        title: 'Call Sam',
        due: const Due(
          minute: 14 * 60,
          reminders: {0, 30, Due.minutesPerDay},
          sound: ReminderSound.chime,
        ),
      );
      final plan = await planner.plan(now: nine);
      expect(plan.map((p) => p.fireAt), [
        DateTime(2026, 9, 4, 13, 30),
        DateTime(2026, 9, 4, 14, 0),
      ], reason: 'the day-ahead one was yesterday, so it is gone');
      expect(plan.map((p) => p.id).toSet(), hasLength(2));
      expect(plan.map((p) => p.sound).toSet(), {ReminderSound.chime});
    },
  );

  test('a day-ahead reminder for tomorrow fires today', () async {
    await store.insert(
      day: today + 1,
      title: 'Dentist',
      due: const Due(minute: 10 * 60, reminders: {Due.minutesPerDay}),
    );
    final plan = await planner.plan(now: nine);
    expect(plan.single.fireAt, DateTime(2026, 9, 4, 10, 0));
    expect(plan.single.day, today + 1, reason: 'but it points at tomorrow');
  });

  test('a time without a reminder plans nothing', () async {
    await store.insert(
      day: today,
      title: 'Buy milk',
      due: const Due(minute: 14 * 60 + 30),
    );
    expect(await planner.plan(now: nine), isEmpty);
  });

  test('done, dismissed and already-passed reminders are left out', () async {
    final done = await store.insert(
      day: today,
      title: 'Done',
      due: const Due(minute: 14 * 60, reminders: {0}),
    );
    await store.save(done.toggled(1));
    final waved = await store.insert(
      day: today,
      title: 'Waved away',
      due: const Due(minute: 15 * 60, reminders: {0}),
    );
    await store.save(waved.dismiss());
    await store.insert(
      day: today,
      title: 'Gone by',
      due: const Due(minute: 8 * 60, reminders: {0}),
    );
    expect(await planner.plan(now: nine), isEmpty);
  });

  test('a repeating task gets one a day across the window', () async {
    await store.insertSeries(
      day: today,
      title: 'Take the pills',
      rule: RepeatRule.daily(today),
      due: const Due(minute: 20 * 60, reminders: {5}),
    );
    final plan = await planner.plan(now: nine);
    expect(plan, hasLength(ReminderPlanner.daysAhead + 1));
    expect(plan.first.fireAt, DateTime(2026, 9, 4, 19, 55));
    expect(plan.first.key, 'r1');
    expect(plan.map((p) => p.day).toSet(), hasLength(plan.length));
  });

  test('the plan is in firing order and capped', () async {
    for (var each = 0; each < 5; each++) {
      await store.insertSeries(
        day: today,
        title: 'Rule $each',
        rule: RepeatRule.daily(today),
        due: Due(minute: 20 * 60 - each, reminders: {0}),
      );
    }
    final plan = await planner.plan(now: nine);
    expect(plan, hasLength(ReminderPlanner.cap));
    for (var each = 1; each < plan.length; each++) {
      expect(plan[each].fireAt.isBefore(plan[each - 1].fireAt), isFalse);
    }
  });

  test('a sync hands the whole plan over, replacing the last one', () async {
    final scheduler = MemoryReminderScheduler();
    final device = MemoryDeviceBridge();
    final sync = ReminderSync(planner, scheduler, store, device);
    final todo = await store.insert(
      day: today,
      title: 'Call Sam',
      due: const Due(minute: 14 * 60, reminders: {0}),
    );
    await sync.refresh(now: nine);
    expect(scheduler.pending, hasLength(1));

    await store.save(todo.toggled(1));
    await sync.refresh(now: nine);
    expect(scheduler.pending, isEmpty);
  });

  test('a sync numbers the icon with what is left to do today', () async {
    final device = MemoryDeviceBridge();
    final sync = ReminderSync(
      planner,
      MemoryReminderScheduler(),
      store,
      device,
    );
    final milk = await store.insert(day: today, title: 'Milk');
    await store.insert(day: today, title: 'Bread');
    await store.insert(day: today + 1, title: 'Tomorrow');
    await store.insertSeries(
      day: today,
      title: 'Stretch',
      rule: RepeatRule.daily(today),
    );
    await sync.refresh(now: nine);
    expect(device.badge, 3, reason: 'two rows and a rule, not tomorrow');

    await store.save(milk.toggled(1));
    await sync.refresh(now: nine);
    expect(device.badge, 2);
  });
}
