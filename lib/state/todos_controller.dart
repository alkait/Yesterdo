import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import 'providers.dart';

/// How long the checked task stays put before sinking, so the strike-through
/// lands where the finger did and the movement reads as a consequence.
const Duration reorderDelay = Duration(milliseconds: 260);

/// The task list for the selected day. Rebuilds whenever the day changes.
class TodosController extends AsyncNotifier<List<Todo>> {
  int _day = 0;

  @override
  Future<List<Todo>> build() {
    _day = ref.watch(selectedDayProvider).epochDay;
    return ref.read(todoStoreProvider).todosOn(_day);
  }

  Future<void> add(String title) async {
    final text = title.trim();
    if (text.isEmpty) return;
    final todo = await _store.insert(day: _day, title: text);
    if (!ref.mounted) return;
    state = AsyncData(<Todo>[..._items, todo]..sort(compareTodos));
  }

  Future<void> toggle(Todo todo) async {
    final updated = todo.toggled(DateTime.now().millisecondsSinceEpoch);
    await _store.save(updated);
    if (!ref.mounted) return;

    // Flip in place first; re-order only after the strike has been seen.
    state = AsyncData(<Todo>[
      for (final item in _items) item.id == todo.id ? updated : item,
    ]);
    await Future<void>.delayed(reorderDelay);
    if (!ref.mounted) return;
    state = AsyncData(<Todo>[..._items]..sort(compareTodos));
  }

  Future<void> rename(Todo todo, String title) async {
    final text = title.trim();
    if (text.isEmpty) return;
    final updated = todo.renamed(text);
    await _store.save(updated);
    if (!ref.mounted) return;
    state = AsyncData(<Todo>[
      for (final item in _items) item.id == todo.id ? updated : item,
    ]);
  }

  /// Moves an open task. Completed tasks hold their place at the bottom, so a
  /// drag that lands among them is clamped back into the open group.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = _items;
    final openCount = items.indexWhere((item) => item.done);
    final open = openCount == -1 ? items.length : openCount;
    if (oldIndex >= open) return;

    // newIndex already accounts for the item leaving its old slot.
    final target = newIndex.clamp(0, open - 1);
    if (target == oldIndex) return;

    final moved = items.sublist(0, open);
    moved.insert(target, moved.removeAt(oldIndex));
    final renumbered = <Todo>[
      for (var index = 0; index < moved.length; index++)
        moved[index].repositioned(index),
    ];

    state = AsyncData(<Todo>[...renumbered, ...items.sublist(open)]);
    await _store.reorder(renumbered);
  }

  Future<void> remove(Todo todo) async {
    state = AsyncData(<Todo>[
      for (final item in _items)
        if (item.id != todo.id) item,
    ]);
    await _store.delete(todo.id);
  }

  TodoStore get _store => ref.read(todoStoreProvider);

  List<Todo> get _items => state.value ?? const <Todo>[];
}
