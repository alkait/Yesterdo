import '../data/due.dart';
import '../data/repeat_rule.dart';
import '../data/rich/task_body.dart';

/// What the editor screen hands back: the words in full, the day they belong
/// to, when in that day they are due, and how often they come back.
class TaskDraft {
  TaskDraft({
    required this.day,
    String? title,
    TaskBody? body,
    this.due,
    this.repeat,
  }) : assert(title != null || body != null, 'words, one way or the other'),
       body = (body ?? TaskBody.plain(title ?? '')).trimmed();

  /// The day the task is to sit on, as a count of days since the epoch. A
  /// repeating task counts it as the day its rule starts from.
  final int day;

  final TaskBody body;
  final Due? due;
  final RepeatRule? repeat;

  /// The words stripped of every style.
  String get title => body.plainText;
}
