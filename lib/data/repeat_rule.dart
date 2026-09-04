import '../core/date_labels.dart';
import '../core/day.dart';
import 'due.dart';

enum RepeatKind { daily, weekly, monthly }

/// How often a task comes back. Holds no identity and no title, so the editor
/// can hand one around before anything is stored.
class RepeatRule {
  const RepeatRule({
    required this.kind,
    required this.startDay,
    this.weekdays = 0,
    this.monthDays = 0,
    this.endDay,
  });

  factory RepeatRule.daily(int startDay) =>
      RepeatRule(kind: RepeatKind.daily, startDay: startDay);

  factory RepeatRule.weekly(int startDay, int weekdays) => RepeatRule(
    kind: RepeatKind.weekly,
    startDay: startDay,
    weekdays: weekdays,
  );

  factory RepeatRule.monthly(int startDay, int monthDays) => RepeatRule(
    kind: RepeatKind.monthly,
    startDay: startDay,
    monthDays: monthDays,
  );

  /// The highest day of the month that can be chosen. Every month has it,
  /// so a rule never has to make do with a different day.
  static const lastChoosableMonthDay = 28;

  /// The bit in [monthDays] that means the last day of the month, whatever
  /// its length. Kept clear of the day bits, which run from bit 0 for the 1st.
  static const lastDayOfMonthBit = 1 << 31;

  static int monthDayBit(int day) => 1 << (day - 1);

  final RepeatKind kind;

  /// The first day the task can appear. Without it a rule made today would
  /// reach back over every past day the user visits.
  final int startDay;

  /// Bitmask of weekdays, bit 0 being Monday, to match `DateTime.weekday`.
  final int weekdays;

  /// Bitmask of days of the month, bit 0 being the 1st, plus
  /// [lastDayOfMonthBit] for the last day of every month.
  final int monthDays;

  final int? endDay;

  static int weekdayBit(int weekday) => 1 << (weekday - 1);

  bool includesWeekday(int weekday) => weekdays & weekdayBit(weekday) != 0;

  bool includesMonthDay(int day) => monthDays & monthDayBit(day) != 0;

  bool get includesLastDayOfMonth => monthDays & lastDayOfMonthBit != 0;

  bool fallsOn(int day) {
    if (day < startDay) return false;
    if (endDay != null && day > endDay!) return false;

    final date = dateFromEpochDay(day);
    return switch (kind) {
      RepeatKind.daily => true,
      RepeatKind.weekly => includesWeekday(date.weekday),
      RepeatKind.monthly =>
        includesMonthDay(date.day) ||
            (includesLastDayOfMonth && date.day == daysInMonth(date)),
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
    RepeatKind.monthly => 'Every month',
  };

  /// The small print under [label]: which days a monthly rule lands on.
  /// Empty for the other kinds, whose label already says it all.
  String get detail =>
      kind == RepeatKind.monthly ? monthDaysLabel(monthDays) : '';

  /// `On the 1st and 15th`, `On the last day`, `On the 3rd, 17th and last
  /// day`. Empty when no day is chosen.
  static String monthDaysLabel(int monthDays) {
    final parts = [
      for (var day = 1; day <= lastChoosableMonthDay; day++)
        if (monthDays & monthDayBit(day) != 0) ordinal(day),
      if (monthDays & lastDayOfMonthBit != 0) 'last day',
    ];
    if (parts.isEmpty) return '';
    if (parts.length == 1) return 'On the ${parts.single}';
    final head = parts.sublist(0, parts.length - 1).join(', ');
    return 'On the $head and ${parts.last}';
  }

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
    int? monthDays,
    int? startDay,
  }) => RepeatRule(
    kind: kind ?? this.kind,
    startDay: startDay ?? this.startDay,
    weekdays: weekdays ?? this.weekdays,
    monthDays: monthDays ?? this.monthDays,
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
    this.due,
  });

  factory Recurrence.fromRow(Map<String, Object?> row) => Recurrence(
    id: row['id']! as int,
    title: row['title']! as String,
    position: row['position']! as int,
    due: Due.fromRow(row),
    rule: RepeatRule(
      kind: RepeatKind.values.byName(row['kind']! as String),
      startDay: row['start_day']! as int,
      weekdays: row['weekdays']! as int,
      monthDays: row['month_days']! as int,
      endDay: row['end_day'] as int?,
    ),
  );

  final int id;
  final String title;
  final RepeatRule rule;
  final int position;

  /// The time it is due on every day it falls on, or null for none.
  final Due? due;

  bool fallsOn(int day) => rule.fallsOn(day);

  static Map<String, Object?> rowFor({
    required String title,
    required RepeatRule rule,
    required int position,
    Due? due,
  }) => <String, Object?>{
    'title': title,
    ...ruleColumns(rule),
    'position': position,
    ...due?.toRow() ?? Due.emptyRow,
  };

  /// The columns a rule is written into, shared by insert and update.
  static Map<String, Object?> ruleColumns(RepeatRule rule) => <String, Object?>{
    'kind': rule.kind.name,
    'weekdays': rule.weekdays,
    'month_days': rule.monthDays,
    'start_day': rule.startDay,
    'end_day': rule.endDay,
  };
}
