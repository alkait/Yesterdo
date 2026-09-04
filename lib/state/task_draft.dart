import '../data/repeat_rule.dart';

/// What the editor screen hands back: the words, and how often they come back.
class TaskDraft {
  const TaskDraft({required this.title, this.repeat});

  final String title;
  final RepeatRule? repeat;
}
