import '../data/reminder_sound.dart';
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

  /// Shows one notification a few seconds from now, so the sound and the
  /// banner can be checked from the settings screen. Shown even with the app
  /// in front, which is where the person asking for it is.
  Future<void> sendTest({required DateTime at, required ReminderSound sound});

  Future<ReminderPermission> permission();

  /// Asks the system for leave to notify. Safe to call again; a second ask
  /// answers from the first.
  Future<bool> requestPermission();

  /// Opens the app's own page in the system settings, where a refusal can
  /// be undone.
  Future<void> openSettings();
}
