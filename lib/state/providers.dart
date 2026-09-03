import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/todo.dart';
import '../data/todo_store.dart';
import 'selected_day.dart';
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
