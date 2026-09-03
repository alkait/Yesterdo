import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/sqlite_todo_store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opened before the first frame so the interface never shows a loader.
  final database = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        todoStoreProvider.overrideWithValue(SqliteTodoStore(database)),
      ],
      child: const RemindMeApp(),
    ),
  );
}
