import 'dart:math' as math;

import '../core/date_labels.dart';
import '../core/day.dart';
import 'reminder_sound.dart';

/// When in the day a task is due, how far ahead of that to be reminded, and
/// what the reminders sound like.
///
/// Holds no day of its own: a one-off's day is the row it sits on, and a
/// repeating task is due at the same time on every day it falls on.
class Due {
  const Due({
    required this.minute,
    this.reminders = const <int>{},
    this.sound = ReminderSound.system,
  }) : assert(minute >= 0 && minute < minutesPerDay, 'a minute of the day');

  static const minutesPerDay = 24 * 60;

  /// How far a snooze pushes the time on.
  static const snoozeStep = 10;

  /// Every reminder a task can carry, in minutes before its time. Each one
  /// is a bit in the stored value, in this order.
  static const reminderChoices = <int>[0, 5, 15, 30, 60, minutesPerDay];

  /// Minutes after midnight.
  final int minute;

  /// Minutes before [minute] a notification fires. Empty for none.
  final Set<int> reminders;

  final ReminderSound sound;

  bool get hasReminder => reminders.isNotEmpty;

  /// The moment this falls on a given day, in local time.
  DateTime instantOn(int day) => dateFromEpochDayAt(day, minute);

  /// When each reminder fires on a given day, earliest first.
  List<DateTime> reminderInstantsOn(int day) {
    final at = instantOn(day);
    return [
      for (final before in reminders.toList()..sort((a, b) => b.compareTo(a)))
        at.subtract(Duration(minutes: before)),
    ];
  }

  /// Pushed on by [snoozeStep] from [from], the minute of the day it is now,
  /// or from its own time if that is later. Never runs past the end of the
  /// day, and is set to speak up again when the new time comes.
  Due snoozed({int? from}) => Due(
    minute: math.min(
      math.max(minute, from ?? minute) + snoozeStep,
      minutesPerDay - 1,
    ),
    reminders: const {0},
    sound: sound,
  );

  /// `9:30 AM`, or `09:30` in 24-hour form.
  String label({bool twentyFourHour = false}) =>
      timeLabel(minute, twentyFourHour: twentyFourHour);

  /// What the chooser calls one reminder. The one at the time itself names
  /// the time, `At 8:00 AM`, which is clearer than saying "at the time".
  String reminderLabel(int before, {bool twentyFourHour = false}) =>
      switch (before) {
        0 => 'At ${label(twentyFourHour: twentyFourHour)}',
        60 => '1 hour before',
        minutesPerDay => '1 day before',
        final minutes => '$minutes minutes before',
      };

  /// The reminders in one line: `5 min, 1 hr before`, `At 8:00 AM`,
  /// `At 8:00 AM, 1 hr before`, `No reminder`.
  String remindersLabel({bool twentyFourHour = false}) {
    if (reminders.isEmpty) return 'No reminder';
    final ahead = reminders.where((before) => before > 0).toList()..sort();
    final parts = [
      for (final before in ahead)
        switch (before) {
          60 => '1 hr',
          minutesPerDay => '1 day',
          final minutes => '$minutes min',
        },
    ];
    final atTime = reminders.contains(0)
        ? 'At ${label(twentyFourHour: twentyFourHour)}'
        : null;
    if (parts.isEmpty) return atTime!;
    final before = '${parts.join(', ')} before';
    return atTime == null ? before : '$atTime, $before';
  }

  /// The reminders as one number, a bit per choice.
  static int encodeReminders(Set<int> reminders) {
    var bits = 0;
    for (final (index, choice) in reminderChoices.indexed) {
      if (reminders.contains(choice)) bits |= 1 << index;
    }
    return bits;
  }

  static Set<int> decodeReminders(int? bits) => {
    for (final (index, choice) in reminderChoices.indexed)
      if ((bits ?? 0) & (1 << index) != 0) choice,
  };

  /// The columns a due time is kept in, on a task row or a rule.
  Map<String, Object?> toRow() => <String, Object?>{
    'due_time': minute,
    'reminder': encodeReminders(reminders),
    'sound': sound.name,
  };

  static Due? fromRow(Map<String, Object?> row) {
    final minute = row['due_time'] as int?;
    if (minute == null) return null;
    return Due(
      minute: minute,
      reminders: decodeReminders(row['reminder'] as int?),
      sound: ReminderSound.fromName(row['sound'] as String?),
    );
  }

  /// Columns for a row with no due time at all.
  static const emptyRow = <String, Object?>{
    'due_time': null,
    'reminder': null,
    'sound': null,
  };

  Due copyWith({int? minute, Set<int>? reminders, ReminderSound? sound}) => Due(
    minute: minute ?? this.minute,
    reminders: reminders ?? this.reminders,
    sound: sound ?? this.sound,
  );

  @override
  bool operator ==(Object other) =>
      other is Due &&
      other.minute == minute &&
      other.sound == sound &&
      encodeReminders(other.reminders) == encodeReminders(reminders);

  @override
  int get hashCode => Object.hash(minute, encodeReminders(reminders), sound);

  @override
  String toString() => 'Due($minute, reminders: $reminders, sound: $sound)';
}
