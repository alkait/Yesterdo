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

  /// Where pictures go. A test that shows one sets this to a real folder.
  String directory = '';

  /// What the next pick or paste hands back, in order; null for a pick
  /// backed out of.
  final List<String?> toPick = <String?>[];
  final List<ImageSource> picked = <ImageSource>[];
  int pastes = 0;
  final List<String> deleted = <String>[];

  @override
  Future<String> imagesDirectory() => Future.value(directory);

  @override
  Future<String?> pickImage(ImageSource source) {
    picked.add(source);
    return Future.value(toPick.isEmpty ? null : toPick.removeAt(0));
  }

  @override
  Future<String?> pasteImage() {
    pastes++;
    return Future.value(toPick.isEmpty ? null : toPick.removeAt(0));
  }

  @override
  Future<void> deleteImage(String image) {
    deleted.add(image);
    return Future.value();
  }

  @override
  Future<void> openUrl(String url) {
    opened.add(url);
    return Future.value();
  }

  @override
  Future<ReminderPermission> notificationPermission() => Future.value(status);
}
