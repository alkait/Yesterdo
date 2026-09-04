import 'package:sqflite/sqflite.dart';

import 'repeat_rule.dart';
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
  Future<Todo> insert({required int day, required String title}) async {
    final position = await _nextPosition(day);
    final draft = Todo(title: title, done: false, position: position);
    final id = await _db.insert(_todos, draft.toRow(day));
    return draft.stored(id);
  }

  @override
  Future<void> insertSeries({
    required int day,
    required String title,
    required RepeatRule rule,
  }) async {
    final position = await _nextPosition(day);
    await _db.insert(
      _recurrences,
      Recurrence.rowFor(title: title, rule: rule, position: position),
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
      'title': todo.title,
      'done': todo.done ? 1 : 0,
      'completed_at': todo.completedAt,
      'hidden': todo.hidden ? 1 : 0,
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
    required String title,
    required RepeatRule rule,
  }) async {
    await _db.update(
      _recurrences,
      <String, Object?>{
        'title': title,
        'kind': rule.kind.name,
        'weekdays': rule.weekdays,
        'month_days': rule.monthDays,
        'start_day': rule.startDay,
        'end_day': rule.endDay,
      },
      where: 'id = ?',
      whereArgs: [recurrenceId],
    );
    // Written-down occurrences carry their own copy of the words.
    await _db.update(
      _todos,
      <String, Object?>{'title': title},
      where: 'recurrence_id = ?',
      whereArgs: [recurrenceId],
    );
  }

  @override
  Future<List<Todo>> todosOn(int day) async => mergeDay(
    stored: await storedTodosOn(day),
    recurrences: await recurrencesFor(day),
    day: day,
  );

  Future<int> _nextPosition(int day) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(position) AS top FROM $_todos WHERE day = ?',
      [day],
    );
    return ((rows.first['top'] as int?) ?? -1) + 1;
  }
}
