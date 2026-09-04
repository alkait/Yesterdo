import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../data/settings_store.dart';
import 'providers.dart';

/// The look the whole interface is drawn in.
///
/// It starts from [initialThemeChoiceProvider], which `main` binds to the
/// saved choice before the first frame so the app never flashes one look and
/// then switches to another.
class ThemeChoice extends Notifier<AppThemeChoice> {
  /// The name the choice is written under in the settings store.
  static const settingKey = 'theme';

  /// Reads the saved choice, or [AppThemeChoice.fallback] when nothing is
  /// saved.
  static Future<AppThemeChoice> load(SettingsStore store) async =>
      AppThemeChoice.fromName(await store.read(settingKey));

  @override
  AppThemeChoice build() => ref.watch(initialThemeChoiceProvider);

  /// Applies the look at once, saves it, and swaps the home screen icon to
  /// match.
  Future<void> select(AppThemeChoice choice) async {
    state = choice;
    await ref.read(settingsStoreProvider).write(settingKey, choice.name);
    await ref.read(deviceBridgeProvider).setAppIcon(choice);
  }
}
