import '../core/day.dart';
import '../data/todo_store.dart';
import 'glance.dart';

/// Works out what the widgets should be showing. Called with the whole store
/// each time, so what a widget draws is derived from what is true now rather
/// than patched as things change.
class GlancePlanner {
  const GlancePlanner(this._store);

  /// Days handed over beyond today. Tomorrow rides along so the widgets are
  /// still right after midnight, when nobody has opened the app to say so.
  static const daysAhead = 1;

  /// The most tasks carried for one day. A widget can draw a handful; the
  /// rest are only ever a number.
  static const perDay = 20;

  final TodoStore _store;

  Future<List<GlanceTask>> plan({required DateTime now}) async {
    final today = now.epochDay;
    final tasks = <GlanceTask>[];

    for (var day = today; day <= today + daysAhead; day++) {
      final dayStart = dateFromEpochDay(day).millisecondsSinceEpoch;
      final todos = await _store.todosOn(day, now: now);
      for (final todo in todos.take(perDay)) {
        tasks.add(
          GlanceTask(
            day: day,
            key: todo.key,
            title: todo.firstLine,
            dayStart: dayStart,
            dueAt: todo.due?.instantOn(day).millisecondsSinceEpoch,
            done: todo.done,
            dismissed: todo.dismissed,
          ),
        );
      }
    }
    return tasks;
  }
}
