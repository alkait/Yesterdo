import '../data/reminder_sound.dart';

/// One notification to be shown: which task, on which day, and when.
class PlannedReminder {
  const PlannedReminder({
    required this.day,
    required this.key,
    required this.title,
    required this.dueLabel,
    required this.fireAt,
    required this.before,
    this.sound = ReminderSound.system,
  });

  final int day;

  /// The task's [Todo.key], which survives a projected task being written
  /// down, so a tapped notification still finds its card.
  final String key;

  /// The task's first line, which is what the notification says.
  final String title;

  /// `Due 9:30 AM`, the notification's supporting line.
  final String dueLabel;

  final DateTime fireAt;

  /// Minutes ahead of the task's time this one fires. A task can carry
  /// several, so it is part of the identity.
  final int before;

  final ReminderSound sound;

  /// A stable notification id. Ids only have to be unique within one
  /// batch, since every batch replaces the last outright.
  int get id => Object.hash(day, key, before) & 0x7fffffff;

  /// Carried on the notification and read back when it is tapped.
  String get payload => '$day:$key';

  /// The day and key a tapped notification carried, or null for a payload
  /// that is not one of ours.
  static (int, String)? parsePayload(String? payload) {
    if (payload == null) return null;
    final split = payload.indexOf(':');
    if (split == -1) return null;
    final day = int.tryParse(payload.substring(0, split));
    if (day == null) return null;
    return (day, payload.substring(split + 1));
  }
}
