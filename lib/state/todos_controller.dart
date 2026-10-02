import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/day.dart';
import '../data/rich/task_body.dart';
import '../data/todo.dart';
import '../data/todo_store.dart';
import 'providers.dart';
import 'task_draft.dart';

/// How long the checked task stays put before sinking, so the strike-through
/// lands where the finger did and the movement reads as a consequence.
const Duration reorderDelay = Duration(milliseconds: 260);

/// The task list for the selected day. Rebuilds whenever the day changes.
///
/// Tasks whose time has come head the list. The controller keeps a timer set
/// for the next such moment, so a card rises the minute it falls due even
/// while nothing else is happening.
class TodosController extends AsyncNotifier<List<Todo>> {
  int _day = 0;
  Timer? _nextCall;

  @override
  Future<List<Todo>> build() async {
    ref.onDispose(() => _nextCall?.cancel());
    _day = ref.watch(selectedDayProvider).epochDay;
    final todos = await ref.read(todoStoreProvider).todosOn(_day, now: _now);
    _armFor(todos);
    return todos;
  }

  /// Reads the day afresh, as after time has passed while the app was away.
  Future<void> refresh() => _reload();

  /// Writes a task from a draft, and says which it is by its key, so it
  /// can be pointed out. Null when there were no words to write.
  Future<String?> add(TaskDraft draft) async {
    if (!draft.body.hasWords) return null;

    if (draft.repeat != null) {
      final id = await _store.insertSeries(
        day: draft.day,
        body: draft.body,
        rule: draft.repeat!,
        due: draft.due,
      );
      final key = Todo.seriesKey(id);
      if (draft.pinned) await _keepPin(day: draft.day, key: key);
      // A weekly rule may not fire on the day it was written on, so the day is
      // read afresh rather than guessed at.
      await _reload();
      return key;
    }

    final todo = await _store.insert(
      day: draft.day,
      body: draft.body,
      due: draft.due,
      pinned: draft.pinned,
    );
    if (!ref.mounted) return todo.key;
    // Written for another day, it belongs to no list on screen. The banner
    // is what says where it went.
    if (draft.day == _day) _show(_sorted(<Todo>[..._items, todo]));
    await _syncDevice();
    return todo.key;
  }

  Future<void> toggle(Todo todo) async {
    final written = await _write(todo);
    final updated = written.toggled(_now.millisecondsSinceEpoch);
    await _store.save(updated);
    if (!ref.mounted) return;
    // Done is heard as well as seen, unless sounds are off. Undoing it is
    // silent.
    if (updated.done && ref.read(appSoundsProvider)) {
      await ref
          .read(deviceBridgeProvider)
          .playDone(ref.read(doneSoundProvider));
    }

    // Flip in place first; re-order only after the strike has been seen.
    _show(_replacing(updated));
    await _syncDevice();
    await Future<void>.delayed(reorderDelay);
    if (!ref.mounted) return;
    _show(_sorted(_items));
  }

  /// Puts a calling task off for a few minutes. It settles back into place
  /// and rises again when the new time comes.
  Future<void> snooze(Todo todo) async {
    final written = await _write(todo);
    // Counted from now when the day is today. On another day there is no
    // "now" to count from, so it goes from its own time.
    final now = _now;
    final updated = written.snoozed(
      nowMinute: now.epochDay == _day ? now.hour * 60 + now.minute : null,
    );
    await _store.save(updated);
    if (!ref.mounted) return;
    _show(_sorted(_replacing(updated)));
    await _syncDevice();
  }

  /// Puts a calling task off until [minute] of the day.
  Future<void> snoozeUntil(Todo todo, int minute) async {
    final written = await _write(todo);
    final updated = written.snoozedUntil(minute);
    await _store.save(updated);
    if (!ref.mounted) return;
    _show(_sorted(_replacing(updated)));
    await _syncDevice();
  }

  /// Waves a calling task away for the day. It keeps its time, but stops
  /// asking.
  Future<void> dismiss(Todo todo) async {
    final written = await _write(todo);
    final updated = written.dismiss();
    await _store.save(updated);
    if (!ref.mounted) return;
    _show(_sorted(_replacing(updated)));
    await _syncDevice();
  }

  /// Pins a task to the head of its day, or lets it go. Like done, it is a
  /// thing of the day: a showing of a rule is written down and pinned for
  /// that day alone.
  Future<void> togglePin(Todo todo) async {
    final written = await _write(todo);
    final updated = written.withPinned(!written.pinned);
    await _store.save(updated);
    if (!ref.mounted) return;
    _show(_sorted(_replacing(updated)));
    await _syncDevice();
  }

  /// Applies an edit. Words, time and rule all belong to the series, so
  /// editing a repeating task changes every day it appears on. Says which
  /// task it is afterwards, by key: an edit can make a one-off of a rule or
  /// a rule of a one-off, and then it is not the task it was. Null when
  /// there were no words.
  Future<String?> apply(Todo todo, TaskDraft draft) async {
    if (!draft.body.hasWords) return null;

    var key = todo.key;
    if (todo.repeats && draft.repeat != null) {
      // The pin is the day's, not the rule's: this showing is written down
      // to take it, ahead of the words the series is about to be given.
      if (draft.pinned != todo.pinned) {
        await _store.save((await _write(todo)).withPinned(draft.pinned));
      }
      await _store.saveSeries(
        recurrenceId: todo.recurrenceId!,
        body: draft.body,
        rule: draft.repeat!,
        due: draft.due,
      );
    } else if (todo.repeats) {
      // Repeating no more: the series goes, and a one-off takes its place on
      // the day the editor was left on, where the task was.
      await _store.removeSeries(todo.recurrenceId!);
      final written = await _store.insert(
        day: draft.day,
        body: draft.body,
        due: draft.due,
        position: todo.position,
        pinned: draft.pinned,
      );
      key = written.key;
    } else if (draft.repeat != null) {
      // A one-off becomes a series starting on this day, where it was.
      await _store.remove(day: _day, todo: todo);
      final id = await _store.insertSeries(
        day: draft.day,
        body: draft.body,
        rule: draft.repeat!,
        due: draft.due,
        position: todo.position,
      );
      key = Todo.seriesKey(id);
      // A pin is a thing of the day, so the rule cannot hold it: its showing
      // on the day is written down to keep it.
      if (draft.pinned) await _keepPin(day: draft.day, key: key);
    } else {
      final saved = todo
          .withBody(draft.body)
          .withDue(draft.due)
          .withPinned(draft.pinned);
      await _store.save(saved);
      // A day picked in the editor sends it on, the same way Not today does.
      if (draft.day != _day) {
        await _store.moveToDay(fromDay: _day, toDay: draft.day, todo: saved);
      }
    }

    await _reload();
    return key;
  }

  /// Ticks or unticks one item on a task's checklist, from the read view.
  /// Like done, it is a thing of the day: a showing of a rule is written
  /// down and keeps its own ticks, and the series is not touched.
  Future<void> setBody(Todo todo, TaskBody body) async {
    final written = await _write(todo);
    final updated = written.withBody(body);
    await _store.save(updated);
    if (!ref.mounted) return;
    _show(_replacing(updated));
  }

  /// Ticks or unticks one item on a task's checklist, from the read view,
  /// which sends it to the foot of its list or back. A tick is heard the
  /// way done is, unless sounds are off; unticking is silent.
  Future<void> tick(Todo todo, int index) async {
    final ticked = !todo.body.blocks[index].checked;
    await setBody(todo, todo.body.ticked(index));
    if (!ref.mounted) return;
    if (ticked && ref.read(appSoundsProvider)) {
      await ref
          .read(deviceBridgeProvider)
          .playDone(ref.read(doneSoundProvider));
    }
  }

  /// Sends a task to another day. It leaves this list at once. Says which
  /// task it is there, by key: a rule's showing goes as a one-off copy.
  /// Null when it was going nowhere.
  Future<String?> moveToDay(Todo todo, int toDay) async {
    if (toDay == _day) return null;
    _show(_without(todo));
    final moved = await _store.moveToDay(
      fromDay: _day,
      toDay: toDay,
      todo: todo,
    );
    await _syncDevice();
    return moved.key;
  }

  /// Drops this showing only. A repeating task stays on its other days.
  Future<void> removeOccurrence(Todo todo) async {
    _show(_without(todo));
    await _store.remove(day: _day, todo: todo);
    await _syncDevice();
  }

  /// Drops this showing and every one before it, keeping the days after.
  Future<void> removeUpToHere(Todo todo) async {
    _show(_without(todo));
    await _store.startSeriesAfter(recurrenceId: todo.recurrenceId!, day: _day);
    await _syncDevice();
  }

  /// Drops this showing and every one after it, keeping the days before.
  Future<void> removeFromHere(Todo todo) async {
    _show(_without(todo));
    await _store.endSeriesFrom(recurrenceId: todo.recurrenceId!, day: _day);
    await _syncDevice();
  }

  /// Drops the whole repeating task, on every day.
  Future<void> removeSeries(Todo todo) async {
    _show(_without(todo));
    await _store.removeSeries(todo.recurrenceId!);
    await _syncDevice();
  }

  /// Moves an open task. Completed tasks hold their place at the bottom, and
  /// calling ones hold the top, so a drag that lands among either is clamped
  /// back into the band between. That band is two: the pinned, then the
  /// rest, and a task moves only within its own.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = _items;
    final firstDone = items.indexWhere((item) => item.done);
    final open = firstDone == -1 ? items.length : firstDone;
    final calling = items
        .takeWhile((item) => item.isCallingOn(day: _day, now: _now))
        .length;
    if (oldIndex < calling || oldIndex >= open) return;

    final pinnedEnd =
        calling +
        items.sublist(calling, open).where((item) => item.pinned).length;
    final (first, last) = items[oldIndex].pinned
        ? (calling, pinnedEnd - 1)
        : (pinnedEnd, open - 1);

    // newIndex already accounts for the item leaving its old slot.
    final target = newIndex.clamp(first, last);
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
    _show(<Todo>[...renumbered, ...items.sublist(open)]);
    await _store.reorder(renumbered);
  }

  /// Writes a projected occurrence down so it can carry state of its own.
  Future<Todo> _write(Todo todo) => todo.isStored
      ? Future.value(todo)
      : _store.materialize(day: _day, todo: todo);

  /// Writes down the showing of a new rule on [day], pinned, when the rule
  /// has one there.
  Future<void> _keepPin({required int day, required String key}) async {
    for (final shown in await _store.todosOn(day)) {
      if (shown.key != key) continue;
      await _store.materialize(day: day, todo: shown.withPinned(true));
    }
  }

  Future<void> _reload() async {
    final todos = await _store.todosOn(_day, now: _now);
    if (!ref.mounted) return;
    _show(todos);
    await _syncDevice();
  }

  /// After a write: the reminders, the icon's number and the widgets follow
  /// the store, and what is left from earlier days is read again.
  Future<void> _syncDevice() async {
    if (!ref.mounted) return;
    await ref.read(reminderSyncProvider).refresh(now: _now);
    if (!ref.mounted) return;
    await ref.read(glanceSyncProvider).refresh(now: _now);
    if (!ref.mounted) return;
    ref.invalidate(backlogProvider);
  }

  /// Puts a list on screen and sets the timer for the next task to rise.
  void _show(List<Todo> items) {
    state = AsyncData(items);
    _armFor(items);
  }

  /// Wakes at the next moment a task on this day starts calling, and
  /// brings it up.
  void _armFor(List<Todo> items) {
    _nextCall?.cancel();
    final now = _now;
    DateTime? next;
    for (final todo in items) {
      if (todo.done || todo.dismissed || todo.due == null) continue;
      final at = todo.due!.callInstantOn(_day);
      if (!at.isAfter(now)) continue;
      if (next == null || at.isBefore(next)) next = at;
    }
    if (next == null) return;
    _nextCall = Timer(next.difference(now), () {
      if (ref.mounted) _show(_sorted(_items));
    });
  }

  List<Todo> _sorted(List<Todo> items) =>
      <Todo>[...items]..sort(todoOrderOn(day: _day, now: _now));

  List<Todo> _replacing(Todo updated) => <Todo>[
    for (final item in _items) item.key == updated.key ? updated : item,
  ];

  List<Todo> _without(Todo gone) => <Todo>[
    for (final item in _items)
      if (item.key != gone.key) item,
  ];

  TodoStore get _store => ref.read(todoStoreProvider);

  DateTime get _now => ref.read(clockProvider)();

  List<Todo> get _items => state.value ?? const <Todo>[];
}
