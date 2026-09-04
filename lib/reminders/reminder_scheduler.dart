import 'planned_reminder.dart';

/// Where notifications are handed to the system. One implementation talks to
/// iOS; tests supply their own and look at what was handed over.
abstract class ReminderScheduler {
  /// Replaces every pending notification with this batch. Always called with
  /// the whole plan, so nothing stale can linger.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// Asks the system for leave to notify. Safe to call again; a second ask
  /// answers from the first.
  Future<bool> requestPermission();
}
