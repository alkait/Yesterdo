import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/repeat_rule.dart';

import 'app_flow_test.dart' show at, bootApp, tileFor;
import 'support/memory_todo_store.dart';

/// What was left undone on earlier days, raised on today.
void main() {
  final today = todayDate().epochDay;

  Future<MemoryTodoStore> seeded() async {
    final store = MemoryTodoStore();
    await store.insert(day: today - 1, title: 'Call Sam');
    await store.insert(day: today - 2, title: 'Pay rent');
    // Finished, so not left behind.
    final walked = await store.insert(day: today - 1, title: 'Walk');
    await store.save(walked.toggled(1));
    // A daily rule from three days ago: three showings missed, today's not.
    await store.insertSeries(
      day: today - 3,
      title: 'Stretch',
      rule: RepeatRule.daily(today - 3),
    );
    // Too long ago to be chased.
    await store.insert(day: today - 40, title: 'Ancient');
    return store;
  }

  Future<void> openBacklog(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('backlog-row')));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String entry, String action) async {
    await tester.tap(find.byKey(ValueKey('backlog-$entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  testWidgets('today says how much was left, and lists it newest first', (
    tester,
  ) async {
    final store = await seeded();
    await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    expect(find.text('5 left from earlier days'), findsOneWidget);

    await openBacklog(tester);
    expect(find.text('Left behind'), findsOneWidget);
    expect(find.text('Ancient'), findsNothing);
    expect(find.text('Walk'), findsNothing);
    expect(find.text('3 missed'), findsOneWidget, reason: 'one line per rule');
    expect(find.text('Yesterday'), findsOneWidget);
    // Today's own Stretch card sits under the sheet; the line is the last.
    final sam = tester.getTopLeft(find.text('Call Sam')).dy;
    final stretch = tester.getTopLeft(find.text('Stretch').last).dy;
    final rent = tester.getTopLeft(find.text('Pay rent')).dy;
    expect(sam, lessThan(rent));
    expect(stretch, lessThan(rent));
  });

  testWidgets('the row is not there on another day, nor with nothing left', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backlog-row')), findsNothing);

    final store = await seeded();
    await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backlog-row')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backlog-row')), findsNothing);
  });

  testWidgets('a one-off is brought to today, sent to the future, or done', (
    tester,
  ) async {
    final store = await seeded();
    await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
    await tester.pumpAndSettle();

    await openBacklog(tester);
    await choose(tester, 't1', 'Bring to today');
    // The screen stays, one card shorter, so the rest can be seen to.
    expect(find.text('Left behind'), findsOneWidget);
    expect(find.byKey(const ValueKey('backlog-t1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-t2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send to future'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('pick-day-${today + 1}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backlog-t2')), findsNothing);
    final tomorrow = await store.todosOn(today + 1);
    expect(tomorrow.map((t) => t.title), contains('Pay rent'));

    // Done on a rule's line takes every missed showing, and the sheet comes
    // down by itself once nothing is left.
    await choose(tester, 'r1', 'Done');
    expect(find.text('Left behind'), findsNothing);
    expect(find.byKey(const ValueKey('backlog-row')), findsNothing);
    for (var day = today - 3; day < today; day++) {
      final stretch = (await store.todosOn(day))
          .singleWhere((t) => t.title == 'Stretch');
      expect(stretch.done, isTrue, reason: 'day $day');
    }
    expect(tileFor(tester, 'Stretch').todo.done, isFalse, reason: 'today');
    expect(tileFor(tester, 'Call Sam').todo.done, isFalse);
  });

  testWidgets('skipping a rule hides its missed showings and keeps the rule', (
    tester,
  ) async {
    final store = await seeded();
    await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
    await tester.pumpAndSettle();

    await openBacklog(tester);
    await choose(tester, 'r1', 'Skip');
    expect(find.byKey(const ValueKey('backlog-r1')), findsNothing);
    expect(
      (await store.todosOn(today - 1)).map((t) => t.title),
      isNot(contains('Stretch')),
    );
    expect((await store.todosOn(today + 1)).map((t) => t.title), [
      'Stretch',
    ], reason: 'the rule goes on');

    await choose(tester, 't1', 'Delete');
    expect(find.byKey(const ValueKey('backlog-t1')), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1 left from an earlier day'), findsOneWidget);
    expect(tileFor(tester, 'Stretch').todo.done, isFalse, reason: 'today');
    final yesterday = await store.todosOn(today - 1);
    expect(yesterday.where((t) => !t.done), isEmpty);
  });
}
