import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/todo.dart';

void main() {
  group('compareTodos', () {
    Todo open(int id, int position) =>
        Todo(id: id, title: 't$id', done: false, position: position);
    Todo checked(int id, int position, int completedAt) => Todo(
      id: id,
      title: 't$id',
      done: true,
      position: position,
      completedAt: completedAt,
    );

    test('open tasks keep insertion order', () {
      final items = [open(2, 1), open(1, 0)]..sort(compareTodos);
      expect(items.map((t) => t.id), [1, 2]);
    });

    test('checked tasks sink below open ones', () {
      final items = [checked(1, 0, 100), open(2, 1)]..sort(compareTodos);
      expect(items.map((t) => t.id), [2, 1]);
    });

    test('checked tasks order by completion time', () {
      final items = [checked(1, 0, 200), checked(2, 1, 100)]
        ..sort(compareTodos);
      expect(items.map((t) => t.id), [2, 1]);
    });
  });

  group('day maths', () {
    test('epoch day round trips', () {
      final date = DateTime(2026, 9, 3);
      expect(dateFromEpochDay(date.epochDay), date);
    });

    test('adding days crosses month boundaries', () {
      expect(DateTime(2026, 1, 31).addDays(1), DateTime(2026, 2, 1));
    });

    test('month geometry', () {
      expect(daysInMonth(DateTime(2024, 2)), 29);
      expect(leadingBlanksForMonth(DateTime(2026, 9)), 2); // Sep 1 is Tuesday
    });
  });

  group('labels', () {
    final now = DateTime(2026, 9, 3);

    test('relative words near today', () {
      expect(dayHeadline(now, now: now), 'Today');
      expect(dayHeadline(now.addDays(-1), now: now), 'Yesterday');
      expect(dayHeadline(now.addDays(1), now: now), 'Tomorrow');
      expect(dayHeadline(now.addDays(5), now: now), 'Tuesday');
    });

    test('long date', () {
      expect(longDate(now), 'September 3, 2026');
    });
  });
}
