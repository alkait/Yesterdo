import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/rich/task_body.dart';
import 'package:remind_me/data/search.dart';
import 'package:remind_me/data/sync_record.dart';
import 'package:remind_me/data/todo.dart';
import 'package:remind_me/data/todo_store.dart';

/// Test double for [TodoStore]. Completes synchronously so widget tests can
/// drive it with `pump` alone.
///
/// Pass [writeDelay] to make a write take real time, the way SQLite does.
/// Frames are drawn while it waits, so a test can see what the interface
/// does to a card that is on its way off the day.
///
/// Keeps a change log the way the shipping store does, so two of these
/// can be synced through a memory cloud and the merge watched.
class MemoryTodoStore implements TodoStore {
  MemoryTodoStore({
    this.writeDelay = Duration.zero,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock; // ignore: prefer_initializing_formals

  /// How long a write takes. Nothing by default.
  final Duration writeDelay;

  final DateTime Function() _clock;

  Future<void> _written() =>
      writeDelay == Duration.zero ? Future.value() : Future.delayed(writeDelay);

  final Map<int, List<Todo>> _byDay = <int, List<Todo>>{};
  final List<Recurrence> _recurrences = <Recurrence>[];

  /// Uids written since the last send, each marked whether the row is gone.
  final Map<String, bool> _pending = <String, bool>{};
  String? _token;
  int _nextTodoId = 1;
  int _nextRecurrenceId = 1;

  int get _now => _clock().millisecondsSinceEpoch;

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
    bool pinned = false,
    bool carryOver = false,
  }) {
    final todo = Todo(
      id: _nextTodoId++,
      body: TodoStore.bodyOf(title, body),
      done: false,
      position: position ?? _topPosition(day),
      due: due,
      pinned: pinned,
      carryOver: carryOver,
      uid: newUid(),
      updatedAt: _now,
    );
    _dayOf(day).add(todo);
    _log(todo.uid!);
    return Future.value(todo);
  }

  @override
  Future<int> insertSeries({
    required int day,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
    int? position,
  }) {
    final id = _nextRecurrenceId++;
    final recurrence = Recurrence(
      id: id,
      body: TodoStore.bodyOf(title, body),
      rule: rule,
      position: position ?? _topPosition(day),
      due: due,
      updatedAt: _now,
    );
    _recurrences.add(recurrence);
    _log(recurrence.uid);
    return Future.value(id);
  }

  @override
  Future<Todo> materialize({required int day, required Todo todo}) {
    if (todo.isStored) return Future.value(todo);
    final uid = todo.recurrenceUid == null
        ? newUid()
        : occurrenceUid(todo.recurrenceUid!, day);
    final written = todo.written(id: _nextTodoId++, uid: uid, at: _now);
    _dayOf(day).add(written);
    _log(uid);
    return Future.value(written);
  }

  @override
  Future<void> save(Todo todo) {
    final stamped = todo.touched(_now);
    for (final items in _byDay.values) {
      final index = items.indexWhere((each) => each.id == todo.id);
      if (index == -1) continue;
      items[index] = stamped.copyWith(uid: items[index].uid);
      _log(items[index].uid!);
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
      _dropTodos((each) => each.id == todo.id);
      return Future.value();
    }
    final hidden = todo.copyWith(hidden: true);
    return hidden.isStored
        ? save(hidden)
        : materialize(day: day, todo: hidden).then((_) {});
  }

  @override
  Future<Todo> moveToDay({
    required int fromDay,
    required int toDay,
    required Todo todo,
    bool toTop = false,
  }) async {
    await _written();
    final position = toTop ? _topPosition(toDay) : _nextPosition(toDay);
    if (todo.repeats) {
      await remove(day: fromDay, todo: todo);
      return insert(
        day: toDay,
        body: todo.body,
        due: todo.due,
        position: position,
        pinned: todo.pinned,
      );
    }
    final held = _dayOf(fromDay)
        .where((each) => each.id == todo.id)
        .firstOrNull;
    _dayOf(fromDay).removeWhere((each) => each.id == todo.id);
    final moved = todo
        .repositioned(position)
        .copyWith(
          dismissed: false,
          uid: held?.uid ?? todo.uid,
          updatedAt: _now,
        );
    _dayOf(toDay).add(moved);
    if (moved.uid != null) _log(moved.uid!);
    return moved;
  }

  @override
  Future<void> removeSeries(int recurrenceId) {
    _dropTodos((each) => each.recurrenceId == recurrenceId);
    for (final each in _recurrences) {
      if (each.id == recurrenceId) _pending[each.uid] = true;
    }
    _recurrences.removeWhere((each) => each.id == recurrenceId);
    return Future.value();
  }

  @override
  Future<void> endSeriesFrom({required int recurrenceId, required int day}) {
    final index = _recurrences.indexWhere((each) => each.id == recurrenceId);
    if (index == -1) return Future.value();

    final existing = _recurrences[index];
    if (day <= existing.rule.startDay) return removeSeries(recurrenceId);

    _dropTodos(
      (each) => each.recurrenceId == recurrenceId,
      onDays: (at) => at >= day,
    );
    _putRule(
      index,
      existing.copyWith(rule: existing.rule.copyWith(endDay: day - 1)),
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

    _dropTodos(
      (each) => each.recurrenceId == recurrenceId,
      onDays: (at) => at <= day,
    );
    _putRule(
      index,
      existing.copyWith(rule: existing.rule.copyWith(startDay: day + 1)),
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
      _putRule(
        index,
        _recurrences[index].copyWith(
          body: words,
          rule: rule,
          due: due,
          clearDue: due == null,
        ),
      );
    }
    for (final items in _byDay.values) {
      for (var at = 0; at < items.length; at++) {
        if (items[at].recurrenceId == recurrenceId) {
          items[at] = items[at]
              .withBody(words.withTicksOf(items[at].body))
              .copyWith(
                due: due,
                clearDue: due == null,
                dismissed: false,
                updatedAt: _now,
              );
          _log(items[at].uid!);
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
  Future<List<Todo>> carryForward({required int today}) =>
      composeCarryForward(this, today: today);

  @override
  Future<Map<int, List<Todo>>> daysAhead({
    required int today,
    required int last,
  }) => composeDaysAhead(this, today: today, last: last);

  @override
  Future<void> ignoreMissed({required int recurrenceId, required int day}) {
    final index = _recurrences.indexWhere((each) => each.id == recurrenceId);
    if (index == -1) return Future.value();
    final known = _recurrences[index].ignoredThrough;
    if (known == null || known < day) {
      _putRule(index, _recurrences[index].copyWith(ignoredThrough: day));
    }
    return Future.value();
  }

  @override
  Future<Map<int, int>> ignoredMissed() => Future.value({
    for (final each in _recurrences)
      if (each.ignoredThrough != null) each.id: each.ignoredThrough!,
  });

  @override
  Future<List<CarriedTask>> leftToCarryBefore(int day) {
    final days = _byDay.keys.where((each) => each < day).toList()..sort();
    return Future.value([
      for (final each in days)
        for (final todo in [
          ..._byDay[each]!,
        ]..sort((a, b) => a.position.compareTo(b.position)))
          if (todo.carries) CarriedTask(day: each, todo: todo),
    ]);
  }

  @override
  Future<List<SearchHit>> oneOffsMatching(String query) => Future.value([
    for (final entry in _byDay.entries)
      for (final todo in entry.value)
        if (!todo.hidden && !todo.repeats && matchesSearch(todo.title, query))
          SearchHit(day: entry.key, todo: todo),
  ]);

  @override
  Future<List<Recurrence>> recurrencesMatching(String query) => Future.value([
    for (final each in _recurrences)
      if (matchesSearch(each.title, query)) each,
  ]);

  @override
  Future<List<SearchHit>> search(String query, {required int today}) async =>
      query.trim().isEmpty
      ? const []
      : composeSearch(
          oneOffs: await oneOffsMatching(query),
          recurrences: await recurrencesMatching(query),
          today: today,
        );

  @override
  Future<Set<String>> allImages() => Future.value({
    for (final items in _byDay.values)
      for (final todo in items) ...todo.body.images,
    for (final each in _recurrences) ...each.body.images,
  });

  @override
  Future<SeriesRows?> readSeries(int recurrenceId) {
    final recurrence = _recurrences
        .where((each) => each.id == recurrenceId)
        .firstOrNull;
    if (recurrence == null) return Future.value();
    return Future.value(
      SeriesRows(
        recurrence: recurrence,
        byDay: {
          for (final entry in _byDay.entries)
            for (final todo in entry.value)
              if (todo.recurrenceId == recurrenceId) entry.key: todo,
        },
      ),
    );
  }

  // Sync.

  /// The uids still to be sent, for a test to look at.
  Set<String> get pendingUids => _pending.keys.toSet();

  @override
  Future<SyncBatch> pendingChanges() {
    final changed = <SyncRecord>[];
    final deleted = <String>[];
    for (final MapEntry(key: uid, value: gone) in _pending.entries) {
      if (gone) {
        deleted.add(uid);
        continue;
      }
      final record = _recordFor(uid);
      if (record != null) changed.add(record);
    }
    return Future.value(
      SyncBatch(changed: rulesFirst(changed), deleted: deleted),
    );
  }

  @override
  Future<void> clearPending(SyncBatch sent) {
    for (final uid in sent.deleted) {
      if (_pending[uid] == true) _pending.remove(uid);
    }
    for (final record in sent.changed) {
      if (_pending[record.uid] == false &&
          _recordFor(record.uid)?.updatedAt == record.updatedAt) {
        _pending.remove(record.uid);
      }
    }
    return Future.value();
  }

  @override
  Future<void> markAllPending() {
    _pending.clear();
    for (final items in _byDay.values) {
      for (final todo in items) {
        _pending[todo.uid!] = false;
      }
    }
    for (final each in _recurrences) {
      _pending[each.uid] = false;
    }
    return Future.value();
  }

  @override
  Future<bool> applyRemote(SyncBatch incoming) {
    var changed = false;
    for (final uid in incoming.deleted) {
      _pending.remove(uid);
      final before = _count;
      _dropTodos((each) => each.uid == uid, silently: true);
      for (final rule
          in _recurrences.where((each) => each.uid == uid).toList()) {
        _dropTodos((each) => each.recurrenceId == rule.id, silently: true);
        _recurrences.remove(rule);
      }
      changed |= _count != before;
    }
    for (final record in rulesFirst(incoming.changed)) {
      if (!takesIncoming(
        _localState(record.uid),
        updatedAt: record.updatedAt,
      )) {
        continue;
      }
      changed |= switch (record.kind) {
        SyncKind.rule => _takeRule(record),
        SyncKind.todo => _takeTodo(record),
      };
    }
    return Future.value(changed);
  }

  @override
  Future<String?> syncToken() => Future.value(_token);

  @override
  Future<void> setSyncToken(String? token) {
    _token = token;
    return Future.value();
  }

  bool _takeRule(SyncRecord record) {
    final index = _recurrences.indexWhere((each) => each.uid == record.uid);
    final id = index == -1 ? _nextRecurrenceId++ : _recurrences[index].id;
    final taken = Recurrence.fromRow({
      ...record.fields,
      'id': id,
      'uid': record.uid,
      'updated_at': record.updatedAt,
    });
    if (index == -1) {
      _recurrences.add(taken);
    } else {
      _recurrences[index] = taken;
    }
    _pending.remove(record.uid);
    return true;
  }

  bool _takeTodo(SyncRecord record) {
    final ruleUid = record.fields['recurrence_uid'] as String?;
    int? recurrenceId;
    if (ruleUid != null) {
      final rule = _recurrences
          .where((each) => each.uid == ruleUid)
          .firstOrNull;
      if (rule == null) return false;
      recurrenceId = rule.id;
    }
    final held = _find(record.uid);
    final taken = Todo.fromRow({
      ...record.fields,
      'id': held?.todo.id ?? _nextTodoId++,
      'recurrence_id': recurrenceId,
      'uid': record.uid,
      'updated_at': record.updatedAt,
    });
    _dropTodos((each) => each.uid == record.uid, silently: true);
    _dayOf(record.fields['day']! as int).add(taken);
    _pending.remove(record.uid);
    return true;
  }

  LocalState _localState(String uid) {
    final gone = _pending[uid];
    final updatedAt =
        _find(uid)?.todo.updatedAt ??
        _recurrences.where((each) => each.uid == uid).firstOrNull?.updatedAt;
    return LocalState(
      updatedAt: updatedAt,
      pending: gone != null,
      deleted: gone == true,
    );
  }

  SyncRecord? _recordFor(String uid) {
    final held = _find(uid);
    if (held != null) {
      return SyncRecord(
        kind: SyncKind.todo,
        uid: uid,
        updatedAt: held.todo.updatedAt,
        fields: held.todo.toSyncFields(held.day),
      );
    }
    final rule = _recurrences.where((each) => each.uid == uid).firstOrNull;
    if (rule == null) return null;
    return SyncRecord(
      kind: SyncKind.rule,
      uid: uid,
      updatedAt: rule.updatedAt,
      fields: rule.toSyncFields(),
    );
  }

  CarriedTask? _find(String uid) {
    for (final entry in _byDay.entries) {
      for (final todo in entry.value) {
        if (todo.uid == uid) return CarriedTask(day: entry.key, todo: todo);
      }
    }
    return null;
  }

  int get _count =>
      _recurrences.length +
      _byDay.values.fold(0, (sum, items) => sum + items.length);

  void _log(String uid) => _pending[uid] = false;

  /// Takes rows out, leaving a tombstone for each unless [silently].
  void _dropTodos(
    bool Function(Todo) test, {
    bool Function(int day)? onDays,
    bool silently = false,
  }) {
    for (final MapEntry(key: day, value: items) in _byDay.entries) {
      if (onDays != null && !onDays(day)) continue;
      for (final todo in items.where(test).toList()) {
        if (!silently && todo.uid != null) _pending[todo.uid!] = true;
        items.remove(todo);
      }
    }
  }

  void _putRule(int index, Recurrence rule) {
    _recurrences[index] = rule.copyWith(updatedAt: _now);
    _log(rule.uid);
  }

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
