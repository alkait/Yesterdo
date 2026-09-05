import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import 'backlog.dart';
import 'providers.dart';

/// What is left from earlier days, and the ways of clearing it. Each action
/// is applied to every day an entry stands for, then the store is read
/// again, so the sheet shows what is true rather than what was guessed.
class BacklogController extends AsyncNotifier<Backlog> {
  @override
  Future<Backlog> build() =>
      Backlog.read(ref.watch(todoStoreProvider), today: _today);

  /// Marks every showing done, writing each down first.
  Future<void> done(BacklogEntry entry) async {
    final finished = _now.millisecondsSinceEpoch;
    for (final item in entry.items) {
      final written = await _write(item);
      await _store.save(written.toggled(finished));
    }
    await _settle();
  }

  /// Deletes every missed showing: each is hidden, as deleting one showing
  /// of a rule does, and the rule goes on.
  Future<void> deleteMissed(BacklogEntry entry) async {
    for (final item in entry.items) {
      await _store.remove(day: item.day, todo: item.todo);
    }
    await _settle();
  }

  /// Leaves every missed showing where it is and stops it being raised
  /// again. The rule goes on, and a day missed after these counts anew.
  Future<void> ignoreMissed(BacklogEntry entry) async {
    await _store.ignoreMissed(
      recurrenceId: entry.todo.recurrenceId!,
      day: entry.latestDay,
    );
    await _settle();
  }

  /// Puts a one-off on today, or on a later [day], above everything there:
  /// what was brought back is the thing to see first.
  Future<void> bring(BacklogEntry entry, {int? day}) async {
    final item = entry.items.single;
    await _store.moveToDay(
      fromDay: item.day,
      toDay: day ?? _today,
      todo: item.todo,
      toTop: true,
    );
    await _settle();
  }

  /// Removes a one-off outright.
  Future<void> delete(BacklogEntry entry) async {
    final item = entry.items.single;
    await _store.remove(day: item.day, todo: item.todo);
    await _settle();
  }

  TodoStore get _store => ref.read(todoStoreProvider);

  DateTime get _now => ref.read(clockProvider)();

  int get _today => _now.epochDay;

  Future<Todo> _write(BacklogItem item) => item.todo.isStored
      ? Future.value(item.todo)
      : _store.materialize(day: item.day, todo: item.todo);

  /// The day on screen is read again, which also tops up the reminders,
  /// numbers the icon and reads this backlog afresh.
  Future<void> _settle() => ref.read(todosProvider.notifier).refresh();
}
