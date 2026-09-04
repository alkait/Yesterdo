import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/reminder_sound.dart';
import '../reminders/reminder_scheduler.dart';

/// The few things only the device itself can do: swap the app icon, play a
/// sound out loud, and say whether notifications were ever allowed. One
/// implementation talks to iOS; tests supply their own.
abstract class DeviceBridge {
  /// Shows the icon drawn for this look on the home screen.
  Future<void> setAppIcon(AppThemeChoice choice);

  /// Plays a reminder sound once, so it can be heard before it is chosen.
  Future<void> previewSound(ReminderSound sound);

  Future<ReminderPermission> notificationPermission();
}

/// The shipping bridge: a method channel into `AppDelegate`.
class MethodChannelDeviceBridge implements DeviceBridge {
  const MethodChannelDeviceBridge();

  static const _channel = MethodChannel('remindme/device');

  @override
  Future<void> setAppIcon(AppThemeChoice choice) => _channel.invokeMethod(
    'setAppIcon',
    // The look the app ships in is the primary icon, which has no name.
    choice == AppThemeChoice.fallback ? null : 'AppIcon-${choice.name}',
  );

  @override
  Future<void> previewSound(ReminderSound sound) =>
      _channel.invokeMethod('previewSound', sound.file);

  @override
  Future<ReminderPermission> notificationPermission() async {
    final status = await _channel.invokeMethod<String>(
      'notificationPermission',
    );
    return switch (status) {
      'granted' => ReminderPermission.granted,
      'notAsked' => ReminderPermission.notAsked,
      _ => ReminderPermission.denied,
    };
  }
}
