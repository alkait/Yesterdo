import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/reminder_sound.dart';
import 'package:remind_me/reminders/local_reminder_scheduler.dart';
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
    const due = Due(
      minute: 9 * 60 + 30,
      reminders: {15, 0},
      sound: ReminderSound.chime,
    );
    final day = DateTime(2026, 9, 4).epochDay;

    test('falls at its minute on the day, in local time', () {
      expect(due.instantOn(day), DateTime(2026, 9, 4, 9, 30));
    });

    test('reminds ahead of itself, earliest first, or not at all', () {
      expect(due.reminderInstantsOn(day), [
        DateTime(2026, 9, 4, 9, 15),
        DateTime(2026, 9, 4, 9, 30),
      ]);
      expect(const Due(minute: 570).reminderInstantsOn(day), isEmpty);
      expect(const Due(minute: 570).hasReminder, isFalse);
    });

    test('names each reminder, the one at the time by the time', () {
      expect(due.reminderLabel(0), 'At 9:30 AM');
      expect(due.reminderLabel(0, twentyFourHour: true), 'At 09:30');
      expect(due.reminderLabel(15), '15 minutes before');
      expect(due.reminderLabel(60), '1 hour before');
      expect(due.reminderLabel(Due.minutesPerDay), '1 day before');
    });

    test('sums its reminders up in one line', () {
      Due with_(Set<int> reminders) => due.copyWith(reminders: reminders);
      expect(with_(const {}).remindersLabel(), 'No reminder');
      expect(with_(const {0}).remindersLabel(), 'At 9:30 AM');
      expect(with_(const {15}).remindersLabel(), '15 min before');
      expect(
        with_(const {Due.minutesPerDay, 0, 60, 5}).remindersLabel(),
        'At 9:30 AM, 5 min, 1 hr, 1 day before',
      );
    });

    test('snoozes on from now, or from itself when later', () {
      expect(due.snoozed(from: 10 * 60).minute, 10 * 60 + 10);
      expect(due.snoozed(from: 9 * 60).minute, 9 * 60 + 40);
      expect(due.snoozed().minute, 9 * 60 + 40);
    });

    test('a snooze speaks up at the new time, in the same voice', () {
      expect(due.snoozed().reminders, {0});
      expect(due.snoozed().sound, ReminderSound.chime);
      expect(
        const Due(minute: 23 * 60 + 55).snoozed().minute,
        Due.minutesPerDay - 1,
      );
    });

    test('keeps its reminders as one number, a bit per choice', () {
      expect(Due.encodeReminders(const {}), 0);
      expect(Due.encodeReminders(const {0}), 1);
      expect(Due.encodeReminders(const {5, 60}), 2 | 16);
      expect(Due.encodeReminders(const {Due.minutesPerDay}), 32);
      expect(Due.decodeReminders(2 | 16), {5, 60});
      expect(Due.decodeReminders(null), isEmpty);
      expect(Due.decodeReminders(7), {0, 5, 15});
    });

    test('round trips through its columns', () {
      expect(Due.fromRow(due.toRow()), due);
      expect(Due.fromRow(Due.emptyRow), isNull);
      expect(Due.fromRow(const <String, Object?>{}), isNull);
      expect(
        Due.fromRow(const {'due_time': 60, 'reminder': 1, 'sound': 'what'}),
        const Due(minute: 60, reminders: {0}),
        reason: 'an unknown sound falls back to the system one',
      );
    });

    test('a sound falls back to the system one', () {
      expect(ReminderSound.fromName('bell'), ReminderSound.bell);
      expect(ReminderSound.fromName(null), ReminderSound.system);
      expect(ReminderSound.fromName('gong'), ReminderSound.system);
      expect(ReminderSound.system.file, isNull);
      expect(ReminderSound.chime.file, 'chime.caf');
      expect(
        ReminderSound.values.where((s) => s.file != null),
        hasLength(9),
        reason: 'nine tones ship in the bundle',
      );
    });
  });

  test('nothing is shown while the app is in front', () {
    final settings = LocalReminderScheduler.initializationSettings.iOS!;
    expect(settings.defaultPresentAlert, isFalse);
    expect(settings.defaultPresentBanner, isFalse);
    expect(settings.defaultPresentList, isFalse);
    expect(settings.defaultPresentSound, isFalse);
    expect(settings.requestAlertPermission, isFalse, reason: 'not at launch');
  });

  group('a planned reminder', () {
    PlannedReminder plan(int day, String key, {int before = 0}) =>
        PlannedReminder(
          day: day,
          key: key,
          title: 'Take the pills',
          dueLabel: 'Due 9:30 AM',
          fireAt: DateTime(2026, 9, 4, 9, 15),
          before: before,
        );

    test('carries its task in the payload and reads it back', () {
      expect(PlannedReminder.parsePayload(plan(20699, 'r3').payload), (
        20699,
        'r3',
      ));
      expect(PlannedReminder.parsePayload(null), isNull);
      expect(PlannedReminder.parsePayload('nonsense'), isNull);
      expect(PlannedReminder.parsePayload('x:t1'), isNull);
    });

    test('ids tell one day, task and lead time from another', () {
      expect(plan(1, 't1').id, isNot(plan(2, 't1').id));
      expect(plan(1, 't1').id, isNot(plan(1, 't2').id));
      expect(plan(1, 't1').id, isNot(plan(1, 't1', before: 5).id));
      expect(plan(1, 't1').id, plan(1, 't1').id);
      expect(plan(1, 't1').id, isNonNegative);
    });
  });
}
