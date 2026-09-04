import 'due.dart';
import 'repeat_rule.dart';
import 'rich/task_body.dart';
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

  /// Writes a new one-off. Words come as a [body], or as plain [title]
  /// words for short.
  Future<Todo> insert({
    required int day,
    String? title,
    TaskBody? body,
    Due? due,
  });

  /// Starts a repeating task, positioned as of [day].
  ///
  /// Returns nothing on purpose: a rule need not fire on the day it was made,
  /// so what the day holds afterwards is [mergeDay]'s to say, not this call's.
  Future<void> insertSeries({
    required int day,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
  });

  /// Writes down a projected occurrence so it can carry state of its own.
  Future<Todo> materialize({required int day, required Todo todo});

  Future<void> save(Todo todo);

  /// Writes the given order back as positions 0, 1, 2 and so on.
  Future<void> reorder(List<Todo> ordered);

  /// Removes a one-off outright, or hides a single occurrence of a rule.
  Future<void> remove({required int day, required Todo todo});

  /// Puts a task on another day, at the end of that day's open group. A
  /// one-off simply changes day. A rule cannot have one showing moved, so
  /// its showing on [fromDay] is hidden and a one-off copy of the words and
  /// time is written on [toDay]; the copy is no longer part of the series.
  Future<void> moveToDay({
    required int fromDay,
    required int toDay,
    required Todo todo,
  });

  Future<void> removeSeries(int recurrenceId);

  /// Stops a repeating task from [day] onwards, keeping the days before it.
  /// A cut at or before the rule's own beginning removes it outright.
  Future<void> endSeriesFrom({required int recurrenceId, required int day});

  /// Starts a repeating task after [day], dropping that day and every one
  /// before it. A cut at or after the rule's end removes it outright.
  Future<void> startSeriesAfter({required int recurrenceId, required int day});

  /// Rewrites the series. Words, rule and time all belong to it, so every
  /// written-down occurrence takes the new ones too.
  Future<void> saveSeries({
    required int recurrenceId,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
  });

  /// The body meant by a pair of shorthand arguments.
  static TaskBody bodyOf(String? title, TaskBody? body) =>
      body ?? TaskBody.plain(title ?? '');

  /// The day as shown at [now]: tasks whose time has come head the list.
  /// Without a moment the order is the plain one from [compareTodos].
  Future<List<Todo>> todosOn(int day, {DateTime? now}) async => mergeDay(
    stored: await storedTodosOn(day),
    recurrences: await recurrencesFor(day),
    day: day,
    now: now,
  );
}
