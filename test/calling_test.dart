import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/todo.dart';

/// When a task starts calling for attention on its day.
void main() {
  final day = DateTime(2026, 9, 5).epochDay;
  DateTime at(int hour, int minute) => DateTime(2026, 9, 5, hour, minute);

  Todo taskDue(Due due) =>
      Todo(title: 'Lunch', done: false, position: 0, due: due);

  test('with no reminder it calls at the time itself, not a minute before', () {
    final lunch = taskDue(const Due(minute: 12 * 60));
    expect(lunch.isCallingOn(day: day, now: at(11, 39)), isFalse);
    expect(lunch.isCallingOn(day: day, now: at(11, 59)), isFalse);
    expect(lunch.isCallingOn(day: day, now: at(12, 0)), isTrue);
  });

  test('with reminders it calls from the earliest one on the day', () {
    final lunch = taskDue(const Due(minute: 12 * 60, reminders: {0, 30, 5}));
    expect(lunch.isCallingOn(day: day, now: at(11, 29)), isFalse);
    expect(lunch.isCallingOn(day: day, now: at(11, 30)), isTrue);
  });

  test('a reminder the day before is not this day\'s call', () {
    final lunch = taskDue(
      const Due(minute: 12 * 60, reminders: {Due.minutesPerDay}),
    );
    expect(lunch.isCallingOn(day: day, now: at(11, 59)), isFalse);
    expect(lunch.isCallingOn(day: day, now: at(12, 0)), isTrue);
    expect(lunch.due!.callInstantOn(day), at(12, 0));
  });
}
