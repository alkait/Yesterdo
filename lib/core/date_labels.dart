import 'day.dart';

const _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const weekdayInitials = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/// Takes `DateTime.weekday`, where Monday is 1.
String weekdayName(int weekday) => _weekdayNames[weekday - 1];

String shortWeekdayName(int weekday) =>
    _weekdayNames[weekday - 1].substring(0, 3);

/// `1st`, `2nd`, `13th`, `21st`.
String ordinal(int number) {
  final teens = number % 100;
  if (teens >= 11 && teens <= 13) return '${number}th';
  return switch (number % 10) {
    1 => '${number}st',
    2 => '${number}nd',
    3 => '${number}rd',
    _ => '${number}th',
  };
}

/// The headline shown above the list: a relative word when one reads better
/// than a weekday name.
String dayHeadline(DateTime date, {DateTime? now}) {
  final offset = date.epochDay - (now ?? todayDate()).epochDay;
  return switch (offset) {
    0 => 'Today',
    -1 => 'Yesterday',
    1 => 'Tomorrow',
    _ => _weekdayNames[date.weekday - 1],
  };
}

/// The supporting line: `Sep 3, 2026`.
String longDate(DateTime date) =>
    '${_monthNames[date.month - 1].substring(0, 3)} ${date.day}, ${date.year}';

String monthAndYear(DateTime date) =>
    '${_monthNames[date.month - 1]} ${date.year}';

/// `9:05 AM`, or `09:05` when the device keeps a 24-hour clock.
String timeLabel(int minuteOfDay, {bool twentyFourHour = false}) {
  final hour = minuteOfDay ~/ 60;
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  if (twentyFourHour) return '${hour.toString().padLeft(2, '0')}:$minute';
  final clockHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$clockHour:$minute ${hour < 12 ? 'AM' : 'PM'}';
}
