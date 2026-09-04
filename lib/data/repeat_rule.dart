import '../core/date_labels.dart';
import '../core/day.dart';

enum RepeatKind { daily, weekly, monthly }

/// How often a task comes back. Holds no identity and no title, so the editor
/// can hand one around before anything is stored.
class RepeatRule {
  const RepeatRule({
    required this.kind,
    required this.startDay,
    this.weekdays = 0,
    this.monthDay = 1,
    this.endDay,
  });

  factory RepeatRule.daily(int startDay) =>
      RepeatRule(kind: RepeatKind.daily, startDay: startDay);

  factory RepeatRule.weekly(int startDay, int weekdays) => RepeatRule(
    kind: RepeatKind.weekly,
    startDay: startDay,
    weekdays: weekdays,
  );

  factory RepeatRule.monthly(int startDay, int monthDay) => RepeatRule(
    kind: RepeatKind.monthly,
    startDay: startDay,
    monthDay: monthDay,
  );

  final RepeatKind kind;

  /// The first day the task can appear. Without it a rule made today would
  /// reach back over every past day the user visits.
  final int startDay;

  /// Bitmask of weekdays, bit 0 being Monday, to match `DateTime.weekday`.
  final int weekdays;

  /// Day of the month, clamped to the last day of shorter months.
  final int monthDay;

  final int? endDay;

  static int weekdayBit(int weekday) => 1 << (weekday - 1);

  bool includesWeekday(int weekday) => weekdays & weekdayBit(weekday) != 0;

  bool fallsOn(int day) {
    if (day < startDay) return false;
    if (endDay != null && day > endDay!) return false;

    final date = dateFromEpochDay(day);
    return switch (kind) {
      RepeatKind.daily => true,
      RepeatKind.weekly => includesWeekday(date.weekday),
      RepeatKind.monthly => date.day == monthDay.clamp(1, daysInMonth(date)),
    };
  }

  /// The longest a rule can go between showings. Monthly is the widest, and a
  /// month never runs past 31 days, so a window this long always contains one.
  static const _widestGap = 31;

  /// Whether this rule shows up on any day before [day].
  bool hasOccurrenceBefore(int day) {
    if (day <= startDay) return false;
    final lowest = day - _widestGap < startDay ? startDay : day - _widestGap;
    for (var each = day - 1; each >= lowest; each--) {
      if (fallsOn(each)) return true;
    }
    // A window wider than the longest gap must have held one.
    return day - startDay > _widestGap;
  }

  /// Whether this rule shows up on any day after [day].
  bool hasOccurrenceAfter(int day) {
    final last = endDay;
    if (last != null && day >= last) return false;
    var highest = day + _widestGap;
    if (last != null && last < highest) highest = last;
    for (var each = day + 1; each <= highest; each++) {
      if (fallsOn(each)) return true;
    }
    return last == null || last - day > _widestGap;
  }

  /// What the editor and the picker show, such as `Every Tuesday`.
  String get label => switch (kind) {
    RepeatKind.daily => 'Every day',
    RepeatKind.weekly => _weeklyLabel,
    RepeatKind.monthly => 'Monthly on the ${ordinal(monthDay)}',
  };

  String get _weeklyLabel {
    final days = [
      for (var weekday = 1; weekday <= 7; weekday++)
        if (includesWeekday(weekday)) weekday,
    ];
    if (days.isEmpty) return 'Every week';
    if (days.length == 7) return 'Every day';
    if (days.length == 1) return 'Every ${weekdayName(days.first)}';
    return 'Every ${days.map(shortWeekdayName).join(', ')}';
  }

  RepeatRule copyWith({
    RepeatKind? kind,
    int? weekdays,
    int? monthDay,
    int? startDay,
  }) => RepeatRule(
    kind: kind ?? this.kind,
    startDay: startDay ?? this.startDay,
    weekdays: weekdays ?? this.weekdays,
    monthDay: monthDay ?? this.monthDay,
    endDay: endDay,
  );
}

/// A repeating task: a rule, the words that go with it, and where it sits.
class Recurrence {
  const Recurrence({
    required this.id,
    required this.title,
    required this.rule,
    required this.position,
  });

  factory Recurrence.fromRow(Map<String, Object?> row) => Recurrence(
    id: row['id']! as int,
    title: row['title']! as String,
    position: row['position']! as int,
    rule: RepeatRule(
      kind: RepeatKind.values.byName(row['kind']! as String),
      startDay: row['start_day']! as int,
      weekdays: row['weekdays']! as int,
      monthDay: row['month_day']! as int,
      endDay: row['end_day'] as int?,
    ),
  );

  final int id;
  final String title;
  final RepeatRule rule;
  final int position;

  bool fallsOn(int day) => rule.fallsOn(day);

  static Map<String, Object?> rowFor({
    required String title,
    required RepeatRule rule,
    required int position,
  }) => <String, Object?>{
    'title': title,
    'kind': rule.kind.name,
    'weekdays': rule.weekdays,
    'month_day': rule.monthDay,
    'start_day': rule.startDay,
    'end_day': rule.endDay,
    'position': position,
  };
}
