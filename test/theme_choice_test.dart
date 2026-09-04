import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/state/theme_choice.dart';

import 'support/memory_settings_store.dart';

void main() {
  test('a saved look is loaded by name', () async {
    final store = MemorySettingsStore({ThemeChoice.settingKey: 'forest'});
    expect(await ThemeChoice.load(store), AppThemeChoice.forest);
  });

  test('nothing saved, or a name no longer known, falls back to Ink', () async {
    expect(await ThemeChoice.load(MemorySettingsStore()), AppThemeChoice.ink);
    final stale = MemorySettingsStore({ThemeChoice.settingKey: 'lavender'});
    expect(await ThemeChoice.load(stale), AppThemeChoice.ink);
    expect(AppThemeChoice.fallback, AppThemeChoice.ink);
  });

  test('every look has a light and a dark palette', () {
    for (final choice in AppThemeChoice.values) {
      expect(
        AppTheme.schemeFor(choice, Brightness.light).brightness,
        Brightness.light,
      );
      expect(
        AppTheme.schemeFor(choice, Brightness.dark).brightness,
        Brightness.dark,
      );
    }
  });
}
