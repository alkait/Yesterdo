import '../data/due.dart';
import '../data/repeat_rule.dart';
import '../data/rich/task_body.dart';

/// What the editor screen hands back: the words in full, when in the day
/// they are due, and how often they come back.
class TaskDraft {
  TaskDraft({String? title, TaskBody? body, this.due, this.repeat})
    : assert(title != null || body != null, 'words, one way or the other'),
      body = (body ?? TaskBody.plain(title ?? '')).trimmed();

  final TaskBody body;
  final Due? due;
  final RepeatRule? repeat;

  /// The words stripped of every style.
  String get title => body.plainText;
}
