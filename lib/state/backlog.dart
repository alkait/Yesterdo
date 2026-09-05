import '../data/todo.dart';
import '../data/todo_store.dart';

/// What was left undone on earlier days. One-offs stand one by one; a
/// rule's missed showings are gathered under it with a count. Read afresh
/// from the store, never patched.
class Backlog {
  const Backlog(this.entries);

  static const empty = Backlog([]);

  /// How far back is looked. Anything older is history, not a backlog.
  static const window = 30;

  final List<BacklogEntry> entries;

  /// Every task and every missed showing, counted one by one.
  int get count => entries.fold(0, (sum, entry) => sum + entry.count);

  bool get isEmpty => entries.isEmpty;

  /// Reads the days before [today], newest first. A task not done counts,
  /// waved away or not, and a rule's showings fall under one entry.
  static Future<Backlog> read(TodoStore store, {required int today}) async {
    final oneOffs = <BacklogEntry>[];
    final rules = <int, List<BacklogItem>>{};
    for (var day = today - 1; day >= today - window; day--) {
      for (final todo in await store.todosOn(day)) {
        if (todo.done) continue;
        final item = BacklogItem(day: day, todo: todo);
        if (todo.repeats) {
          rules.putIfAbsent(todo.recurrenceId!, () => []).add(item);
        } else {
          oneOffs.add(BacklogEntry([item]));
        }
      }
    }
    final entries = [
      ...oneOffs,
      for (final items in rules.values) BacklogEntry(items),
    ]..sort((a, b) => b.latestDay.compareTo(a.latestDay));
    return Backlog(entries);
  }
}

/// One line of the backlog: a one-off, or every missed showing of a rule.
class BacklogEntry {
  BacklogEntry(this.items) : assert(items.isNotEmpty, 'an entry has a day');

  /// Newest first.
  final List<BacklogItem> items;

  /// The task as it stands on its most recent day: what the line reads.
  Todo get todo => items.first.todo;

  int get latestDay => items.first.day;

  int get count => items.length;

  bool get repeats => todo.repeats;

  /// Stable across reads, for widget keys.
  String get key => todo.key;
}

/// A task on the day it was left on.
class BacklogItem {
  const BacklogItem({required this.day, required this.todo});

  final int day;
  final Todo todo;
}
