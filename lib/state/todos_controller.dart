import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import 'providers.dart';
import 'task_draft.dart';

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

  Future<void> add(TaskDraft draft) async {
    if (draft.title.isEmpty) return;

    if (draft.repeat != null) {
      await _store.insertSeries(
        day: _day,
        title: draft.title,
        rule: draft.repeat!,
      );
      // A weekly rule may not fire on the day it was written on, so the day is
      // read afresh rather than guessed at.
      return _reload();
    }

    final todo = await _store.insert(day: _day, title: draft.title);
    if (!ref.mounted) return;
    state = AsyncData(<Todo>[..._items, todo]..sort(compareTodos));
  }

  Future<void> toggle(Todo todo) async {
    final written = await _write(todo);
    final updated = written.toggled(DateTime.now().millisecondsSinceEpoch);
    await _store.save(updated);
    if (!ref.mounted) return;

    // Flip in place first; re-order only after the strike has been seen.
    state = AsyncData(_replacing(updated));
    await Future<void>.delayed(reorderDelay);
    if (!ref.mounted) return;
    state = AsyncData(<Todo>[..._items]..sort(compareTodos));
  }

  /// Applies an edit. Words and rule both belong to the series, so editing a
  /// repeating task changes every day it appears on.
  Future<void> apply(Todo todo, TaskDraft draft) async {
    if (draft.title.isEmpty) return;

    if (todo.repeats && draft.repeat != null) {
      await _store.saveSeries(
        recurrenceId: todo.recurrenceId!,
        title: draft.title,
        rule: draft.repeat!,
      );
    } else if (todo.repeats) {
      // Repeating no more: the series goes, and this day keeps a one-off.
      await _store.removeSeries(todo.recurrenceId!);
      await _store.insert(day: _day, title: draft.title);
    } else if (draft.repeat != null) {
      // A one-off becomes a series starting on this day.
      await _store.remove(day: _day, todo: todo);
      await _store.insertSeries(
        day: _day,
        title: draft.title,
        rule: draft.repeat!,
      );
    } else {
      await _store.save(todo.renamed(draft.title));
    }

    await _reload();
  }

  /// Drops this showing only. A repeating task stays on its other days.
  Future<void> removeOccurrence(Todo todo) async {
    state = AsyncData(_without(todo));
    await _store.remove(day: _day, todo: todo);
  }

  /// Drops this showing and every one before it, keeping the days after.
  Future<void> removeUpToHere(Todo todo) async {
    state = AsyncData(_without(todo));
    await _store.startSeriesAfter(recurrenceId: todo.recurrenceId!, day: _day);
  }

  /// Drops this showing and every one after it, keeping the days before.
  Future<void> removeFromHere(Todo todo) async {
    state = AsyncData(_without(todo));
    await _store.endSeriesFrom(recurrenceId: todo.recurrenceId!, day: _day);
  }

  /// Drops the whole repeating task, on every day.
  Future<void> removeSeries(Todo todo) async {
    state = AsyncData(_without(todo));
    await _store.removeSeries(todo.recurrenceId!);
  }

  /// Moves an open task. Completed tasks hold their place at the bottom, so a
  /// drag that lands among them is clamped back into the open group.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = _items;
    final firstDone = items.indexWhere((item) => item.done);
    final open = firstDone == -1 ? items.length : firstDone;
    if (oldIndex >= open) return;

    // newIndex already accounts for the item leaving its old slot.
    final target = newIndex.clamp(0, open - 1);
    if (target == oldIndex) return;

    // Positions only mean something on a written-down row.
    final moved = <Todo>[
      for (final todo in items.sublist(0, open)) await _write(todo),
    ];
    if (!ref.mounted) return;
    moved.insert(target, moved.removeAt(oldIndex));

    final renumbered = <Todo>[
      for (var index = 0; index < moved.length; index++)
        moved[index].repositioned(index),
    ];
    state = AsyncData(<Todo>[...renumbered, ...items.sublist(open)]);
    await _store.reorder(renumbered);
  }

  /// Writes a projected occurrence down so it can carry state of its own.
  Future<Todo> _write(Todo todo) => todo.isStored
      ? Future.value(todo)
      : _store.materialize(day: _day, todo: todo);

  Future<void> _reload() async {
    final todos = await _store.todosOn(_day);
    if (ref.mounted) state = AsyncData(todos);
  }

  List<Todo> _replacing(Todo updated) => <Todo>[
    for (final item in _items) item.key == updated.key ? updated : item,
  ];

  List<Todo> _without(Todo gone) => <Todo>[
    for (final item in _items)
      if (item.key != gone.key) item,
  ];

  TodoStore get _store => ref.read(todoStoreProvider);

  List<Todo> get _items => state.value ?? const <Todo>[];
}
