import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';
import 'providers.dart';

/// Whether the app makes a sound of its own, such as when a task is marked
/// done. Reminders are the system's and are not touched by this.
///
/// Starts from [initialAppSoundsProvider], which `main` binds to the saved
/// value before the first frame.
class AppSounds extends Notifier<bool> {
  /// The name the choice is written under in the settings store.
  static const settingKey = 'sounds';

  /// Reads the saved choice; on unless it was turned off.
  static Future<bool> load(SettingsStore store) async =>
      await store.read(settingKey) != 'off';

  @override
  bool build() => ref.watch(initialAppSoundsProvider);

  Future<void> set(bool on) async {
    if (on == state) return;
    state = on;
    await ref.read(settingsStoreProvider).write(settingKey, on ? 'on' : 'off');
  }
}
