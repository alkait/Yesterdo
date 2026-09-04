/// Whole-day arithmetic.
///
/// A day is identified by the number of days since the Unix epoch, so every
/// lookup, comparison and database index stays a plain integer.
library;

const int _millisecondsPerDay = 86400000;

extension DayMath on DateTime {
  /// This instant collapsed to midnight local time.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Days since the Unix epoch. Stable across time zones and DST.
  int get epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
      _millisecondsPerDay;

  DateTime addDays(int amount) => DateTime(year, month, day + amount);

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}

DateTime dateFromEpochDay(int value) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    value * _millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

DateTime todayDate() => DateTime.now().startOfDay;

/// A moment on a day, in local time. Built from calendar fields rather than
/// by adding a duration to midnight, so a clock change in the night does not
/// shift it.
DateTime dateFromEpochDayAt(int day, int minuteOfDay) {
  final date = dateFromEpochDay(day);
  return DateTime(
    date.year,
    date.month,
    date.day,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
}

/// Number of days in the month containing [date].
int daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

/// Weekday index of the first of the month with Sunday as 0.
int leadingBlanksForMonth(DateTime date) =>
    DateTime(date.year, date.month, 1).weekday % 7;
