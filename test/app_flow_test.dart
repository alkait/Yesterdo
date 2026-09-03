import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/app.dart';
import 'package:remind_me/ui/branded/branded.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/state/todos_controller.dart';
import 'package:remind_me/ui/widgets/todo_tile.dart';

import 'support/memory_todo_store.dart';

Widget bootApp() => ProviderScope(
  overrides: [todoStoreProvider.overrideWithValue(MemoryTodoStore())],
  child: const RemindMeApp(),
);

/// Titles in the order they are painted.
List<String> visibleTitles(WidgetTester tester) => tester
    .widgetList<TodoTile>(find.byType(TodoTile))
    .map((tile) => tile.todo.title)
    .toList();

Future<void> addTask(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextField), title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens straight onto today with an empty list', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);
    expect(find.text('Add a task'), findsOneWidget);
  });

  testWidgets('typed tasks appear in the order they were added', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
  });

  testWidgets('checking a task strikes it and sinks it to the bottom', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Post letter');

    await tester.tap(find.text('Buy milk'));
    await tester.pump();

    // Strikes through where it stands, before any movement.
    final struck = tester.widget<TodoTile>(
      find.ancestor(of: find.text('Buy milk'), matching: find.byType(TodoTile)),
    );
    expect(struck.todo.done, isTrue);
    expect(visibleTitles(tester).first, 'Buy milk');

    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Call Sam', 'Post letter', 'Buy milk']);
  });

  testWidgets('unchecking lifts a task back above the completed ones', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await tester.tap(find.text('Buy milk'));
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);

    await tester.tap(find.text('Buy milk'));
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
  });

  testWidgets('arrows move a day at a time and each day keeps its own list', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(visibleTitles(tester), ['Buy milk']);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('tapping the date opens a month grid that jumps to a day', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    // The sheet shows a full week header and a Today shortcut.
    expect(find.byKey(const ValueKey('weekday-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('weekday-6')), findsOneWidget);

    final firstOfMonth = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(
      find.textContaining('${firstOfMonth.year}'),
      findsOneWidget,
      reason: 'header should now show the picked date',
    );
  });

  testWidgets('swiping a task away removes it', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await tester.drag(find.text('Buy milk'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Call Sam']);
  });

  testWidgets('content is capped so it stays readable on a large screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    final header = tester.getSize(find.byType(TextField));
    expect(header.width, lessThanOrEqualTo(Brand.maxContentWidth));
  });
}
