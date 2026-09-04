import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reminder_sound.dart';
import '../data/settings_store.dart';
import 'providers.dart';

/// The sound chosen last time, which a new reminder starts from. Someone who
/// picked Bell once most likely wants Bell again.
///
/// Starts from [initialSoundProvider], which `main` binds to the saved
/// choice before the first frame.
class LastSound extends Notifier<ReminderSound> {
  /// The name the choice is written under in the settings store.
  static const settingKey = 'sound';

  /// Reads the saved sound, or the system's when nothing is saved.
  static Future<ReminderSound> load(SettingsStore store) async =>
      ReminderSound.fromName(await store.read(settingKey));

  @override
  ReminderSound build() => ref.watch(initialSoundProvider);

  Future<void> remember(ReminderSound sound) async {
    if (sound == state) return;
    state = sound;
    await ref.read(settingsStoreProvider).write(settingKey, sound.name);
  }
}
