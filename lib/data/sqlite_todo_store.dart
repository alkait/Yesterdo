import 'package:sqflite/sqflite.dart';

import 'due.dart';
import 'repeat_rule.dart';
import 'rich/task_body.dart';
import 'search.dart';
import 'sync_record.dart';
import 'todo.dart';
import 'todo_store.dart';

/// The shipping store: a single SQLite file on the device.
///
/// Every write stamps the row with the moment and logs its uid in
/// `sync_changes`, so the cloud can be told of it later; a removal logs a
/// tombstone there instead. The [clock] is what the stamp reads.
class SqliteTodoStore implements TodoStore {
  const SqliteTodoStore(this._db, {DateTime Function() clock = DateTime.now})
    : _clock = clock; // ignore: prefer_initializing_formals

  static const _todos = 'todos';
  static const _recurrences = 'recurrences';
  static const _changes = 'sync_changes';
  static const _state = 'sync_state';
  static const _tokenKey = 'token';

  final Database _db;
  final DateTime Function() _clock;

  int get _now => _clock().millisecondsSinceEpoch;

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
    bool pinned = false,
    bool carryOver = false,
  }) async {
    position ??= await _topPosition(day);
    final at = _now;
    final draft = Todo(
      body: TodoStore.bodyOf(title, body),
      done: false,
      position: position,
      due: due,
      pinned: pinned,
      carryOver: carryOver,
      uid: newUid(),
      updatedAt: at,
    );
    final id = await _db.insert(_todos, draft.toRow(day));
    await _log(draft.uid!, SyncKind.todo);
    return draft.stored(id);
  }

  @override
  Future<int> insertSeries({
    required int day,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
    int? position,
  }) async {
    position ??= await _topPosition(day);
    final uid = newUid();
    final id = await _db.insert(_recurrences, <String, Object?>{
      ...Recurrence.rowFor(
        body: TodoStore.bodyOf(title, body),
        rule: rule,
        position: position,
        due: due,
      ),
      'uid': uid,
      'updated_at': _now,
    });
    await _log(uid, SyncKind.rule);
    return id;
  }

  @override
  Future<Todo> materialize({required int day, required Todo todo}) async {
    if (todo.isStored) return todo;
    final uid = todo.recurrenceUid == null
        ? newUid()
        : occurrenceUid(todo.recurrenceUid!, day);
    final stamped = todo.copyWith(uid: uid, updatedAt: _now);
    final id = await _db.insert(
      _todos,
      stamped.toRow(day),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _log(uid, SyncKind.todo);
    return stamped.stored(id);
  }

  @override
  Future<void> save(Todo todo) async {
    await _db.update(
      _todos,
      <String, Object?>{
        ...Todo.bodyColumns(todo.body),
        'done': todo.done ? 1 : 0,
        'completed_at': todo.completedAt,
        'hidden': todo.hidden ? 1 : 0,
        ...todo.due?.toRow() ?? Due.emptyRow,
        'dismissed': todo.dismissed ? 1 : 0,
        'pinned': todo.pinned ? 1 : 0,
        'carry_over': todo.carryOver ? 1 : 0,
        'updated_at': _now,
      },
      where: 'id = ?',
      whereArgs: [todo.id],
    );
    await _logTodoRows(where: 'id = ?', whereArgs: [todo.id]);
  }

  @override
  Future<void> reorder(List<Todo> ordered) async {
    final at = _now;
    final batch = _db.batch();
    for (var index = 0; index < ordered.length; index++) {
      batch.update(
        _todos,
        <String, Object?>{'position': index, 'updated_at': at},
        where: 'id = ?',
        whereArgs: [ordered[index].id],
      );
    }
    await batch.commit(noResult: true);
    final ids = ordered.map((each) => each.id).toList();
    await _logTodoRows(
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  @override
  Future<void> remove({required int day, required Todo todo}) async {
    if (!todo.repeats) {
      await _deleteTodos(where: 'id = ?', whereArgs: [todo.id]);
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
  Future<Todo> moveToDay({
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
      return insert(
        day: toDay,
        body: todo.body,
        due: todo.due,
        position: position,
        pinned: todo.pinned,
      );
    }
    // A new day is a new call, so a wave-away from the old one no longer
    // holds.
    final at = _now;
    await _db.update(
      _todos,
      <String, Object?>{
        'day': toDay,
        'position': position,
        'dismissed': 0,
        'updated_at': at,
      },
      where: 'id = ?',
      whereArgs: [todo.id],
    );
    await _logTodoRows(where: 'id = ?', whereArgs: [todo.id]);
    return todo
        .repositioned(position)
        .copyWith(dismissed: false, updatedAt: at);
  }

  @override
  Future<void> removeSeries(int recurrenceId) async {
    await _deleteTodos(where: 'recurrence_id = ?', whereArgs: [recurrenceId]);
    await _deleteRecurrence(recurrenceId);
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

    await _deleteTodos(
      where: 'recurrence_id = ? AND day >= ?',
      whereArgs: [recurrenceId, day],
    );
    await _updateRecurrence(recurrenceId, {'end_day': day - 1});
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

    await _deleteTodos(
      where: 'recurrence_id = ? AND day <= ?',
      whereArgs: [recurrenceId, day],
    );
    await _updateRecurrence(recurrenceId, {'start_day': day + 1});
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
    await _updateRecurrence(recurrenceId, {
      ...Todo.bodyColumns(words.unticked()),
      ...Recurrence.ruleColumns(rule),
      ...due?.toRow() ?? Due.emptyRow,
    });
    // Written-down occurrences carry their own copy of the words and the
    // time, each with its own ticks. A new time is a new call, so a
    // wave-away no longer holds.
    final rows = await _db.query(
      _todos,
      columns: ['id', 'title', 'body'],
      where: 'recurrence_id = ?',
      whereArgs: [recurrenceId],
    );
    final at = _now;
    final batch = _db.batch();
    for (final row in rows) {
      batch.update(
        _todos,
        <String, Object?>{
          ...Todo.bodyColumns(words.withTicksOf(Todo.bodyFromRow(row))),
          ...due?.toRow() ?? Due.emptyRow,
          'dismissed': 0,
          'updated_at': at,
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await batch.commit(noResult: true);
    await _logTodoRows(where: 'recurrence_id = ?', whereArgs: [recurrenceId]);
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
  Future<void> ignoreMissed({
    required int recurrenceId,
    required int day,
  }) async {
    // Only ever forwards, so an entry read before an older one was ignored
    // cannot uncover days again.
    await _db.rawUpdate(
      'UPDATE $_recurrences SET ignored_through = '
      'MAX(COALESCE(ignored_through, ?), ?), updated_at = ? WHERE id = ?',
      [day, day, _now, recurrenceId],
    );
    await _logRecurrence(recurrenceId);
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
  Future<List<CarriedTask>> leftToCarryBefore(int day) async {
    final rows = await _db.query(
      _todos,
      where:
          'carry_over = 1 AND done = 0 AND hidden = 0 '
          'AND recurrence_id IS NULL AND day < ?',
      whereArgs: [day],
      orderBy: 'day, position',
    );
    return [
      for (final row in rows)
        CarriedTask(day: row['day']! as int, todo: Todo.fromRow(row)),
    ];
  }

  /// `LIKE` narrows the read to rows that could answer; it is case-blind
  /// only for ASCII, so [matchesSearch] has the final word on each.
  @override
  Future<List<SearchHit>> oneOffsMatching(String query) async {
    final rows = await _db.query(
      _todos,
      where:
          'hidden = 0 AND recurrence_id IS NULL '
          "AND title LIKE ? ESCAPE '$likeEscape'",
      whereArgs: [likePattern(query)],
    );
    return [
      for (final row in rows)
        if (matchesSearch(row['title']! as String, query))
          SearchHit(day: row['day']! as int, todo: Todo.fromRow(row)),
    ];
  }

  @override
  Future<List<Recurrence>> recurrencesMatching(String query) async {
    final rows = await _db.query(
      _recurrences,
      where: "title LIKE ? ESCAPE '$likeEscape'",
      whereArgs: [likePattern(query)],
    );
    return [
      for (final row in rows)
        if (matchesSearch(row['title']! as String, query))
          Recurrence.fromRow(row),
    ];
  }

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

  // Sync: what is to be sent, and taking in what was sent here.

  @override
  Future<SyncBatch> pendingChanges() async {
    final logged = await _db.query(_changes);
    final changed = <SyncRecord>[];
    final deleted = <String>[];
    final stale = <String>[];
    for (final entry in logged) {
      final uid = entry['uid']! as String;
      if ((entry['deleted'] as int) == 1) {
        deleted.add(uid);
        continue;
      }
      final record = await _recordFor(
        SyncKind.values.byName(entry['kind']! as String),
        uid,
      );
      if (record == null) {
        // Logged, then overwritten by a row with another uid. Nothing to say.
        stale.add(uid);
      } else {
        changed.add(record);
      }
    }
    for (final uid in stale) {
      await _db.delete(_changes, where: 'uid = ?', whereArgs: [uid]);
    }
    return SyncBatch(changed: rulesFirst(changed), deleted: deleted);
  }

  @override
  Future<void> clearPending(SyncBatch sent) async {
    for (final uid in sent.deleted) {
      await _db.delete(
        _changes,
        where: 'uid = ? AND deleted = 1',
        whereArgs: [uid],
      );
    }
    for (final record in sent.changed) {
      // A write that landed while the send was out keeps its place in the
      // log, since the row is no longer what was sent.
      final table = record.kind == SyncKind.todo ? _todos : _recurrences;
      final rows = await _db.query(
        table,
        columns: ['updated_at'],
        where: 'uid = ?',
        whereArgs: [record.uid],
      );
      if (rows.isEmpty) continue;
      if (rows.single['updated_at'] as int != record.updatedAt) continue;
      await _db.delete(
        _changes,
        where: 'uid = ? AND deleted = 0',
        whereArgs: [record.uid],
      );
    }
  }

  @override
  Future<void> markAllPending() async {
    await _db.delete(_changes);
    await _db.execute(
      "INSERT INTO $_changes (uid, kind) SELECT uid, 'todo' FROM $_todos",
    );
    await _db.execute(
      "INSERT INTO $_changes (uid, kind) SELECT uid, 'rule' FROM $_recurrences",
    );
  }

  @override
  Future<bool> applyRemote(SyncBatch incoming) async {
    var changed = false;
    for (final uid in incoming.deleted) {
      changed |= await _takeDeletion(uid);
    }
    for (final record in rulesFirst(incoming.changed)) {
      changed |= switch (record.kind) {
        SyncKind.rule => await _takeRule(record),
        SyncKind.todo => await _takeTodo(record),
      };
    }
    return changed;
  }

  @override
  Future<String?> syncToken() async {
    final rows = await _db.query(
      _state,
      where: 'key = ?',
      whereArgs: [_tokenKey],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  @override
  Future<void> setSyncToken(String? token) async {
    if (token == null) {
      await _db.delete(_state, where: 'key = ?', whereArgs: [_tokenKey]);
      return;
    }
    await _db.insert(_state, <String, Object?>{
      'key': _tokenKey,
      'value': token,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> _takeDeletion(String uid) async {
    // A removal beats an edit, so whatever was done here goes too.
    await _db.delete(_changes, where: 'uid = ?', whereArgs: [uid]);
    final todos = await _db.delete(_todos, where: 'uid = ?', whereArgs: [uid]);
    final rules = await _db.query(
      _recurrences,
      columns: ['id'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    for (final rule in rules) {
      // Its showings go with it, as they do when it is removed here.
      await _db.delete(
        _todos,
        where: 'recurrence_id = ?',
        whereArgs: [rule['id']],
      );
      await _db.delete(_recurrences, where: 'id = ?', whereArgs: [rule['id']]);
    }
    return todos > 0 || rules.isNotEmpty;
  }

  Future<bool> _takeRule(SyncRecord record) async {
    if (!takesIncoming(
      await _localState(_recurrences, record.uid),
      updatedAt: record.updatedAt,
    )) {
      return false;
    }
    final row = <String, Object?>{
      ...record.fields,
      'uid': record.uid,
      'updated_at': record.updatedAt,
    };
    final updated = await _db.update(
      _recurrences,
      row,
      where: 'uid = ?',
      whereArgs: [record.uid],
    );
    if (updated == 0) await _db.insert(_recurrences, row);
    await _db.delete(_changes, where: 'uid = ?', whereArgs: [record.uid]);
    return true;
  }

  Future<bool> _takeTodo(SyncRecord record) async {
    if (!takesIncoming(
      await _localState(_todos, record.uid),
      updatedAt: record.updatedAt,
    )) {
      return false;
    }
    int? recurrenceId;
    final ruleUid = record.fields['recurrence_uid'] as String?;
    if (ruleUid != null) {
      final rules = await _db.query(
        _recurrences,
        columns: ['id'],
        where: 'uid = ?',
        whereArgs: [ruleUid],
      );
      // A showing of a rule not held here is no use: its rule is gone, or
      // on its way out of here.
      if (rules.isEmpty) return false;
      recurrenceId = rules.single['id'] as int;
    }
    final row = <String, Object?>{
      ...record.fields,
      'recurrence_id': recurrenceId,
      'uid': record.uid,
      'updated_at': record.updatedAt,
    };
    final updated = await _db.update(
      _todos,
      row,
      where: 'uid = ?',
      whereArgs: [record.uid],
    );
    if (updated == 0) {
      await _db.insert(
        _todos,
        row,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _db.delete(_changes, where: 'uid = ?', whereArgs: [record.uid]);
    return true;
  }

  Future<LocalState> _localState(String table, String uid) async {
    final logged = await _db.query(
      _changes,
      where: 'uid = ?',
      whereArgs: [uid],
    );
    final rows = await _db.query(
      table,
      columns: ['updated_at'],
      where: 'uid = ?',
      whereArgs: [uid],
    );
    return LocalState(
      updatedAt: rows.isEmpty ? null : rows.single['updated_at'] as int,
      pending: logged.isNotEmpty,
      deleted: logged.isNotEmpty && (logged.single['deleted'] as int) == 1,
    );
  }

  Future<SyncRecord?> _recordFor(SyncKind kind, String uid) async {
    final table = kind == SyncKind.todo ? _todos : _recurrences;
    final rows = await _db.query(table, where: 'uid = ?', whereArgs: [uid]);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return SyncRecord(
      kind: kind,
      uid: uid,
      updatedAt: row['updated_at'] as int,
      fields: kind == SyncKind.todo
          ? Todo.fromRow(row).toSyncFields(row['day']! as int)
          : Recurrence.fromRow(row).toSyncFields(),
    );
  }

  /// Logs a write, so it is sent. A row written again after being removed
  /// here, as a rule's showing is when the rule is stretched back over its
  /// day, is a row again, so a tombstone gives way.
  Future<void> _log(String uid, SyncKind kind) => _db.insert(_changes, {
    'uid': uid,
    'kind': kind.name,
    'deleted': 0,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _logTodoRows({
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await _db.query(
      _todos,
      columns: ['uid'],
      where: where,
      whereArgs: whereArgs,
    );
    for (final row in rows) {
      await _log(row['uid']! as String, SyncKind.todo);
    }
  }

  Future<void> _logRecurrence(int id) async {
    final rows = await _db.query(
      _recurrences,
      columns: ['uid'],
      where: 'id = ?',
      whereArgs: [id],
    );
    for (final row in rows) {
      await _log(row['uid']! as String, SyncKind.rule);
    }
  }

  /// Logs a removal, so the other side lets the row go too.
  Future<void> _tombstone(String uid, SyncKind kind) => _db.insert(_changes, {
    'uid': uid,
    'kind': kind.name,
    'deleted': 1,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> _deleteTodos({
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await _db.query(
      _todos,
      columns: ['uid'],
      where: where,
      whereArgs: whereArgs,
    );
    for (final row in rows) {
      await _tombstone(row['uid']! as String, SyncKind.todo);
    }
    await _db.delete(_todos, where: where, whereArgs: whereArgs);
  }

  Future<void> _deleteRecurrence(int id) async {
    final rows = await _db.query(
      _recurrences,
      columns: ['uid'],
      where: 'id = ?',
      whereArgs: [id],
    );
    for (final row in rows) {
      await _tombstone(row['uid']! as String, SyncKind.rule);
    }
    await _db.delete(_recurrences, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _updateRecurrence(int id, Map<String, Object?> values) async {
    await _db.update(
      _recurrences,
      <String, Object?>{...values, 'updated_at': _now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _logRecurrence(id);
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
