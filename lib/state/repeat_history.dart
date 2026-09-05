import '../data/todo_store.dart';

/// How a repeating task has gone: every day it fell on, from its first to
/// today, and what became of each. Read afresh from the store, never
/// patched.
class RepeatHistory {
  const RepeatHistory(this.entries);

  static const empty = RepeatHistory([]);

  /// Newest first.
  final List<HistoryEntry> entries;

  bool get isEmpty => entries.isEmpty;

  int get done => entries.where((each) => each.outcome.isDone).length;

  /// The showings that have been settled one way or the other. Today's,
  /// while still open, is left out, so the figure never drops during the
  /// day for no reason.
  int get counted => entries.where((each) => each.outcome.isCounted).length;

  /// `12 of 15 done`, or `Nothing yet` before any showing has been settled.
  String get summary => counted == 0 ? 'Nothing yet' : '$done of $counted done';

  /// Walks the rule from its first day to [today]. A day the rule falls on
  /// reads its written row where there is one, and is taken as not done
  /// otherwise. A hidden row, deleted for its day or sent elsewhere, was
  /// taken off that day on purpose and is left out altogether.
  static Future<RepeatHistory> read(
    TodoStore store, {
    required int recurrenceId,
    required int today,
  }) async {
    final series = await store.readSeries(recurrenceId);
    if (series == null) return empty;
    final rule = series.recurrence.rule;
    final last = rule.endDay == null || rule.endDay! > today
        ? today
        : rule.endDay!;
    final entries = <HistoryEntry>[];
    for (var day = last; day >= rule.startDay; day--) {
      if (!rule.fallsOn(day)) continue;
      final row = series.byDay[day];
      if (row != null && row.hidden) continue;
      entries.add(
        HistoryEntry(
          day: day,
          outcome: switch ((row?.done ?? false, day == today)) {
            (true, _) => HistoryOutcome.done,
            (false, true) => HistoryOutcome.open,
            (false, false) => HistoryOutcome.missed,
          },
        ),
      );
    }
    return RepeatHistory(entries);
  }
}

/// One showing of the rule and how it went.
class HistoryEntry {
  const HistoryEntry({required this.day, required this.outcome});

  final int day;
  final HistoryOutcome outcome;
}

enum HistoryOutcome {
  done,
  missed,

  /// Today's showing, not done yet and still to be.
  open;

  bool get isDone => this == done;

  bool get isCounted => this != open;

  String get label => switch (this) {
    done => 'Done',
    missed => 'Missed',
    open => 'Open',
  };
}
