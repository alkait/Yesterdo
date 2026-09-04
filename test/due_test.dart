import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/reminders/planned_reminder.dart';

void main() {
  group('time labels', () {
    test('read as a clock face', () {
      expect(timeLabel(0), '12:00 AM');
      expect(timeLabel(9 * 60 + 5), '9:05 AM');
      expect(timeLabel(12 * 60), '12:00 PM');
      expect(timeLabel(14 * 60 + 30), '2:30 PM');
      expect(timeLabel(23 * 60 + 59), '11:59 PM');
    });

    test('keep a 24-hour clock when asked', () {
      expect(timeLabel(0, twentyFourHour: true), '00:00');
      expect(timeLabel(9 * 60 + 5, twentyFourHour: true), '09:05');
      expect(timeLabel(14 * 60 + 30, twentyFourHour: true), '14:30');
    });
  });

  group('a due time', () {
    const due = Due(minute: 9 * 60 + 30, reminder: 15);
    final day = DateTime(2026, 9, 4).epochDay;

    test('falls at its minute on the day, in local time', () {
      expect(due.instantOn(day), DateTime(2026, 9, 4, 9, 30));
    });

    test('reminds ahead of itself, or not at all', () {
      expect(due.reminderInstantOn(day), DateTime(2026, 9, 4, 9, 15));
      expect(const Due(minute: 570).reminderInstantOn(day), isNull);
    });

    test('names its reminder', () {
      expect(Due.reminderLabel(null), 'No reminder');
      expect(Due.reminderLabel(0), 'At the time');
      expect(Due.reminderLabel(15), '15 minutes before');
      expect(Due.reminderLabel(60), '1 hour before');
    });

    test('snoozes on from now, or from itself when later', () {
      expect(due.snoozed(from: 10 * 60).minute, 10 * 60 + 10);
      expect(due.snoozed(from: 9 * 60).minute, 9 * 60 + 40);
      expect(due.snoozed().minute, 9 * 60 + 40);
    });

    test('a snooze speaks up at the new time and never leaves the day', () {
      expect(due.snoozed().reminder, 0);
      expect(
        const Due(minute: 23 * 60 + 55).snoozed().minute,
        Due.minutesPerDay - 1,
      );
    });

    test('round trips through its columns', () {
      expect(Due.fromRow(due.toRow()), due);
      expect(Due.fromRow(Due.emptyRow), isNull);
      expect(Due.fromRow(const <String, Object?>{}), isNull);
    });
  });

  group('a planned reminder', () {
    test('carries its task in the payload and reads it back', () {
      final reminder = PlannedReminder(
        day: 20699,
        key: 'r3',
        title: 'Take the pills',
        dueLabel: 'Due 9:30 AM',
        fireAt: DateTime(2026, 9, 4, 9, 15),
      );
      expect(PlannedReminder.parsePayload(reminder.payload), (20699, 'r3'));
      expect(PlannedReminder.parsePayload(null), isNull);
      expect(PlannedReminder.parsePayload('nonsense'), isNull);
      expect(PlannedReminder.parsePayload('x:t1'), isNull);
    });

    test('ids tell one day and task from another', () {
      PlannedReminder plan(int day, String key) => PlannedReminder(
        day: day,
        key: key,
        title: '',
        dueLabel: '',
        fireAt: DateTime(2026),
      );
      expect(plan(1, 't1').id, isNot(plan(2, 't1').id));
      expect(plan(1, 't1').id, isNot(plan(1, 't2').id));
      expect(plan(1, 't1').id, plan(1, 't1').id);
      expect(plan(1, 't1').id, isNonNegative);
    });
  });
}
