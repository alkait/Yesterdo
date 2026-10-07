import '../data/due.dart';
import '../data/repeat_rule.dart';
import '../data/rich/task_body.dart';

/// What the editor screen hands back: the words in full, the day they belong
/// to, when in that day they are due, how often they come back, and whether
/// they are pinned to the head of that day.
class TaskDraft {
  TaskDraft({
    required this.day,
    String? title,
    TaskBody? body,
    this.due,
    this.repeat,
    this.pinned = false,
    this.carryOver = false,
  }) : assert(title != null || body != null, 'words, one way or the other'),
       body = (body ?? TaskBody.plain(title ?? '')).trimmed();

  /// The day the task is to sit on, as a count of days since the epoch. A
  /// repeating task counts it as the day its rule starts from.
  final int day;

  final TaskBody body;
  final Due? due;
  final RepeatRule? repeat;

  /// Pinned on [day]. For a repeating task that is its showing on the day,
  /// not the rule.
  final bool pinned;

  /// Moves itself on to today when left undone on an earlier day. A
  /// one-off's alone: a repeating task has no use for it.
  final bool carryOver;

  /// The words stripped of every style.
  String get title => body.plainText;
}
