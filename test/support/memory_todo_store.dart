import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/data/todo.dart';
import 'package:remind_me/data/todo_store.dart';

/// Test double for [TodoStore]. Completes synchronously so widget tests can
/// drive it with `pump` alone.
class MemoryTodoStore implements TodoStore {
  final Map<int, List<Todo>> _byDay = <int, List<Todo>>{};
  final List<Recurrence> _recurrences = <Recurrence>[];
  final Map<int, int> _ignored = <int, int>{};
  int _nextTodoId = 1;
  int _nextRecurrenceId = 1;

  @override
  Future<List<Todo>> storedTodosOn(int day) =>
      Future.value(<Todo>[...?_byDay[day]]);

  @override
  Future<List<Recurrence>> recurrencesFor(int day) => Future.value(
    _recurrences
        .where(
          (each) =>
              each.rule.startDay <= day &&
              (each.rule.endDay == null || each.rule.endDay! >= day),
        )
        .toList(),
  );

  @override
  Future<Todo> insert({
    required int day,
    String? title,
    TaskBody? body,
    Due? due,
    int? position,
  }) {
    final todo = Todo(
      id: _nextTodoId++,
      body: TodoStore.bodyOf(title, body),
      done: false,
      position: position ?? _topPosition(day),
      due: due,
    );
    _dayOf(day).add(todo);
    return Future.value(todo);
  }

  @override
  Future<void> insertSeries({
    required int day,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
    int? position,
  }) {
    _recurrences.add(
      Recurrence(
        id: _nextRecurrenceId++,
        body: TodoStore.bodyOf(title, body),
        rule: rule,
        position: position ?? _topPosition(day),
        due: due,
      ),
    );
    return Future.value();
  }

  @override
  Future<Todo> materialize({required int day, required Todo todo}) {
    if (todo.isStored) return Future.value(todo);
    final written = todo.stored(_nextTodoId++);
    _dayOf(day).add(written);
    return Future.value(written);
  }

  @override
  Future<void> save(Todo todo) {
    for (final items in _byDay.values) {
      final index = items.indexWhere((each) => each.id == todo.id);
      if (index != -1) items[index] = todo;
    }
    return Future.value();
  }

  @override
  Future<void> reorder(List<Todo> ordered) {
    for (var index = 0; index < ordered.length; index++) {
      save(ordered[index].repositioned(index));
    }
    return Future.value();
  }

  @override
  Future<void> remove({required int day, required Todo todo}) {
    if (!todo.repeats) {
      for (final items in _byDay.values) {
        items.removeWhere((each) => each.id == todo.id);
      }
      return Future.value();
    }
    final hidden = todo.copyWith(hidden: true);
    return hidden.isStored
        ? save(hidden)
        : materialize(day: day, todo: hidden).then((_) {});
  }

  @override
  Future<void> moveToDay({
    required int fromDay,
    required int toDay,
    required Todo todo,
    bool toTop = false,
  }) async {
    final position = toTop ? _topPosition(toDay) : _nextPosition(toDay);
    if (todo.repeats) {
      await remove(day: fromDay, todo: todo);
      await insert(
        day: toDay,
        body: todo.body,
        due: todo.due,
        position: position,
      );
      return;
    }
    _dayOf(fromDay).removeWhere((each) => each.id == todo.id);
    _dayOf(toDay).add(todo.repositioned(position).copyWith(dismissed: false));
  }

  @override
  Future<void> removeSeries(int recurrenceId) {
    for (final items in _byDay.values) {
      items.removeWhere((each) => each.recurrenceId == recurrenceId);
    }
    _recurrences.removeWhere((each) => each.id == recurrenceId);
    _ignored.remove(recurrenceId);
    return Future.value();
  }

  @override
  Future<void> endSeriesFrom({required int recurrenceId, required int day}) {
    final index = _recurrences.indexWhere((each) => each.id == recurrenceId);
    if (index == -1) return Future.value();

    final existing = _recurrences[index];
    if (day <= existing.rule.startDay) return removeSeries(recurrenceId);

    for (final entry in _byDay.entries) {
      if (entry.key >= day) {
        entry.value.removeWhere((each) => each.recurrenceId == recurrenceId);
      }
    }
    _recurrences[index] = Recurrence(
      id: existing.id,
      body: existing.body,
      position: existing.position,
      due: existing.due,
      rule: existing.rule.copyWith(endDay: day - 1),
    );
    return Future.value();
  }

  @override
  Future<void> startSeriesAfter({required int recurrenceId, required int day}) {
    final index = _recurrences.indexWhere((each) => each.id == recurrenceId);
    if (index == -1) return Future.value();

    final existing = _recurrences[index];
    final endDay = existing.rule.endDay;
    if (endDay != null && day >= endDay) return removeSeries(recurrenceId);

    for (final entry in _byDay.entries) {
      if (entry.key <= day) {
        entry.value.removeWhere((each) => each.recurrenceId == recurrenceId);
      }
    }
    _recurrences[index] = Recurrence(
      id: existing.id,
      body: existing.body,
      position: existing.position,
      due: existing.due,
      rule: existing.rule.copyWith(startDay: day + 1),
    );
    return Future.value();
  }

  @override
  Future<void> saveSeries({
    required int recurrenceId,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
  }) {
    final words = TodoStore.bodyOf(title, body);
    final index = _recurrences.indexWhere((each) => each.id == recurrenceId);
    if (index != -1) {
      _recurrences[index] = Recurrence(
        id: recurrenceId,
        body: words,
        rule: rule,
        position: _recurrences[index].position,
        due: due,
      );
    }
    for (final items in _byDay.values) {
      for (var at = 0; at < items.length; at++) {
        if (items[at].recurrenceId == recurrenceId) {
          items[at] = items[at]
              .withBody(words)
              .copyWith(due: due, clearDue: due == null, dismissed: false);
        }
      }
    }
    return Future.value();
  }

  @override
  Future<List<Todo>> todosOn(int day, {DateTime? now}) async => mergeDay(
    stored: await storedTodosOn(day),
    recurrences: await recurrencesFor(day),
    day: day,
    now: now,
  );

  @override
  Future<void> ignoreMissed({required int recurrenceId, required int day}) {
    final known = _ignored[recurrenceId];
    if (known == null || known < day) _ignored[recurrenceId] = day;
    return Future.value();
  }

  @override
  Future<Map<int, int>> ignoredMissed() =>
      Future.value(Map<int, int>.of(_ignored));

  @override
  Future<Set<String>> allImages() => Future.value({
    for (final items in _byDay.values)
      for (final todo in items) ...todo.body.images,
    for (final each in _recurrences) ...each.body.images,
  });

  List<Todo> _dayOf(int day) => _byDay.putIfAbsent(day, () => <Todo>[]);

  List<int> _taken(int day) => <int>[
    for (final todo in _dayOf(day)) todo.position,
    for (final each in _recurrences)
      if (each.rule.fallsOn(day)) each.position,
  ];

  int _topPosition(int day) {
    final taken = _taken(day);
    return taken.isEmpty ? 0 : taken.reduce((a, b) => a < b ? a : b) - 1;
  }

  int _nextPosition(int day) {
    final taken = _taken(day);
    return taken.isEmpty ? 0 : taken.reduce((a, b) => a > b ? a : b) + 1;
  }
}
