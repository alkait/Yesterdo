import 'package:remind_me/reminders/planned_reminder.dart';
import 'package:remind_me/reminders/reminder_scheduler.dart';

/// Test double for [ReminderScheduler]. Keeps the last batch handed over so a
/// test can see what the system would have been asked to show.
class MemoryReminderScheduler implements ReminderScheduler {
  List<PlannedReminder> pending = const <PlannedReminder>[];
  int permissionAsks = 0;

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) {
    pending = List.unmodifiable(reminders);
    return Future.value();
  }

  @override
  Future<bool> requestPermission() {
    permissionAsks++;
    return Future.value(true);
  }
}
