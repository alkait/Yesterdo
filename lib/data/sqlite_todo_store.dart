import 'package:sqflite/sqflite.dart';

import 'todo.dart';
import 'todo_store.dart';

/// The shipping store: a single SQLite file on the device.
class SqliteTodoStore implements TodoStore {
  const SqliteTodoStore(this._db);

  static const _table = 'todos';

  final Database _db;

  @override
  Future<List<Todo>> todosOn(int day) async {
    final rows = await _db.query(_table, where: 'day = ?', whereArgs: [day]);
    return rows.map(Todo.fromRow).toList()..sort(compareTodos);
  }

  @override
  Future<Todo> insert({required int day, required String title}) async {
    final position = await _nextPosition(day);
    final draft = Todo(id: 0, title: title, done: false, position: position);
    final id = await _db.insert(_table, draft.toRow(day));
    return Todo(id: id, title: title, done: false, position: position);
  }

  @override
  Future<void> save(Todo todo) => _db.update(
    _table,
    <String, Object?>{
      'title': todo.title,
      'done': todo.done ? 1 : 0,
      'completed_at': todo.completedAt,
    },
    where: 'id = ?',
    whereArgs: [todo.id],
  );

  @override
  Future<void> delete(int id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<int> _nextPosition(int day) async {
    final rows = await _db.rawQuery(
      'SELECT MAX(position) AS top FROM $_table WHERE day = ?',
      [day],
    );
    return ((rows.first['top'] as int?) ?? -1) + 1;
  }
}
