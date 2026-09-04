import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'planned_reminder.dart';
import 'reminder_scheduler.dart';

/// The shipping scheduler: local notifications through the system, nothing
/// leaving the device.
class LocalReminderScheduler implements ReminderScheduler {
  const LocalReminderScheduler(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(interruptionLevel: InterruptionLevel.active),
  );

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    await _plugin.cancelAll();
    for (final reminder in reminders) {
      // The plan was drawn up a moment ago; one that has since gone by is
      // not worth the throw the plugin answers it with.
      if (!reminder.fireAt.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.dueLabel,
        // An instant is an instant in any zone, and UTC needs no zone
        // database to be loaded.
        scheduledDate: tz.TZDateTime.from(reminder.fireAt, tz.UTC),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exact,
        payload: reminder.payload,
      );
    }
  }

  @override
  Future<bool> requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios == null) return false;
    return await ios.requestPermissions(alert: true, sound: true) ?? false;
  }
}
