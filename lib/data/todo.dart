import 'due.dart';
import 'repeat_rule.dart';
import 'rich/task_body.dart';

/// A single task on a single day.
///
/// A task is either stored as its own row, or projected from a repeat rule and
/// not written down at all until someone acts on it.
class Todo {
  /// Built from a [body], or from plain [title] words as a shorthand for a
  /// body of plain paragraphs. One or the other.
  Todo({
    this.id,
    String? title,
    TaskBody? body,
    required this.done,
    required this.position,
    this.completedAt,
    this.recurrenceId,
    this.hidden = false,
    this.due,
    this.dismissed = false,
  }) : assert(title != null || body != null, 'words, one way or the other'),
       body = body ?? TaskBody.plain(title ?? '');

  factory Todo.fromRow(Map<String, Object?> row) => Todo(
    id: row['id']! as int,
    body: bodyFromRow(row),
    done: (row['done']! as int) == 1,
    position: row['position']! as int,
    completedAt: row['completed_at'] as int?,
    recurrenceId: row['recurrence_id'] as int?,
    hidden: (row['hidden'] as int? ?? 0) == 1,
    due: Due.fromRow(row),
    dismissed: (row['dismissed'] as int? ?? 0) == 1,
  );

  /// The words as stored: the body's JSON when there is one, else the plain
  /// title from before bodies existed.
  static TaskBody bodyFromRow(Map<String, Object?> row) =>
      switch (row['body']) {
        final String json => TaskBody.decode(json),
        _ => TaskBody.plain(row['title']! as String),
      };

  /// One day's showing of a repeat rule, before anyone has touched it.
  factory Todo.projected(Recurrence recurrence) => Todo(
    body: recurrence.body,
    done: false,
    position: recurrence.position,
    recurrenceId: recurrence.id,
    due: recurrence.due,
  );

  /// Row id, or null while the task is only projected from a rule.
  final int? id;

  /// The words in full, with their styles and checklist.
  final TaskBody body;

  /// The words stripped of every style, one line per block.
  String get title => body.plainText;

  final bool done;

  /// Insertion rank within the day.
  final int position;

  /// Epoch milliseconds of the last completion, or null while open.
  final int? completedAt;

  /// The rule this task comes from, or null for a one-off.
  final int? recurrenceId;

  /// A written-down occurrence that was deleted for its day alone.
  final bool hidden;

  /// When in the day it is due, or null for a task with no time.
  final Due? due;

  /// Its call for attention has been waved away for this day.
  final bool dismissed;

  bool get isStored => id != null;
  bool get repeats => recurrenceId != null;

  /// Identity for sorting, widget keys and swipe state. A repeating task keeps
  /// the same key when it goes from projected to stored, so nothing jumps.
  String get key => repeats ? 'r$recurrenceId' : 't$id';

  /// The opening line of words, which is what a notification says. A task
  /// that is pictures alone has none, and says so.
  String get firstLine {
    final wrap = title.indexOf('\n');
    final line = wrap == -1 ? title : title.substring(0, wrap);
    return line.isEmpty && body.images.isNotEmpty ? 'Picture' : line;
  }

  /// Whether the task is calling for attention on [day] at [now]: its
  /// moment has come, the earliest reminder on the day or the time itself,
  /// it is still open, and nobody has waved it away.
  bool isCallingOn({required int day, required DateTime now}) =>
      due != null &&
      !done &&
      !dismissed &&
      !due!.callInstantOn(day).isAfter(now);

  Todo repositioned(int newPosition) => copyWith(position: newPosition);

  Todo renamed(String newTitle) => copyWith(body: TaskBody.plain(newTitle));

  Todo withBody(TaskBody newBody) => copyWith(body: newBody);

  Todo toggled(int nowMillis) => copyWith(
    done: !done,
    completedAt: done ? null : nowMillis,
    clearCompletedAt: done,
  );

  /// Given a new time. A change of time is a new call, so a wave-away from
  /// the old one no longer holds.
  Todo withDue(Due? newDue) => copyWith(
    due: newDue,
    clearDue: newDue == null,
    dismissed: newDue == due ? dismissed : false,
  );

  /// Pushed on a few minutes from [nowMinute], to call again then.
  Todo snoozed({int? nowMinute}) =>
      copyWith(due: due?.snoozed(from: nowMinute), dismissed: false);

  /// Put off until a minute of the day, to call again then.
  Todo snoozedUntil(int minute) =>
      copyWith(due: due?.snoozedUntil(minute), dismissed: false);

  /// Waved away for the day. The time stays on the card.
  Todo dismiss() => copyWith(dismissed: true);

  Todo stored(int rowId) => copyWith(id: rowId);

  Todo copyWith({
    int? id,
    TaskBody? body,
    bool? done,
    int? position,
    int? completedAt,
    bool clearCompletedAt = false,
    bool? hidden,
    Due? due,
    bool clearDue = false,
    bool? dismissed,
  }) => Todo(
    id: id ?? this.id,
    body: body ?? this.body,
    done: done ?? this.done,
    position: position ?? this.position,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    recurrenceId: recurrenceId,
    hidden: hidden ?? this.hidden,
    due: clearDue ? null : (due ?? this.due),
    dismissed: dismissed ?? this.dismissed,
  );

  /// The two columns the words are kept in: the body, and the plain title
  /// derived from it for anything that reads words without styles.
  static Map<String, Object?> bodyColumns(TaskBody body) => <String, Object?>{
    'title': body.plainText,
    'body': body.encode(),
  };

  Map<String, Object?> toRow(int day) => <String, Object?>{
    'day': day,
    ...bodyColumns(body),
    'done': done ? 1 : 0,
    'position': position,
    'completed_at': completedAt,
    'recurrence_id': recurrenceId,
    'hidden': hidden ? 1 : 0,
    ...due?.toRow() ?? Due.emptyRow,
    'dismissed': dismissed ? 1 : 0,
  };
}

/// Open tasks keep their position order. Completed ones sink below them, in
/// the order they were finished, so the one just checked goes to the very
/// bottom.
int compareTodos(Todo a, Todo b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  final ranked = a.done
      ? (a.completedAt ?? 0).compareTo(b.completedAt ?? 0)
      : a.position.compareTo(b.position);
  // Positions can collide after a reorder, or between a rule and a row, so the
  // key settles it and the list never reshuffles between rebuilds.
  return ranked != 0 ? ranked : a.key.compareTo(b.key);
}

/// The order a day is shown in at a given moment: tasks calling for
/// attention head the list, earliest due first, and everything else follows
/// [compareTodos].
Comparator<Todo> todoOrderOn({required int day, required DateTime now}) =>
    (a, b) {
      final aCalls = a.isCallingOn(day: day, now: now);
      final bCalls = b.isCallingOn(day: day, now: now);
      if (aCalls != bCalls) return aCalls ? -1 : 1;
      if (aCalls) {
        final ranked = a.due!.minute.compareTo(b.due!.minute);
        return ranked != 0 ? ranked : a.key.compareTo(b.key);
      }
      return compareTodos(a, b);
    };

/// What a day holds: the rows written for it, plus every rule that fires on it
/// and has not already been written down. Given [now], tasks whose time has
/// come are brought to the top.
List<Todo> mergeDay({
  required List<Todo> stored,
  required List<Recurrence> recurrences,
  required int day,
  DateTime? now,
}) {
  final alreadyStored = <int>{
    for (final todo in stored)
      if (todo.recurrenceId != null) todo.recurrenceId!,
  };

  return <Todo>[
    for (final todo in stored)
      if (!todo.hidden) todo,
    for (final recurrence in recurrences)
      if (recurrence.fallsOn(day) && !alreadyStored.contains(recurrence.id))
        Todo.projected(recurrence),
  ]..sort(now == null ? compareTodos : todoOrderOn(day: day, now: now));
}
