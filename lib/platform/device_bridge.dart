import 'package:flutter/services.dart';

import '../core/app_theme.dart';
import '../data/done_sound.dart';
import '../data/reminder_sound.dart';
import '../reminders/reminder_scheduler.dart';

/// The few things only the device itself can do: swap the app icon, number
/// it, play a sound out loud, and say whether notifications were ever
/// allowed. One implementation talks to iOS; tests supply their own.
abstract class DeviceBridge {
  /// Shows the icon drawn for this look on the home screen.
  Future<void> setAppIcon(AppThemeChoice choice);

  /// Puts a number on the icon, or takes it off with zero. The system only
  /// shows it once notifications have been allowed.
  Future<void> setBadge(int count);

  /// Plays a reminder sound once, so it can be heard before it is chosen.
  Future<void> previewSound(ReminderSound sound);

  /// Plays a sound that marks a task done.
  Future<void> playDone(DoneSound sound);

  Future<ReminderPermission> notificationPermission();

  /// Hands a web address to the system to open.
  Future<void> openUrl(String url);

  /// The folder pictures are kept in, under the app's own documents.
  Future<String> imagesDirectory();

  /// Lets a picture be taken or chosen, sized down and saved into the
  /// images folder. Returns its file name, or null if none was picked.
  Future<String?> pickImage(ImageSource source);

  /// Saves whatever picture is on the pasteboard the same way. Null when
  /// there is none.
  Future<String?> pasteImage();

  Future<void> deleteImage(String image);
}

/// Where a picture comes from.
enum ImageSource { camera, library }

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
  Future<void> setBadge(int count) => _channel.invokeMethod('setBadge', count);

  @override
  Future<void> previewSound(ReminderSound sound) =>
      _channel.invokeMethod('previewSound', sound.file);

  @override
  Future<void> playDone(DoneSound sound) =>
      _channel.invokeMethod('playSound', sound.file);

  @override
  Future<void> openUrl(String url) => _channel.invokeMethod('openUrl', url);

  @override
  Future<String> imagesDirectory() async =>
      (await _channel.invokeMethod<String>('imagesDirectory'))!;

  @override
  Future<String?> pickImage(ImageSource source) =>
      _channel.invokeMethod<String>('pickImage', source.name);

  @override
  Future<String?> pasteImage() => _channel.invokeMethod<String>('pasteImage');

  @override
  Future<void> deleteImage(String image) =>
      _channel.invokeMethod('deleteImage', image);

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
