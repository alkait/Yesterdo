import 'dart:convert';

import '../core/app_theme.dart';
import '../core/day.dart';
import '../reminders/planned_reminder.dart';

/// One task as the Lock Screen and Home Screen widgets need it. Only what
/// can be drawn crosses over: no body, no pictures, no rule.
class GlanceTask {
  const GlanceTask({
    required this.day,
    required this.key,
    required this.title,
    required this.callsAt,
    required this.dueAt,
  });

  /// The day it sits on, as a count of days since the epoch.
  final int day;

  /// The task's [Todo.key], so a tapped widget finds its card again.
  final String key;

  /// What a tapped widget hands back, the same as a notification's.
  String get payload => taskPayload(day, key);

  /// The first line of words, which is all a widget has room for.
  final String title;

  /// Milliseconds at the moment it starts calling for attention: its
  /// earliest reminder on the day, or its time itself. A widget draws it
  /// from this moment on, and nothing before.
  final int callsAt;

  /// Milliseconds at its due moment, which is the time a widget shows.
  final int dueAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'payload': payload,
    'title': title,
    'callsAt': callsAt,
    'dueAt': dueAt,
  };
}

/// One pinned task as the Pinned widget needs it. It has no moment of its
/// own: it is drawn for the whole of its day, in the day's order.
class GlancePin {
  const GlancePin({
    required this.day,
    required this.key,
    required this.title,
    this.dueAt,
  });

  /// The day it is pinned on, as a count of days since the epoch.
  final int day;

  /// The task's [Todo.key], so a tapped widget finds its card again.
  final String key;

  String get payload => taskPayload(day, key);

  /// The first line of words.
  final String title;

  /// Milliseconds at its due moment, or null for a task with no time.
  final int? dueAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'payload': payload,
    'title': title,
    // The day as the moment it begins, which a widget can hold against
    // the moment it is drawing without knowing how days are counted.
    'dayAt': dateFromEpochDay(day).millisecondsSinceEpoch,
    'dueAt': dueAt,
  };
}

/// Everything the widgets are given: the tasks of the days they may need to
/// draw, the pinned ones of today and tomorrow, and the accent of the chosen look in both brightnesses, since the
/// widgets follow the system rather than the app.
///
/// Handed over whole each time. A widget is never told about one change.
class Glance {
  const Glance({
    required this.tasks,
    this.pinned = const [],
    required this.choice,
  });

  final List<GlanceTask> tasks;
  final List<GlancePin> pinned;
  final AppThemeChoice choice;

  String encode() => jsonEncode(<String, Object?>{
    'accentLight': _hex(AppTheme.accentOf(choice, dark: false)),
    'accentDark': _hex(AppTheme.accentOf(choice, dark: true)),
    'tasks': <Object?>[for (final task in tasks) task.toJson()],
    'pinned': <Object?>[for (final pin in pinned) pin.toJson()],
  });

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
