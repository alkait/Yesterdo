import '../core/day.dart';
import '../data/todo_store.dart';
import '../state/backlog.dart';
import 'glance.dart';

/// Works out what the widgets should be showing. Called with the whole store
/// each time, so what a widget draws is derived from what is true now rather
/// than patched as things change.
///
/// Only tasks that can call for attention are handed over, since that is all
/// a widget ever draws. A task with no time, one already done and one waved
/// away are no use to it and never cross.
class GlancePlanner {
  const GlancePlanner(this._store);

  /// Days looked at beyond today. Tomorrow rides along so the widgets are
  /// still right after midnight, when nobody has opened the app to say so.
  static const daysAhead = 1;

  /// Days looked back over. The same reach as the backlog, so what the app
  /// still counts as outstanding is what a widget can still call about.
  static const daysBehind = Backlog.window;

  /// The most tasks carried at once. The system holds only so much for a
  /// widget, and no widget can draw more than a handful anyway.
  static const cap = 40;

  final TodoStore _store;

  Future<List<GlanceTask>> plan({required DateTime now}) async {
    final today = now.epochDay;
    final ignored = await _store.ignoredMissed();
    final tasks = <GlanceTask>[];

    for (var day = today - daysBehind; day <= today + daysAhead; day++) {
      for (final todo in await _store.todosOn(day, now: now)) {
        final due = todo.due;
        if (due == null || todo.done || todo.dismissed) continue;
        // A rule's missed showings can be left where they are and passed
        // over. The backlog stops raising those, and so does a widget.
        if (day < today && todo.repeats) {
          final through = ignored[todo.recurrenceId!];
          if (through != null && day <= through) continue;
        }
        tasks.add(
          GlanceTask(
            day: day,
            key: todo.key,
            title: todo.firstLine,
            // When it starts calling, which is its earliest reminder on the
            // day or its time itself. The one rule, worked out here so a
            // widget never has to reason about it.
            callsAt: due.callInstantOn(day).millisecondsSinceEpoch,
            dueAt: due.instantOn(day).millisecondsSinceEpoch,
          ),
        );
      }
    }

    // Newest first, so a long-forgotten day is what falls off the end rather
    // than this morning's.
    tasks.sort((a, b) => b.callsAt.compareTo(a.callsAt));
    return tasks.length > cap ? tasks.sublist(0, cap) : tasks;
  }
}
