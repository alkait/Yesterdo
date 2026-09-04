import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_theme.dart';
import '../data/settings_store.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import 'selected_day.dart';
import 'theme_choice.dart';
import 'todos_controller.dart';

/// Bound to the opened database in `main`. Riverpod is the only state
/// mechanism in this app; nothing else holds shared state.
final todoStoreProvider = Provider<TodoStore>(
  (ref) => throw StateError('todoStoreProvider must be overridden'),
);

final selectedDayProvider = NotifierProvider<SelectedDay, DateTime>(
  SelectedDay.new,
);

final todosProvider = AsyncNotifierProvider<TodosController, List<Todo>>(
  TodosController.new,
);

/// Bound to the opened database in `main`, alongside the todo store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw StateError('settingsStoreProvider must be overridden'),
);

/// The look in force when the app came up. `main` overrides it with the
/// saved choice; left alone, it is the plain one.
final initialThemeChoiceProvider = Provider<AppThemeChoice>(
  (ref) => AppThemeChoice.ink,
);

final themeChoiceProvider = NotifierProvider<ThemeChoice, AppThemeChoice>(
  ThemeChoice.new,
);
