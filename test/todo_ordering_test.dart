import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
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

  group('todoOrderOn', () {
    final day = DateTime(2026, 9, 4).epochDay;
    final nine = DateTime(2026, 9, 4, 9, 0);
    Todo at(
      int id,
      int position,
      int minute, {
      bool done = false,
      bool dismissed = false,
    }) => Todo(
      id: id,
      title: 't$id',
      done: done,
      position: position,
      due: Due(minute: minute),
      dismissed: dismissed,
      completedAt: done ? 1 : null,
    );
    Todo plain(int id, int position) =>
        Todo(id: id, title: 't$id', done: false, position: position);

    test('a task whose time has come heads the open ones', () {
      final items = [plain(1, 0), at(2, 1, 8 * 60 + 30)]
        ..sort(todoOrderOn(day: day, now: nine));
      expect(items.map((t) => t.id), [2, 1]);
    });

    test('a task due later keeps its place until then', () {
      final items = [plain(1, 0), at(2, 1, 9 * 60 + 30)]
        ..sort(todoOrderOn(day: day, now: nine));
      expect(items.map((t) => t.id), [1, 2]);
      expect(items[1].isCallingOn(day: day, now: nine), isFalse);
      expect(
        items[1].isCallingOn(day: day, now: DateTime(2026, 9, 4, 9, 30)),
        isTrue,
        reason: 'the very minute counts',
      );
    });

    test('calling tasks rank by time, earliest first', () {
      final items = [at(1, 0, 8 * 60 + 45), at(2, 1, 8 * 60), plain(3, 2)]
        ..sort(todoOrderOn(day: day, now: nine));
      expect(items.map((t) => t.id), [2, 1, 3]);
    });

    test('done and dismissed tasks do not call', () {
      final items = [
        plain(1, 0),
        at(2, 1, 8 * 60, done: true),
        at(3, 2, 8 * 60, dismissed: true),
      ]..sort(todoOrderOn(day: day, now: nine));
      expect(items.map((t) => t.id), [1, 3, 2]);
    });

    test('a task on another day is judged against that day', () {
      final tomorrow = day + 1;
      expect(at(1, 0, 8 * 60).isCallingOn(day: tomorrow, now: nine), isFalse);
      expect(at(1, 0, 8 * 60).isCallingOn(day: day - 1, now: nine), isTrue);
    });

    test('the plain order stands without a moment to judge by', () {
      final items = [plain(1, 0), at(2, 1, 8 * 60)]..sort(compareTodos);
      expect(items.map((t) => t.id), [1, 2]);
    });

    test('a new time is a new call, the same time keeps a wave-away', () {
      final waved = at(1, 0, 8 * 60, dismissed: true);
      expect(waved.withDue(const Due(minute: 8 * 60)).dismissed, isTrue);
      expect(waved.withDue(const Due(minute: 9 * 60)).dismissed, isFalse);
      expect(waved.withDue(null).due, isNull);
      expect(waved.snoozed(nowMinute: 9 * 60).dismissed, isFalse);
      expect(waved.snoozed(nowMinute: 9 * 60).due!.minute, 9 * 60 + 10);
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
      expect(longDate(now), 'Sep 3, 2026');
    });
  });
}
