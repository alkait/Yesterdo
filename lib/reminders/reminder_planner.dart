import '../core/day.dart';
import '../data/todo_store.dart';
import 'planned_reminder.dart';

/// Works out which notifications the coming days need. Called with the whole
/// store each time, so the plan is always derived from what is true now
/// rather than patched as things change.
class ReminderPlanner {
  const ReminderPlanner(this._store);

  /// How far ahead notifications are laid down. A repeating rule could go on
  /// forever, and the system keeps only so many pending, so the window is
  /// refilled whenever something changes and each time the app wakes.
  static const daysAhead = 14;

  /// The most the system will hold for one app, with a little kept back.
  static const cap = 60;

  final TodoStore _store;

  Future<List<PlannedReminder>> plan({required DateTime now}) async {
    final today = now.epochDay;
    final planned = <PlannedReminder>[];

    for (var day = today; day <= today + daysAhead; day++) {
      for (final todo in await _store.todosOn(day)) {
        if (todo.done || todo.dismissed) continue;
        final fireAt = todo.due?.reminderInstantOn(day);
        if (fireAt == null || !fireAt.isAfter(now)) continue;
        planned.add(
          PlannedReminder(
            day: day,
            key: todo.key,
            title: todo.firstLine,
            dueLabel: 'Due ${todo.due!.label()}',
            fireAt: fireAt,
          ),
        );
      }
    }

    planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return planned.length > cap ? planned.sublist(0, cap) : planned;
  }
}
