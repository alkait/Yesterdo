import 'package:sqflite/sqflite.dart';

import 'due.dart';
import 'repeat_rule.dart';
import 'rich/task_body.dart';
import 'todo.dart';
import 'todo_store.dart';

/// The shipping store: a single SQLite file on the device.
class SqliteTodoStore implements TodoStore {
  const SqliteTodoStore(this._db);

  static const _todos = 'todos';
  static const _recurrences = 'recurrences';

  final Database _db;

  @override
  Future<List<Todo>> storedTodosOn(int day) async {
    final rows = await _db.query(_todos, where: 'day = ?', whereArgs: [day]);
    return rows.map(Todo.fromRow).toList();
  }

  @override
  Future<List<Recurrence>> recurrencesFor(int day) async {
    final rows = await _db.query(
      _recurrences,
      where: 'start_day <= ? AND (end_day IS NULL OR end_day >= ?)',
      whereArgs: [day, day],
    );
    return rows.map(Recurrence.fromRow).toList();
  }

  @override
  Future<Todo> insert({
    required int day,
    String? title,
    TaskBody? body,
    Due? due,
    int? position,
  }) async {
    position ??= await _topPosition(day);
    final draft = Todo(
      body: TodoStore.bodyOf(title, body),
      done: false,
      position: position,
      due: due,
    );
    final id = await _db.insert(_todos, draft.toRow(day));
    return draft.stored(id);
  }

  @override
  Future<void> insertSeries({
    required int day,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
    int? position,
  }) async {
    position ??= await _topPosition(day);
    await _db.insert(
      _recurrences,
      Recurrence.rowFor(
        body: TodoStore.bodyOf(title, body),
        rule: rule,
        position: position,
        due: due,
      ),
    );
  }

  @override
  Future<Todo> materialize({required int day, required Todo todo}) async {
    if (todo.isStored) return todo;
    final id = await _db.insert(
      _todos,
      todo.toRow(day),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return todo.stored(id);
  }

  @override
  Future<void> save(Todo todo) => _db.update(
    _todos,
    <String, Object?>{
      ...Todo.bodyColumns(todo.body),
      'done': todo.done ? 1 : 0,
      'completed_at': todo.completedAt,
      'hidden': todo.hidden ? 1 : 0,
      ...todo.due?.toRow() ?? Due.emptyRow,
      'dismissed': todo.dismissed ? 1 : 0,
    },
    where: 'id = ?',
    whereArgs: [todo.id],
  );

  @override
  Future<void> reorder(List<Todo> ordered) async {
    final batch = _db.batch();
    for (var index = 0; index < ordered.length; index++) {
      batch.update(
        _todos,
        <String, Object?>{'position': index},
        where: 'id = ?',
        whereArgs: [ordered[index].id],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> remove({required int day, required Todo todo}) async {
    if (!todo.repeats) {
      await _db.delete(_todos, where: 'id = ?', whereArgs: [todo.id]);
      return;
    }
    // A rule cannot be unwritten for one day, so the day gets a hidden row.
    final hidden = todo.copyWith(hidden: true);
    if (hidden.isStored) {
      await save(hidden);
    } else {
      await materialize(day: day, todo: hidden);
    }
  }

  @override
  Future<void> moveToDay({
    required int fromDay,
    required int toDay,
    required Todo todo,
    bool toTop = false,
  }) async {
    final position = toTop
        ? await _topPosition(toDay)
        : await _nextPosition(toDay);
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
    // A new day is a new call, so a wave-away from the old one no longer
    // holds.
    await _db.update(
      _todos,
      <String, Object?>{'day': toDay, 'position': position, 'dismissed': 0},
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  @override
  Future<void> removeSeries(int recurrenceId) async {
    await _db.delete(
      _todos,
      where: 'recurrence_id = ?',
      whereArgs: [recurrenceId],
    );
    await _db.delete(_recurrences, where: 'id = ?', whereArgs: [recurrenceId]);
  }

  @override
  Future<void> endSeriesFrom({
    required int recurrenceId,
    required int day,
  }) async {
    final rows = await _db.query(
      _recurrences,
      columns: ['start_day'],
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
    final startDay = rows.isEmpty ? null : rows.first['start_day'] as int;
    if (startDay == null || day <= startDay) {
      // Nothing would be left of it.
      await removeSeries(recurrenceId);
      return;
    }

    await _db.delete(
      _todos,
      where: 'recurrence_id = ? AND day >= ?',
      whereArgs: [recurrenceId, day],
    );
    await _db.update(
      _recurrences,
      <String, Object?>{'end_day': day - 1},
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
  }

  @override
  Future<void> startSeriesAfter({
    required int recurrenceId,
    required int day,
  }) async {
    final rows = await _db.query(
      _recurrences,
      columns: ['end_day'],
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
    if (rows.isEmpty) return;
    final endDay = rows.first['end_day'] as int?;
    if (endDay != null && day >= endDay) {
      // Nothing would be left of it.
      await removeSeries(recurrenceId);
      return;
    }

    await _db.delete(
      _todos,
      where: 'recurrence_id = ? AND day <= ?',
      whereArgs: [recurrenceId, day],
    );
    await _db.update(
      _recurrences,
      <String, Object?>{'start_day': day + 1},
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
  }

  @override
  Future<void> saveSeries({
    required int recurrenceId,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
  }) async {
    final words = TodoStore.bodyOf(title, body);
    await _db.update(
      _recurrences,
      <String, Object?>{
        ...Todo.bodyColumns(words),
        ...Recurrence.ruleColumns(rule),
        ...due?.toRow() ?? Due.emptyRow,
      },
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
    // Written-down occurrences carry their own copy of the words and the
    // time. A new time is a new call, so a wave-away no longer holds.
    await _db.update(
      _todos,
      <String, Object?>{
        ...Todo.bodyColumns(words),
        ...due?.toRow() ?? Due.emptyRow,
        'dismissed': 0,
      },
      where: 'recurrence_id = ?',
      whereArgs: [recurrenceId],
    );
  }

  @override
  Future<List<Todo>> todosOn(int day, {DateTime? now}) async => mergeDay(
    stored: await storedTodosOn(day),
    recurrences: await recurrencesFor(day),
    day: day,
    now: now,
  );

  @override
  Future<void> ignoreMissed({
    required int recurrenceId,
    required int day,
  }) async {
    // Only ever forwards, so an entry read before an older one was ignored
    // cannot uncover days again.
    await _db.rawUpdate(
      'UPDATE $_recurrences SET ignored_through = '
      'MAX(COALESCE(ignored_through, ?), ?) WHERE id = ?',
      [day, day, recurrenceId],
    );
  }

  @override
  Future<Map<int, int>> ignoredMissed() async {
    final rows = await _db.query(
      _recurrences,
      columns: ['id', 'ignored_through'],
      where: 'ignored_through IS NOT NULL',
    );
    return <int, int>{
      for (final row in rows) row['id']! as int: row['ignored_through']! as int,
    };
  }

  @override
  Future<Set<String>> allImages() async {
    final wanted = <String>{};
    for (final table in [_todos, _recurrences]) {
      final rows = await _db.query(
        table,
        columns: ['body'],
        where: 'body IS NOT NULL',
      );
      for (final row in rows) {
        wanted.addAll(TaskBody.decode(row['body']! as String).images);
      }
    }
    return wanted;
  }

  @override
  Future<SeriesRows?> readSeries(int recurrenceId) async {
    final rules = await _db.query(
      _recurrences,
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
    if (rules.isEmpty) return null;
    final rows = await _db.query(
      _todos,
      where: 'recurrence_id = ?',
      whereArgs: [recurrenceId],
    );
    return SeriesRows(
      recurrence: Recurrence.fromRow(rules.single),
      byDay: {for (final row in rows) row['day']! as int: Todo.fromRow(row)},
    );
  }

  /// Above everything on the day, rows and rules alike. Positions may go
  /// negative; only their order means anything.
  Future<int> _topPosition(int day) async {
    final rows = await _db.rawQuery(
      'SELECT MIN(position) AS top FROM $_todos WHERE day = ?',
      [day],
    );
    var top = rows.first['top'] as int?;
    for (final rule in await recurrencesFor(day)) {
      if (rule.fallsOn(day) && (top == null || rule.position < top)) {
        top = rule.position;
      }
    }
    return (top ?? 1) - 1;
  }

  /// Below everything on the day, for a task sent here from another day.
  Future<int> _nextPosition(int day) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(position) AS top FROM $_todos WHERE day = ?',
      [day],
    );
    return ((rows.first['top'] as int?) ?? -1) + 1;
  }
}
