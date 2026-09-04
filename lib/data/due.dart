import 'dart:math' as math;

import '../core/date_labels.dart';
import '../core/day.dart';

/// When in the day a task is due, and how far ahead of that to be reminded.
///
/// Holds no day of its own: a one-off's day is the row it sits on, and a
/// repeating task is due at the same time on every day it falls on.
class Due {
  const Due({required this.minute, this.reminder})
    : assert(minute >= 0 && minute < minutesPerDay, 'a minute of the day');

  static const minutesPerDay = 24 * 60;

  /// How far a snooze pushes the time on.
  static const snoozeStep = 10;

  /// The reminders the chooser offers, in minutes before the time. Zero is
  /// at the time itself; no reminder at all is null.
  static const reminderChoices = <int>[0, 5, 15, 30, 60];

  /// Minutes after midnight.
  final int minute;

  /// Minutes before [minute] a notification fires, or null for none.
  final int? reminder;

  bool get hasReminder => reminder != null;

  /// The moment this falls on a given day, in local time.
  DateTime instantOn(int day) => dateFromEpochDayAt(day, minute);

  /// When the reminder fires on a given day, or null without one.
  DateTime? reminderInstantOn(int day) => reminder == null
      ? null
      : instantOn(day).subtract(Duration(minutes: reminder!));

  /// Pushed on by [snoozeStep] from [from], the minute of the day it is now,
  /// or from its own time if that is later. Never runs past the end of the
  /// day, and is set to speak up again when the new time comes.
  Due snoozed({int? from}) => Due(
    minute: math.min(
      math.max(minute, from ?? minute) + snoozeStep,
      minutesPerDay - 1,
    ),
    reminder: 0,
  );

  /// `9:30 AM`, or `09:30` in 24-hour form.
  String label({bool twentyFourHour = false}) =>
      timeLabel(minute, twentyFourHour: twentyFourHour);

  /// What the chooser and the editor call a reminder setting.
  static String reminderLabel(int? reminder) => switch (reminder) {
    null => 'No reminder',
    0 => 'At the time',
    60 => '1 hour before',
    final minutes => '$minutes minutes before',
  };

  /// The two columns a due time is kept in, on a task row or a rule.
  Map<String, Object?> toRow() => <String, Object?>{
    'due_time': minute,
    'reminder': reminder,
  };

  static Due? fromRow(Map<String, Object?> row) {
    final minute = row['due_time'] as int?;
    if (minute == null) return null;
    return Due(minute: minute, reminder: row['reminder'] as int?);
  }

  /// Columns for a row with no due time at all.
  static const emptyRow = <String, Object?>{'due_time': null, 'reminder': null};

  @override
  bool operator ==(Object other) =>
      other is Due && other.minute == minute && other.reminder == reminder;

  @override
  int get hashCode => Object.hash(minute, reminder);

  @override
  String toString() => 'Due($minute, reminder: $reminder)';
}
