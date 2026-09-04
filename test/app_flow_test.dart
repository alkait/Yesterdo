import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/app.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/state/todos_controller.dart';
import 'package:remind_me/ui/branded/branded.dart';
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

/// Writes a task the way a person does: on the editor screen.
Future<void> addTask(WidgetTester tester, String title) async {
  await tester.tap(find.text('Add a task'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

Future<void> openActions(WidgetTester tester, String title) async {
  final tile = find.text(title);
  await tester.tap(tile);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

/// Opens the action sheet and taps one of its buttons.
Future<void> actOn(
  WidgetTester tester,
  String title,
  String action, {
  bool settle = true,
}) async {
  await openActions(tester, title);
  await tester.tap(find.text(action));
  if (settle) {
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Picks a card up by its grip and drags it down over another one.
Future<void> dragCardDown(
  WidgetTester tester, {
  required String from,
  required String over,
}) async {
  final row = find.ancestor(
    of: find.text(from),
    matching: find.byType(TodoTile),
  );
  final grip = find.descendant(
    of: row,
    matching: find.byType(BrandedDragHandle),
  );
  final start = tester.getCenter(grip);
  final target = tester.getCenter(find.text(over));

  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.moveTo(target);
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Drags a row sideways to uncover its buttons, then lets go.
Future<void> swipe(WidgetTester tester, String title, Offset by) async {
  await tester.drag(find.text(title), by);
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

  testWidgets('the list screen takes no text inline', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();

    expect(find.text('New task'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('cancelling the editor adds nothing', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing planned'), findsOneWidget);
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

  testWidgets('tasks carry no checkbox', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    expect(find.byType(BrandedSelectionCircle), findsNothing);
  });

  testWidgets('double tapping opens the actions for that task', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await openActions(tester, 'Buy milk');

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('marking done strikes the task, then sinks it', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Post letter');

    await actOn(tester, 'Buy milk', 'Done', settle: false);

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

  testWidgets('the newest completed task heads the struck group', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Post letter');

    await actOn(tester, 'Buy milk', 'Done');
    expect(visibleTitles(tester), ['Call Sam', 'Post letter', 'Buy milk']);

    await actOn(tester, 'Call Sam', 'Done');
    expect(visibleTitles(tester), ['Post letter', 'Call Sam', 'Buy milk']);
  });

  testWidgets('unmarking lifts a task back above the completed ones', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await actOn(tester, 'Buy milk', 'Done');
    expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);

    await actOn(tester, 'Buy milk', 'Not done');
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
  });

  testWidgets('editing rewrites the task on its own screen', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await openActions(tester, 'Buy milk');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Buy milk'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy oat milk');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Buy oat milk']);
  });

  testWidgets('deleting from the actions removes the task', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await actOn(tester, 'Buy milk', 'Delete');

    expect(visibleTitles(tester), ['Call Sam']);
  });

  /// The rendered title of the first card.
  Text titleTextOf(WidgetTester tester, String title) => tester.widget<Text>(
    find
        .descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(TodoTile),
          ),
          matching: find.byType(Text),
        )
        .first,
  );

  testWidgets('a card shows one line only, ellipsised', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk\nand bread');

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.textContaining('and bread'), findsNothing);

    final rendered = titleTextOf(tester, 'Buy milk');
    expect(rendered.maxLines, 1);
    expect(rendered.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an Arabic task lays out right to left', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'اشتري الحليب');
    await addTask(tester, 'Buy bread');

    expect(
      titleTextOf(tester, 'اشتري الحليب').textDirection,
      TextDirection.rtl,
    );
    expect(titleTextOf(tester, 'Buy bread').textDirection, TextDirection.ltr);
  });

  testWidgets('open tasks carry a drag handle, completed ones do not', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    expect(find.byType(BrandedDragHandle), findsNWidgets(2));

    await actOn(tester, 'Buy milk', 'Done');
    expect(find.byType(BrandedDragHandle), findsOneWidget);
  });

  testWidgets('dragging the handle reorders open tasks and it sticks', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Post letter');

    await dragCardDown(tester, from: 'Buy milk', over: 'Post letter');

    expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);

    // The new order survives leaving the day and coming back, so it reached
    // the store rather than living only in memory.
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);
  });

  testWidgets('a reordered task keeps its slot after being unchecked', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Post letter');

    await actOn(tester, 'Call Sam', 'Done');
    expect(visibleTitles(tester), ['Buy milk', 'Post letter', 'Call Sam']);

    await actOn(tester, 'Call Sam', 'Not done');
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);
  });

  testWidgets('swiping alone changes nothing until a button is tapped', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await swipe(tester, 'Buy milk', const Offset(-160, 0));
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    // Swiping back puts it away without doing anything.
    await swipe(tester, 'Buy milk', const Offset(160, 0));
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
  });

  testWidgets('the delete button on the trailing side removes the task', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await swipe(tester, 'Buy milk', const Offset(-160, 0));
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Call Sam']);
  });

  testWidgets('the leading side offers done and edit', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await swipe(tester, 'Buy milk', const Offset(200, 0));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);

    // Now the same button offers to undo it.
    await swipe(tester, 'Buy milk', const Offset(200, 0));
    expect(find.byIcon(Icons.remove_done_rounded), findsOneWidget);
  });

  testWidgets('the edit button opens the editor screen', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await swipe(tester, 'Buy milk', const Offset(200, 0));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy oat milk');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Buy oat milk']);
  });

  testWidgets('opening one row puts the last one away', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await swipe(tester, 'Buy milk', const Offset(-160, 0));
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    await swipe(tester, 'Call Sam', const Offset(-160, 0));
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
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

    expect(find.byKey(const ValueKey('weekday-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('weekday-6')), findsOneWidget);

    final now = DateTime.now();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(
      find.textContaining('${now.year}'),
      findsOneWidget,
      reason: 'header should now show the picked date',
    );
  });

  testWidgets('content is capped so it stays readable on a large screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    final bar = tester.getSize(find.byType(BrandedBottomBar));
    expect(bar.width, lessThanOrEqualTo(Brand.maxContentWidth));
  });
}
