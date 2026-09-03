/// A single task, owned by exactly one day.
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.done,
    required this.position,
    this.completedAt,
  });

  factory Todo.fromRow(Map<String, Object?> row) => Todo(
    id: row['id']! as int,
    title: row['title']! as String,
    done: (row['done']! as int) == 1,
    position: row['position']! as int,
    completedAt: row['completed_at'] as int?,
  );

  final int id;
  final String title;
  final bool done;

  /// Insertion rank within the day. Never reused, never renumbered.
  final int position;

  /// Epoch milliseconds of the last completion, or null while open.
  final int? completedAt;

  /// The one line a list shows. A task may hold more, written on the editor
  /// screen, but only the opening line is ever displayed.
  String get firstLine {
    final wrap = title.indexOf('\n');
    return wrap == -1 ? title : title.substring(0, wrap);
  }

  Todo repositioned(int newPosition) => Todo(
    id: id,
    title: title,
    done: done,
    position: newPosition,
    completedAt: completedAt,
  );

  Todo renamed(String newTitle) => Todo(
    id: id,
    title: newTitle,
    done: done,
    position: position,
    completedAt: completedAt,
  );

  Todo toggled(int nowMillis) => Todo(
    id: id,
    title: title,
    done: !done,
    position: position,
    completedAt: done ? null : nowMillis,
  );

  Map<String, Object?> toRow(int day) => <String, Object?>{
    'day': day,
    'title': title,
    'done': done ? 1 : 0,
    'position': position,
    'completed_at': completedAt,
  };
}

/// Open tasks keep their insertion order. Completed ones sink below them, and
/// the one just checked sits at the top of that struck group so it lands where
/// the eye already is.
int compareTodos(Todo a, Todo b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  final ranked = a.done
      ? (b.completedAt ?? 0).compareTo(a.completedAt ?? 0)
      : a.position.compareTo(b.position);
  // Positions can collide after a reorder, so id settles it and the list
  // never reshuffles between rebuilds.
  return ranked != 0 ? ranked : a.id.compareTo(b.id);
}
