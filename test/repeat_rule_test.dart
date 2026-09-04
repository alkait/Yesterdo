import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/data/todo.dart';

int dayOf(int year, int month, int day) => DateTime(year, month, day).epochDay;

void main() {
  // Sep 1 2026 is a Tuesday.
  final tuesday = dayOf(2026, 9, 1);

  group('daily', () {
    test('fires every day from its start', () {
      final rule = RepeatRule.daily(tuesday);
      expect(rule.fallsOn(tuesday), isTrue);
      expect(rule.fallsOn(tuesday + 1), isTrue);
      expect(rule.fallsOn(tuesday + 400), isTrue);
    });

    test('never reaches back before its start', () {
      expect(RepeatRule.daily(tuesday).fallsOn(tuesday - 1), isFalse);
    });

    test('stops at its end when it has one', () {
      const kind = RepeatKind.daily;
      final rule = RepeatRule(
        kind: kind,
        startDay: tuesday,
        endDay: tuesday + 2,
      );
      expect(rule.fallsOn(tuesday + 2), isTrue);
      expect(rule.fallsOn(tuesday + 3), isFalse);
    });
  });

  group('weekly', () {
    test('fires on its weekday and no other', () {
      final rule = RepeatRule.weekly(tuesday, RepeatRule.weekdayBit(2));
      expect(rule.fallsOn(tuesday), isTrue);
      expect(rule.fallsOn(tuesday + 1), isFalse);
      expect(rule.fallsOn(tuesday + 7), isTrue);
    });

    test('takes more than one weekday', () {
      final rule = RepeatRule.weekly(
        tuesday,
        RepeatRule.weekdayBit(2) | RepeatRule.weekdayBit(4),
      );
      expect(rule.fallsOn(tuesday), isTrue);
      expect(rule.fallsOn(tuesday + 2), isTrue, reason: 'Thursday');
      expect(rule.fallsOn(tuesday + 1), isFalse);
    });
  });

  group('monthly', () {
    test('fires on its day of the month', () {
      final rule = RepeatRule.monthly(dayOf(2026, 1, 15), 15);
      expect(rule.fallsOn(dayOf(2026, 2, 15)), isTrue);
      expect(rule.fallsOn(dayOf(2026, 2, 14)), isFalse);
    });

    test('the 31st clamps to the last day of a shorter month', () {
      final rule = RepeatRule.monthly(dayOf(2026, 1, 31), 31);
      expect(rule.fallsOn(dayOf(2026, 1, 31)), isTrue);
      expect(rule.fallsOn(dayOf(2026, 2, 28)), isTrue, reason: 'February');
      expect(rule.fallsOn(dayOf(2026, 4, 30)), isTrue, reason: 'April');
      expect(rule.fallsOn(dayOf(2026, 4, 29)), isFalse);
    });

    test('clamping follows a leap year', () {
      final rule = RepeatRule.monthly(dayOf(2024, 1, 31), 31);
      expect(rule.fallsOn(dayOf(2024, 2, 29)), isTrue);
      expect(rule.fallsOn(dayOf(2024, 2, 28)), isFalse);
    });
  });

  group('neighbours', () {
    test('daily has none before its start and some after', () {
      final rule = RepeatRule.daily(tuesday);
      expect(rule.hasOccurrenceBefore(tuesday), isFalse);
      expect(rule.hasOccurrenceAfter(tuesday), isTrue);
      expect(rule.hasOccurrenceBefore(tuesday + 1), isTrue);
    });

    test('an ended rule has none after its last day', () {
      final rule = RepeatRule(
        kind: RepeatKind.daily,
        startDay: tuesday,
        endDay: tuesday + 3,
      );
      expect(rule.hasOccurrenceAfter(tuesday + 2), isTrue);
      expect(rule.hasOccurrenceAfter(tuesday + 3), isFalse);
      expect(rule.hasOccurrenceAfter(tuesday + 400), isFalse);
    });

    test('a single-day rule has neighbours on neither side', () {
      final rule = RepeatRule(
        kind: RepeatKind.daily,
        startDay: tuesday,
        endDay: tuesday,
      );
      expect(rule.hasOccurrenceBefore(tuesday), isFalse);
      expect(rule.hasOccurrenceAfter(tuesday), isFalse);
    });

    test('weekly looks past the days in between', () {
      final rule = RepeatRule.weekly(tuesday, RepeatRule.weekdayBit(2));
      expect(rule.hasOccurrenceBefore(tuesday + 7), isTrue);
      expect(rule.hasOccurrenceAfter(tuesday), isTrue);
    });

    test('monthly looks past a whole month', () {
      final rule = RepeatRule.monthly(dayOf(2026, 1, 31), 31);
      expect(rule.hasOccurrenceBefore(dayOf(2026, 2, 28)), isTrue);
      expect(rule.hasOccurrenceAfter(dayOf(2026, 1, 31)), isTrue);
    });

    test('a far-off day still counts what came before it', () {
      final rule = RepeatRule.daily(tuesday);
      expect(rule.hasOccurrenceBefore(tuesday + 500), isTrue);
    });
  });

  group('labels', () {
    test('reads the way a person would say it', () {
      expect(RepeatRule.daily(tuesday).label, 'Every day');
      expect(
        RepeatRule.weekly(tuesday, RepeatRule.weekdayBit(2)).label,
        'Every Tuesday',
      );
      expect(
        RepeatRule.weekly(
          tuesday,
          RepeatRule.weekdayBit(1) | RepeatRule.weekdayBit(3),
        ).label,
        'Every Mon, Wed',
      );
      expect(RepeatRule.monthly(tuesday, 3).label, 'Monthly on the 3rd');
    });

    test('ordinals', () {
      expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(ordinal).toList(), [
        '1st',
        '2nd',
        '3rd',
        '4th',
        '11th',
        '12th',
        '13th',
        '21st',
        '22nd',
        '23rd',
        '31st',
      ]);
    });
  });

  group('a day is rows plus rules', () {
    Recurrence rule(int id, String title) => Recurrence(
      id: id,
      title: title,
      rule: RepeatRule.daily(tuesday),
      position: 5,
    );

    test('a rule that fires shows up without being written down', () {
      final day = mergeDay(
        stored: const <Todo>[],
        recurrences: [rule(1, 'Take the pills')],
        day: tuesday,
      );
      expect(day.single.title, 'Take the pills');
      expect(day.single.isStored, isFalse);
      expect(day.single.repeats, isTrue);
    });

    test('a rule that does not fire stays away', () {
      expect(
        mergeDay(
          stored: const <Todo>[],
          recurrences: [rule(1, 'Take the pills')],
          day: tuesday - 1,
        ),
        isEmpty,
      );
    });

    test('a written-down occurrence replaces its projection', () {
      final day = mergeDay(
        stored: [
          const Todo(
            id: 9,
            title: 'Take the pills',
            done: true,
            position: 5,
            recurrenceId: 1,
          ),
        ],
        recurrences: [rule(1, 'Take the pills')],
        day: tuesday,
      );
      expect(day, hasLength(1));
      expect(day.single.done, isTrue);
      expect(day.single.isStored, isTrue);
    });

    test('a hidden occurrence shows nothing at all', () {
      final day = mergeDay(
        stored: [
          const Todo(
            id: 9,
            title: 'Take the pills',
            done: false,
            position: 5,
            recurrenceId: 1,
            hidden: true,
          ),
        ],
        recurrences: [rule(1, 'Take the pills')],
        day: tuesday,
      );
      expect(day, isEmpty);
    });

    test('a projected task keeps its key once written down', () {
      const projected = Todo(
        title: 'Take the pills',
        done: false,
        position: 5,
        recurrenceId: 1,
      );
      expect(projected.stored(9).key, projected.key);
    });
  });
}
