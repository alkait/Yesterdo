import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/repeat_rule.dart';
import 'package:remind_me/state/repeat_history.dart';

import 'app_flow_test.dart' show at, bootApp;
import 'support/memory_todo_store.dart';

/// How a repeating task has gone, day by day.
void main() {
  final today = todayDate().epochDay;

  /// A daily rule from four days ago: done three days ago and yesterday,
  /// deleted for the day before yesterday, missed four days ago, and open
  /// today.
  Future<MemoryTodoStore> seeded() async {
    final store = MemoryTodoStore();
    await store.insertSeries(
      day: today - 4,
      title: 'Stretch',
      rule: RepeatRule.daily(today - 4),
    );
    for (final day in [today - 3, today - 1]) {
      final showing = (await store.todosOn(day)).single;
      final written = await store.materialize(day: day, todo: showing);
      await store.save(written.toggled(1));
    }
    final skipped = (await store.todosOn(today - 2)).single;
    await store.remove(day: today - 2, todo: skipped);
    return store;
  }

  test('reads every showing newest first, leaving out deleted days', () async {
    final history = await RepeatHistory.read(
      await seeded(),
      recurrenceId: 1,
      today: today,
    );
    expect(history.entries.map((each) => each.day), [
      today,
      today - 1,
      today - 3,
      today - 4,
    ]);
    expect(history.entries.map((each) => each.outcome), [
      HistoryOutcome.open,
      HistoryOutcome.done,
      HistoryOutcome.done,
      HistoryOutcome.missed,
    ]);
    expect(history.summary, '2 of 3 done', reason: 'today is not counted');
  });

  test(
    'a rule that ended stops at its end, one still to come has nothing',
    () async {
      final store = MemoryTodoStore();
      await store.insertSeries(
        day: today - 5,
        title: 'Ended',
        rule: RepeatRule.daily(today - 5).copyWith(endDay: today - 3),
      );
      await store.insertSeries(
        day: today + 1,
        title: 'Soon',
        rule: RepeatRule.daily(today + 1),
      );
      final ended = await RepeatHistory.read(
        store,
        recurrenceId: 1,
        today: today,
      );
      expect(ended.entries.map((each) => each.day), [
        today - 3,
        today - 4,
        today - 5,
      ]);
      expect(ended.summary, '0 of 3 done');

      final soon = await RepeatHistory.read(
        store,
        recurrenceId: 2,
        today: today,
      );
      expect(soon.isEmpty, isTrue);
      expect(soon.summary, 'Nothing yet');

      final gone = await RepeatHistory.read(
        store,
        recurrenceId: 9,
        today: today,
      );
      expect(gone.isEmpty, isTrue);
    },
  );

  testWidgets('the view has a History row that opens the days', (tester) async {
    final store = await seeded();
    await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stretch'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('2 of 3 done'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('history-row')));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget, reason: 'the title');
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-summary')), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Done'), findsNWidgets(2));
    expect(find.text('Missed'), findsOneWidget);
    expect(
      find.byKey(ValueKey('history-${today - 2}')),
      findsNothing,
      reason: 'deleted for its day',
    );
    // Newest at the top.
    final todayRow = tester.getTopLeft(find.text('Today')).dy;
    final missed = tester.getTopLeft(find.text('Missed')).dy;
    expect(todayRow, lessThan(missed));

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Task'), findsOneWidget);
  });

  testWidgets('a one-off has no History row', (tester) async {
    final store = MemoryTodoStore();
    await store.insert(day: today, title: 'Once');
    await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Once'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsNothing);
  });
}
