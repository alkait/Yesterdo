import 'planned_reminder.dart';

/// Whether the system lets the app notify.
enum ReminderPermission {
  /// Never asked, so asking will put the system's prompt up.
  notAsked,
  granted,

  /// Refused, or turned off since. Only the system's settings can undo it.
  denied,
}

/// Where notifications are handed to the system. One implementation talks to
/// iOS; tests supply their own and look at what was handed over.
abstract class ReminderScheduler {
  /// Replaces every pending notification with this batch. Always called with
  /// the whole plan, so nothing stale can linger.
  Future<void> replaceAll(List<PlannedReminder> reminders);

  /// TEMPORARY. Shows one reminder as it would really be shown, a few
  /// seconds from now, so the notification path can be tried without
  /// waiting for a real time to come round. Shown even with the app in
  /// front. Take out with the rehearsal button on the card.
  Future<void> rehearse(PlannedReminder reminder);

  Future<ReminderPermission> permission();

  /// Asks the system for leave to notify. Safe to call again; a second ask
  /// answers from the first.
  Future<bool> requestPermission();

  /// Opens the app's own page in the system settings, where a refusal can
  /// be undone.
  Future<void> openSettings();
}
