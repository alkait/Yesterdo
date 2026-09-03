import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/todo.dart';
import 'package:remind_me/ui/branded/branded.dart';

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

    test('the most recently checked task heads the struck group', () {
      final items = [checked(1, 0, 100), checked(2, 1, 200)]
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

  group('first line', () {
    Todo withTitle(String title) =>
        Todo(id: 1, title: title, done: false, position: 0);

    test('a single line is itself', () {
      expect(withTitle('Buy milk').firstLine, 'Buy milk');
    });

    test('anything past the first break is dropped', () {
      expect(withTitle('Buy milk\nand bread\nand jam').firstLine, 'Buy milk');
    });

    test('an empty title stays empty', () {
      expect(withTitle('').firstLine, '');
    });
  });

  group('reading direction', () {
    test('plain text either way', () {
      expect(brandedTextDirection('Buy milk'), TextDirection.ltr);
      expect(brandedTextDirection('اشتري الحليب'), TextDirection.rtl);
    });

    test('leading digits and punctuation are skipped, not decided on', () {
      expect(brandedTextDirection('1. اشتري الحليب'), TextDirection.rtl);
      expect(brandedTextDirection('1. Buy milk'), TextDirection.ltr);
      expect(brandedTextDirection('"اشتري"'), TextDirection.rtl);
    });

    test('emoji carry no direction', () {
      expect(brandedTextDirection('🎉 اشتري الحليب'), TextDirection.rtl);
      expect(brandedTextDirection('🎉 Buy milk'), TextDirection.ltr);
    });

    test('the first strong letter wins, not a later one', () {
      expect(brandedTextDirection('Call محمد'), TextDirection.ltr);
      expect(brandedTextDirection('اتصل بـ Sam'), TextDirection.rtl);
    });

    test('Hebrew reads right to left too', () {
      expect(brandedTextDirection('שלום'), TextDirection.rtl);
    });

    test('text with no letters falls back to left to right', () {
      expect(brandedTextDirection(''), TextDirection.ltr);
      expect(brandedTextDirection('123 !?'), TextDirection.ltr);
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
