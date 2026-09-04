import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/data/reminder_sound.dart';
import 'package:remind_me/platform/device_bridge.dart';
import 'package:remind_me/reminders/reminder_scheduler.dart';

/// Test double for [DeviceBridge]. Remembers what it was asked to do.
class MemoryDeviceBridge implements DeviceBridge {
  AppThemeChoice? icon;
  final List<ReminderSound> previewed = <ReminderSound>[];
  ReminderPermission status = ReminderPermission.notAsked;

  @override
  Future<void> setAppIcon(AppThemeChoice choice) {
    icon = choice;
    return Future.value();
  }

  @override
  Future<void> previewSound(ReminderSound sound) {
    previewed.add(sound);
    return Future.value();
  }

  final List<String> opened = <String>[];

  @override
  Future<void> openUrl(String url) {
    opened.add(url);
    return Future.value();
  }

  @override
  Future<ReminderPermission> notificationPermission() => Future.value(status);
}
