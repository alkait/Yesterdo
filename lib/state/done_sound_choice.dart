import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/done_sound.dart';
import '../data/settings_store.dart';
import 'providers.dart';

/// Which sound marks a task done.
///
/// Starts from [initialDoneSoundProvider], which `main` binds to the saved
/// choice before the first frame.
class DoneSoundChoice extends Notifier<DoneSound> {
  /// The name the choice is written under in the settings store.
  static const settingKey = 'doneSound';

  static Future<DoneSound> load(SettingsStore store) async =>
      DoneSound.fromName(await store.read(settingKey));

  @override
  DoneSound build() => ref.watch(initialDoneSoundProvider);

  Future<void> select(DoneSound sound) async {
    if (sound == state) return;
    state = sound;
    await ref.read(settingsStoreProvider).write(settingKey, sound.name);
  }
}
