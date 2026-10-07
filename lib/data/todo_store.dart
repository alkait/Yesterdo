import 'due.dart';
import 'repeat_rule.dart';
import 'rich/task_body.dart';
import 'search.dart';
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

  /// Writes a new one-off, at the top of the day unless a [position] is
  /// given. Words come as a [body], or as plain [title] words for short.
  /// [pinned] is for a task that takes the place of a pinned one, and
  /// [carryOver] for one that moves itself on while undone.
  Future<Todo> insert({
    required int day,
    String? title,
    TaskBody? body,
    Due? due,
    int? position,
    bool pinned = false,
    bool carryOver = false,
  });

  /// Starts a repeating task, at the top of [day] unless a [position] is
  /// given, and returns the rule's id.
  ///
  /// Nothing more on purpose: a rule need not fire on the day it was made,
  /// so what the day holds afterwards is [mergeDay]'s to say, not this call's.
  Future<int> insertSeries({
    required int day,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
    int? position,
  });

  /// Writes down a projected occurrence so it can carry state of its own.
  Future<Todo> materialize({required int day, required Todo todo});

  Future<void> save(Todo todo);

  /// Writes the given order back as positions 0, 1, 2 and so on.
  Future<void> reorder(List<Todo> ordered);

  /// Removes a one-off outright, or hides a single occurrence of a rule.
  Future<void> remove({required int day, required Todo todo});

  /// Puts a task on another day, at the end of that day's open group, or
  /// above everything on it with [toTop]. A one-off simply changes day. A
  /// rule cannot have one showing moved, so its showing on [fromDay] is
  /// hidden and a one-off copy of the words and time is written on [toDay];
  /// the copy is no longer part of the series. A pin goes with the task
  /// either way. Returns the task as it now stands on [toDay].
  Future<Todo> moveToDay({
    required int fromDay,
    required int toDay,
    required Todo todo,
    bool toTop = false,
  });

  Future<void> removeSeries(int recurrenceId);

  /// Stops a repeating task from [day] onwards, keeping the days before it.
  /// A cut at or before the rule's own beginning removes it outright.
  Future<void> endSeriesFrom({required int recurrenceId, required int day});

  /// Starts a repeating task after [day], dropping that day and every one
  /// before it. A cut at or after the rule's end removes it outright.
  Future<void> startSeriesAfter({required int recurrenceId, required int day});

  /// Rewrites the series. Words, rule and time all belong to it, so every
  /// written-down occurrence takes the new ones too. Ticks do not: the rule
  /// takes the words open, and each occurrence keeps its own ticks on
  /// them, through [TaskBody.withTicksOf].
  Future<void> saveSeries({
    required int recurrenceId,
    String? title,
    TaskBody? body,
    required RepeatRule rule,
    Due? due,
  });

  /// Leaves a rule's missed showings on the days up to and including [day]
  /// where they are, and stops the backlog raising them again. Nothing is
  /// written to those days; a later day missed is a fresh miss and counts.
  Future<void> ignoreMissed({required int recurrenceId, required int day});

  /// Per rule, the last day whose missed showings have been ignored.
  Future<Map<int, int>> ignoredMissed();

  /// The tasks that carry themselves over and were left undone on a day
  /// before [day], each with the day it sits on, earliest day first and in
  /// the day's position order within it. However far back.
  Future<List<CarriedTask>> leftToCarryBefore(int day);

  /// Every picture any task or rule refers to, for the sweep that clears
  /// the rest out.
  Future<Set<String>> allImages();

  /// A rule with every showing of it that has been written down, for the
  /// history. Null for a rule since gone.
  Future<SeriesRows?> readSeries(int recurrenceId);

  /// One-off rows whose words answer to [query], each with its day. Hidden
  /// rows are left out, and so are a rule's written-down showings: the rule
  /// stands for those, through [recurrencesMatching].
  Future<List<SearchHit>> oneOffsMatching(String query);

  /// Rules whose words answer to [query].
  Future<List<Recurrence>> recurrencesMatching(String query);

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

  /// Brings every task that carries itself over, left undone on a day
  /// before [today], on to today. Composed in [composeCarryForward], so
  /// both stores answer alike.
  Future<List<Todo>> carryForward({required int today});

  /// The days from [today] to [last] as they will stand if nobody touches
  /// them. Composed in [composeDaysAhead], so both stores answer alike.
  Future<Map<int, List<Todo>>> daysAhead({
    required int today,
    required int last,
  });

  /// Everything answering to [query], latest day first. Composed once, in
  /// [composeSearch], so both stores answer alike.
  Future<List<SearchHit>> search(String query, {required int today}) async =>
      query.trim().isEmpty
      ? const []
      : composeSearch(
          oneOffs: await oneOffsMatching(query),
          recurrences: await recurrencesMatching(query),
          today: today,
        );
}

/// A task that carries itself over, on the day it was left on.
class CarriedTask {
  const CarriedTask({required this.day, required this.todo});

  final int day;
  final Todo todo;
}

/// A rule and its written-down showings, keyed by day. What the history is
/// composed from: a day the rule falls on reads its row here, or is taken
/// as untouched when there is none.
class SeriesRows {
  const SeriesRows({required this.recurrence, required this.byDay});

  final Recurrence recurrence;
  final Map<int, Todo> byDay;
}

/// Brings every task that carries itself over, left undone on a day before
/// [today], on to today, above everything there and in the order they were
/// left in. Returns the tasks as they now stand on today.
Future<List<Todo>> composeCarryForward(
  TodoStore store, {
  required int today,
}) async {
  final left = await store.leftToCarryBefore(today);
  final moved = <Todo>[];
  // Each goes on top of the last, so the earliest left is moved last and
  // lands highest.
  for (final each in left.reversed) {
    moved.insert(
      0,
      await store.moveToDay(
        fromDay: each.day,
        toDay: today,
        todo: each.todo,
        toTop: true,
      ),
    );
  }
  return moved;
}

/// The days from [today] to [last] as they will stand if nobody touches
/// them: each day's own tasks, headed by the carry-over tasks left open on
/// the days before it, which will be carried on to it when it comes. A new
/// day is a new call, so a carried task arrives not waved away.
Future<Map<int, List<Todo>>> composeDaysAhead(
  TodoStore store, {
  required int today,
  required int last,
}) async {
  final ahead = <int, List<Todo>>{};
  var carrying = <Todo>[];
  for (var day = today; day <= last; day++) {
    final own = await store.todosOn(day);
    ahead[day] = <Todo>[...carrying, ...own];
    carrying = <Todo>[
      ...carrying,
      for (final todo in own)
        if (todo.carries) todo.copyWith(dismissed: false),
    ];
  }
  return ahead;
}
