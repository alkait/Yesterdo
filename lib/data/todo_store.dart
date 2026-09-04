import 'repeat_rule.dart';
import 'todo.dart';

/// Everything the app needs from storage. One implementation ships with the
/// app; tests supply their own.
///
/// The day view is composed here so both implementations answer it the same
/// way: rows written for the day, plus rules that fire on it.
abstract class TodoStore {
  Future<List<Todo>> storedTodosOn(int day);

  /// Rules that could fire on this day. Filtering to the ones that actually do
  /// is [mergeDay]'s job.
  Future<List<Recurrence>> recurrencesFor(int day);

  Future<Todo> insert({required int day, required String title});

  /// Starts a repeating task, positioned as of [day].
  ///
  /// Returns nothing on purpose: a rule need not fire on the day it was made,
  /// so what the day holds afterwards is [mergeDay]'s to say, not this call's.
  Future<void> insertSeries({
    required int day,
    required String title,
    required RepeatRule rule,
  });

  /// Writes down a projected occurrence so it can carry state of its own.
  Future<Todo> materialize({required int day, required Todo todo});

  Future<void> save(Todo todo);

  /// Writes the given order back as positions 0, 1, 2 and so on.
  Future<void> reorder(List<Todo> ordered);

  /// Removes a one-off outright, or hides a single occurrence of a rule.
  Future<void> remove({required int day, required Todo todo});

  Future<void> removeSeries(int recurrenceId);

  /// Stops a repeating task from [day] onwards, keeping the days before it.
  /// A cut at or before the rule's own beginning removes it outright.
  Future<void> endSeriesFrom({required int recurrenceId, required int day});

  /// Starts a repeating task after [day], dropping that day and every one
  /// before it. A cut at or after the rule's end removes it outright.
  Future<void> startSeriesAfter({required int recurrenceId, required int day});

  Future<void> saveSeries({
    required int recurrenceId,
    required String title,
    required RepeatRule rule,
  });

  Future<List<Todo>> todosOn(int day) async => mergeDay(
    stored: await storedTodosOn(day),
    recurrences: await recurrencesFor(day),
    day: day,
  );
}
