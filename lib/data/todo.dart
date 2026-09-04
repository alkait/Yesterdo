import 'repeat_rule.dart';

/// A single task on a single day.
///
/// A task is either stored as its own row, or projected from a repeat rule and
/// not written down at all until someone acts on it.
class Todo {
  const Todo({
    this.id,
    required this.title,
    required this.done,
    required this.position,
    this.completedAt,
    this.recurrenceId,
    this.hidden = false,
  });

  factory Todo.fromRow(Map<String, Object?> row) => Todo(
    id: row['id']! as int,
    title: row['title']! as String,
    done: (row['done']! as int) == 1,
    position: row['position']! as int,
    completedAt: row['completed_at'] as int?,
    recurrenceId: row['recurrence_id'] as int?,
    hidden: (row['hidden'] as int? ?? 0) == 1,
  );

  /// One day's showing of a repeat rule, before anyone has touched it.
  factory Todo.projected(Recurrence recurrence) => Todo(
    title: recurrence.title,
    done: false,
    position: recurrence.position,
    recurrenceId: recurrence.id,
  );

  /// Row id, or null while the task is only projected from a rule.
  final int? id;

  final String title;
  final bool done;

  /// Insertion rank within the day.
  final int position;

  /// Epoch milliseconds of the last completion, or null while open.
  final int? completedAt;

  /// The rule this task comes from, or null for a one-off.
  final int? recurrenceId;

  /// A written-down occurrence that was deleted for its day alone.
  final bool hidden;

  bool get isStored => id != null;
  bool get repeats => recurrenceId != null;

  /// Identity for sorting, widget keys and swipe state. A repeating task keeps
  /// the same key when it goes from projected to stored, so nothing jumps.
  String get key => repeats ? 'r$recurrenceId' : 't$id';

  /// The one line a list shows. A task may hold more, written on the editor
  /// screen, but only the opening line is ever displayed.
  String get firstLine {
    final wrap = title.indexOf('\n');
    return wrap == -1 ? title : title.substring(0, wrap);
  }

  Todo repositioned(int newPosition) => copyWith(position: newPosition);

  Todo renamed(String newTitle) => copyWith(title: newTitle);

  Todo toggled(int nowMillis) => copyWith(
    done: !done,
    completedAt: done ? null : nowMillis,
    clearCompletedAt: done,
  );

  Todo stored(int rowId) => copyWith(id: rowId);

  Todo copyWith({
    int? id,
    String? title,
    bool? done,
    int? position,
    int? completedAt,
    bool clearCompletedAt = false,
    bool? hidden,
  }) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    done: done ?? this.done,
    position: position ?? this.position,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    recurrenceId: recurrenceId,
    hidden: hidden ?? this.hidden,
  );

  Map<String, Object?> toRow(int day) => <String, Object?>{
    'day': day,
    'title': title,
    'done': done ? 1 : 0,
    'position': position,
    'completed_at': completedAt,
    'recurrence_id': recurrenceId,
    'hidden': hidden ? 1 : 0,
  };
}

/// Open tasks keep their position order. Completed ones sink below them, and
/// the one just checked heads that struck group.
int compareTodos(Todo a, Todo b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  final ranked = a.done
      ? (b.completedAt ?? 0).compareTo(a.completedAt ?? 0)
      : a.position.compareTo(b.position);
  // Positions can collide after a reorder, or between a rule and a row, so the
  // key settles it and the list never reshuffles between rebuilds.
  return ranked != 0 ? ranked : a.key.compareTo(b.key);
}

/// What a day holds: the rows written for it, plus every rule that fires on it
/// and has not already been written down.
List<Todo> mergeDay({
  required List<Todo> stored,
  required List<Recurrence> recurrences,
  required int day,
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
  ]..sort(compareTodos);
}
