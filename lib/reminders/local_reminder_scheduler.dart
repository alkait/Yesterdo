import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/reminder_sound.dart';
import '../platform/device_bridge.dart';
import 'planned_reminder.dart';
import 'reminder_scheduler.dart';

/// The shipping scheduler: local notifications through the system, nothing
/// leaving the device.
class LocalReminderScheduler implements ReminderScheduler {
  const LocalReminderScheduler(this._plugin, this._device);

  final FlutterLocalNotificationsPlugin _plugin;

  /// The plugin cannot tell a question never put from one refused, so the
  /// device is asked about permission directly.
  final DeviceBridge _device;

  /// How the plugin is set up: no permission asked at launch, and nothing
  /// shown while the app is in front, since the card itself calls then.
  static const initializationSettings = InitializationSettings(
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: false,
      defaultPresentBanner: false,
      defaultPresentList: false,
      defaultPresentSound: false,
      defaultPresentBadge: false,
    ),
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
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            sound: reminder.sound.file,
            interruptionLevel: InterruptionLevel.active,
            presentAlert: false,
            presentBanner: false,
            presentList: false,
            presentSound: false,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exact,
        payload: reminder.payload,
      );
    }
  }

  /// Well clear of any task's id, which is a positive hash.
  static const _testId = 0;

  @override
  Future<void> sendTest({required DateTime at, required ReminderSound sound}) =>
      _plugin.zonedSchedule(
        id: _testId,
        title: 'Test reminder',
        body: 'This is what a reminder looks like.',
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: NotificationDetails(
          iOS: DarwinNotificationDetails(
            sound: sound.file,
            interruptionLevel: InterruptionLevel.active,
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exact,
      );

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<ReminderPermission> permission() => _device.notificationPermission();

  @override
  Future<bool> requestPermission() async =>
      await _ios?.requestPermissions(alert: true, sound: true) ?? false;

  @override
  Future<void> openSettings() async {
    await _ios?.openAppNotificationSettings();
  }
}
