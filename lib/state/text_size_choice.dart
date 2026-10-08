import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/text_size.dart';
import '../data/settings_store.dart';
import 'providers.dart';

/// How large the words are drawn.
///
/// Starts from [initialTextSizeProvider], which `main` binds to the saved
/// choice before the first frame, so the app never flashes one size and
/// then switches to another.
class TextSizeChoice extends Notifier<AppTextSize> {
  /// The name the choice is written under in the settings store.
  static const settingKey = 'textSize';

  static Future<AppTextSize> load(SettingsStore store) async =>
      AppTextSize.fromName(await store.read(settingKey));

  @override
  AppTextSize build() => ref.watch(initialTextSizeProvider);

  Future<void> select(AppTextSize size) async {
    if (size == state) return;
    state = size;
    await ref.read(settingsStoreProvider).write(settingKey, size.name);
  }
}
