import 'todo.dart';

/// Everything the app needs from storage. One implementation ships with the
/// app; tests supply their own.
abstract interface class TodoStore {
  Future<List<Todo>> todosOn(int day);

  Future<Todo> insert({required int day, required String title});

  Future<void> save(Todo todo);

  /// Writes the given order back as positions 0, 1, 2 and so on.
  Future<void> reorder(List<Todo> ordered);

  Future<void> delete(int id);
}
