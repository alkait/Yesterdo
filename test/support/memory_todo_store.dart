import 'package:remind_me/data/todo.dart';
import 'package:remind_me/data/todo_store.dart';

/// Test double for [TodoStore]. Completes synchronously so widget tests can
/// drive it with `pump` alone.
class MemoryTodoStore implements TodoStore {
  final Map<int, List<Todo>> _byDay = <int, List<Todo>>{};
  int _nextId = 1;

  @override
  Future<List<Todo>> todosOn(int day) =>
      Future.value(<Todo>[...?_byDay[day]]..sort(compareTodos));

  @override
  Future<Todo> insert({required int day, required String title}) {
    final items = _byDay.putIfAbsent(day, () => <Todo>[]);
    final todo = Todo(
      id: _nextId++,
      title: title,
      done: false,
      position: items.length,
    );
    items.add(todo);
    return Future.value(todo);
  }

  @override
  Future<void> save(Todo todo) {
    for (final items in _byDay.values) {
      final index = items.indexWhere((item) => item.id == todo.id);
      if (index != -1) items[index] = todo;
    }
    return Future.value();
  }

  @override
  Future<void> delete(int id) {
    for (final items in _byDay.values) {
      items.removeWhere((item) => item.id == id);
    }
    return Future.value();
  }
}
