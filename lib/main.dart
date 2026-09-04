import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/sqlite_settings_store.dart';
import 'data/sqlite_todo_store.dart';
import 'state/providers.dart';
import 'state/theme_choice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened before the first frame so the interface never shows a loader.
  final database = await AppDatabase.open();
  final settings = SqliteSettingsStore(database);
  // Read before the first frame too, so the saved look is the first one seen.
  final theme = await ThemeChoice.load(settings);

  runApp(
    ProviderScope(
      overrides: [
        todoStoreProvider.overrideWithValue(SqliteTodoStore(database)),
        settingsStoreProvider.overrideWithValue(settings),
        initialThemeChoiceProvider.overrideWithValue(theme),
      ],
      child: const RemindMeApp(),
    ),
  );
}
