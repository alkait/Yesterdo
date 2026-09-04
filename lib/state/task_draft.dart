import '../data/due.dart';
import '../data/repeat_rule.dart';

/// What the editor screen hands back: the words, when in the day they are
/// due, and how often they come back.
class TaskDraft {
  const TaskDraft({required this.title, this.due, this.repeat});

  final String title;
  final Due? due;
  final RepeatRule? repeat;
}
