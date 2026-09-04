import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';
import 'providers.dart';

/// Whether the tools for trying the app out are shown: a way to ring a
/// task's reminder in ten seconds, and whatever else comes. Turned on by
/// tapping the version row in settings ten times, and off again from the
/// row that then appears.
///
/// Starts from [initialDeveloperModeProvider], which `main` binds to the
/// saved value before the first frame.
class DeveloperMode extends Notifier<bool> {
  /// The name the choice is written under in the settings store.
  static const settingKey = 'developer';

  /// How many taps on the version row turn it on.
  static const tapsToEnable = 10;

  static Future<bool> load(SettingsStore store) async =>
      await store.read(settingKey) == 'on';

  @override
  bool build() => ref.watch(initialDeveloperModeProvider);

  Future<void> set(bool on) async {
    if (on == state) return;
    state = on;
    await ref.read(settingsStoreProvider).write(settingKey, on ? 'on' : 'off');
  }
}
