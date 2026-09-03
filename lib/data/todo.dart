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

/// Open tasks keep their insertion order. Completed ones sink to the bottom,
/// most recently checked last.
int compareTodos(Todo a, Todo b) {
  if (a.done != b.done) return a.done ? 1 : -1;
  if (a.done) return (a.completedAt ?? 0).compareTo(b.completedAt ?? 0);
  return a.position.compareTo(b.position);
}
