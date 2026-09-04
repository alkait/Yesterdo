import 'package:remind_me/reminders/planned_reminder.dart';
import 'package:remind_me/reminders/reminder_scheduler.dart';

/// Test double for [ReminderScheduler]. Keeps the last batch handed over so a
/// test can see what the system would have been asked to show, and answers
/// about permission however the test sets it.
class MemoryReminderScheduler implements ReminderScheduler {
  MemoryReminderScheduler({this.status = ReminderPermission.notAsked});

  List<PlannedReminder> pending = const <PlannedReminder>[];
  ReminderPermission status;
  int permissionAsks = 0;
  int settingsOpened = 0;
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) {
    pending = List.unmodifiable(reminders);
    return Future.value();
  }

  final List<PlannedReminder> rehearsed = <PlannedReminder>[];

  @override
  Future<void> rehearse(PlannedReminder reminder) {
    rehearsed.add(reminder);
    return Future.value();
  }

  @override
  Future<ReminderPermission> permission() => Future.value(status);

  /// Asking is granted, the way a tester says yes to the prompt.
  @override
  Future<bool> requestPermission() {
    permissionAsks++;
    status = ReminderPermission.granted;
    return Future.value(true);
  }

  @override
  Future<void> openSettings() {
    settingsOpened++;
    return Future.value();
  }
}
