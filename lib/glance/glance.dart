import 'dart:convert';

import '../core/app_theme.dart';
import '../reminders/planned_reminder.dart';

/// One task as the Lock Screen and Home Screen widgets need it. Only what
/// can be drawn crosses over: no body, no pictures, no rule.
class GlanceTask {
  const GlanceTask({
    required this.day,
    required this.key,
    required this.title,
    required this.dayStart,
    required this.done,
    required this.dismissed,
    this.dueAt,
  });

  /// The day it sits on, as a count of days since the epoch.
  final int day;

  /// The task's [Todo.key], so a tapped widget finds its card again.
  final String key;

  /// What a tapped widget hands back, the same as a notification's.
  String get payload => taskPayload(day, key);

  /// The first line of words, which is all a widget has room for.
  final String title;

  /// Milliseconds at midnight of the day it sits on, local time.
  final int dayStart;

  /// Milliseconds at its due moment, or null for a task with no time.
  final int? dueAt;

  final bool done;

  /// Waved away for the day: it keeps its time but stops asking, so a widget
  /// does not put it forward.
  final bool dismissed;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'payload': payload,
    'title': title,
    'dayStart': dayStart,
    'dueAt': dueAt,
    'done': done,
    'dismissed': dismissed,
  };
}

/// Everything the widgets are given: the tasks of the days they may need to
/// draw, and the accent of the chosen look in both brightnesses, since the
/// widgets follow the system rather than the app.
///
/// Handed over whole each time. A widget is never told about one change.
class Glance {
  const Glance({required this.tasks, required this.choice});

  final List<GlanceTask> tasks;
  final AppThemeChoice choice;

  String encode() => jsonEncode(<String, Object?>{
    'accentLight': _hex(AppTheme.accentOf(choice, dark: false)),
    'accentDark': _hex(AppTheme.accentOf(choice, dark: true)),
    'tasks': <Object?>[for (final task in tasks) task.toJson()],
  });

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
