import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/app.dart';
import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/state/theme_choice.dart';
import 'package:remind_me/state/todos_controller.dart';
import 'package:remind_me/ui/branded/branded.dart';
import 'package:remind_me/ui/home_page.dart';
import 'package:remind_me/ui/widgets/todo_tile.dart';

import 'support/memory_settings_store.dart';
import 'support/memory_todo_store.dart';

Widget bootApp({
  MemorySettingsStore? settings,
  AppThemeChoice theme = AppThemeChoice.ink,
}) => ProviderScope(
  overrides: [
    todoStoreProvider.overrideWithValue(MemoryTodoStore()),
    settingsStoreProvider.overrideWithValue(settings ?? MemorySettingsStore()),
    initialThemeChoiceProvider.overrideWithValue(theme),
  ],
  child: const RemindMeApp(),
);

/// The colours the home screen is currently drawn in.
ColorScheme homeScheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(HomePage, skipOffstage: false)))
        .colorScheme;

/// Titles in the order they are painted.
List<String> visibleTitles(WidgetTester tester) => tester
    .widgetList<TodoTile>(find.byType(TodoTile))
    .map((tile) => tile.todo.title)
    .toList();

/// Writes a task the way a person does: on the editor screen.
///
/// Pass [repeat] to also work the repeat picker, naming the option to choose.
Future<void> addTask(
  WidgetTester tester,
  String title, {
  String? repeat,
}) async {
  await tester.tap(find.text('Add a task'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  if (repeat != null) await chooseRepeat(tester, repeat);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// Opens the repeat picker from the editor and settles on one option.
Future<void> chooseRepeat(WidgetTester tester, String option) async {
  await tester.tap(find.text('Repeat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

/// Steps the day header forward or back.
Future<void> stepDay(WidgetTester tester, int days) async {
  final arrow = days > 0
      ? Icons.chevron_right_rounded
      : Icons.chevron_left_rounded;
  for (var step = 0; step < days.abs(); step++) {
    await tester.tap(find.byIcon(arrow).first);
    await tester.pumpAndSettle();
  }
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
///
/// An already open row is covered by its own tap absorber, so the drag lands
/// there rather than on the text. It still reaches the row, which is why the
/// hit-test warning is turned off.
Future<void> swipe(WidgetTester tester, String title, Offset by) async {
  await tester.drag(find.text(title), by, warnIfMissed: false);
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

  group('repeating tasks', () {
    testWidgets('a daily task comes back tomorrow but not yesterday', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      expect(visibleTitles(tester), ['Take the pills']);

      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the pills']);

      // The rule starts on the day it was made, so earlier days are untouched.
      await stepDay(tester, -2);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('a weekly task comes back in seven days, not tomorrow', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Team sync', repeat: 'Every week');

      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, 6);
      expect(visibleTitles(tester), ['Team sync']);
    });

    testWidgets('several repeating tasks all show, each keyed apart', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Draft the summary');
      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await addTask(tester, 'Team sync', repeat: 'Every week');
      await addTask(tester, 'Pay the rent', repeat: 'Every day');

      // Projected occurrences carry no row id. Keying tiles on that id gave
      // them all the same key and the list showed only the last.
      expect(visibleTitles(tester), [
        'Draft the summary',
        'Take the pills',
        'Team sync',
        'Pay the rent',
      ]);

      final keys = tester
          .widgetList<TodoTile>(find.byType(TodoTile))
          .map((tile) => tile.key)
          .toSet();
      expect(keys, hasLength(4), reason: 'every tile needs its own key');
    });

    testWidgets('the picker offers this day, not a leftover from the rule', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      // A weekly rule carries no meaningful day of the month, so the monthly
      // option must fall back to the day being looked at.
      final today = DateTime.now().day;
      await addTask(tester, 'Team sync', repeat: 'Every week');
      await openActions(tester, 'Team sync');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      expect(find.text('Monthly on the ${ordinal(today)}'), findsOneWidget);
    });

    testWidgets('a weekly task skipping today leaves today at once', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      final today = DateTime.now().weekday;
      final tomorrow = today % 7 + 1;

      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Team sync');
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every week').last);
      await tester.pumpAndSettle();

      // Turn tomorrow on before turning today off; the picker will not let a
      // weekly rule end up with no weekday at all.
      await tester.tap(find.byKey(ValueKey('repeat-weekday-$tomorrow')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('repeat-weekday-$today')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The rule does not fire today, so the list must say so straight away
      // rather than only after stepping off the day and back.
      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Team sync']);

      await stepDay(tester, -1);
      expect(
        find.text('Nothing planned'),
        findsOneWidget,
        reason: 'and it stays gone on the way back',
      );
    });

    testWidgets('a repeating card is marked as one', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Buy milk');
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    });

    testWidgets('completing one day leaves the next day open', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await actOn(tester, 'Take the pills', 'Done');

      final struck = tester.widgetList<TodoTile>(find.byType(TodoTile)).single;
      expect(struck.todo.done, isTrue);

      await stepDay(tester, 1);
      final tomorrow = tester
          .widgetList<TodoTile>(find.byType(TodoTile))
          .single;
      expect(tomorrow.todo.done, isFalse);
    });

    testWidgets('deleting asks, and this one leaves the others alone', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('This task repeats'), findsOneWidget);
      await tester.tap(find.text('Delete this one'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the pills']);
    });

    testWidgets('deleting this and later keeps the days before it', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');

      // Cut the series two days out, not on the day it began.
      await stepDay(tester, 2);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget, reason: 'later');

      await stepDay(tester, -2);
      expect(visibleTitles(tester), [
        'Take the pills',
      ], reason: 'the day before');

      await stepDay(tester, -1);
      expect(visibleTitles(tester), [
        'Take the pills',
      ], reason: 'the first day');
    });

    testWidgets('the first day still offers the later ones', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this one'), findsOneWidget);
      expect(
        find.text('Delete this and later ones'),
        findsOneWidget,
        reason: 'tomorrow is already there, written down or not',
      );
      expect(find.text('Delete every one'), findsOneWidget);
      expect(
        find.text('Delete this and earlier ones'),
        findsNothing,
        reason: 'there is no earlier',
      );
    });

    testWidgets('the last day offers the earlier ones but not later', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');

      // End the run two days out, then stand on its final day.
      await stepDay(tester, 2);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      await stepDay(tester, -1);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this one'), findsOneWidget);
      expect(find.text('Delete this and earlier ones'), findsOneWidget);
      expect(find.text('Delete every one'), findsOneWidget);
      expect(find.text('Delete this and later ones'), findsNothing);
    });

    testWidgets('a task down to one showing deletes without asking', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');

      // Cut the future off tomorrow, leaving today as the only showing.
      await stepDay(tester, 1);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      await stepDay(tester, -1);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('This task repeats'), findsNothing);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('a day with showings either side offers all four', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await stepDay(tester, 2);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this one'), findsOneWidget);
      expect(find.text('Delete this and earlier ones'), findsOneWidget);
      expect(find.text('Delete this and later ones'), findsOneWidget);
      expect(find.text('Delete every one'), findsOneWidget);

      // Each scope carries its own icon, and the two ranges mirror each other.
      expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.keyboard_double_arrow_left_rounded),
        findsOneWidget,
      );
      expect(
        find.byIcon(Icons.keyboard_double_arrow_right_rounded),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    });

    testWidgets('deleting this and earlier keeps the days after it', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');

      // Cut two days out, so there are days on both sides of the cut.
      await stepDay(tester, 2);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this and earlier ones'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, -1);
      expect(find.text('Nothing planned'), findsOneWidget, reason: 'earlier');

      await stepDay(tester, -1);
      expect(
        find.text('Nothing planned'),
        findsOneWidget,
        reason: 'the first day',
      );

      await stepDay(tester, 3);
      expect(visibleTitles(tester), [
        'Take the pills',
      ], reason: 'the day after');
    });

    testWidgets('the two halves meet without overlapping', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');

      // Cut the future off at day three, then the past off at day one.
      await stepDay(tester, 3);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      await stepDay(tester, -2);
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete this and earlier ones'));
      await tester.pumpAndSettle();

      // Only day two is left standing.
      expect(find.text('Nothing planned'), findsOneWidget);
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the pills']);
      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('a one-off still deletes without being asked', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Buy milk');
      await openActions(tester, 'Buy milk');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('This task repeats'), findsNothing);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('deleting every one clears it from other days too', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete every one'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('editing a repeating task changes it on every day', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // The editor opens on the rule already in force.
      expect(find.text('Every day'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Take the vitamins');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Take the vitamins']);
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the vitamins']);
    });

    testWidgets('turning off repeat leaves the task on this day only', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await chooseRepeat(tester, 'Never');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Take the pills']);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);

      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('a one-off can be turned into a repeating task', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills');
      await openActions(tester, 'Take the pills');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await chooseRepeat(tester, 'Every day');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the pills']);
    });

    testWidgets('a repeating task can be dragged into a new order', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam');

      await dragCardDown(tester, from: 'Take the pills', over: 'Call Sam');

      expect(visibleTitles(tester), ['Buy milk', 'Take the pills', 'Call Sam']);
    });
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

  group('settings', () {
    testWidgets('the gear at the bottom right opens the settings screen', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      final gear = find.byIcon(Icons.settings_outlined);
      expect(gear, findsOneWidget);
      final bar = tester.getRect(find.byType(BrandedBottomBar));
      final at = tester.getCenter(gear);
      expect(at.dx, greaterThan(bar.center.dx), reason: 'on the right');
      expect(at.dy, greaterThan(bar.top));
      expect(at.dy, lessThan(bar.bottom));

      await tester.tap(gear);
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Theme'), findsOneWidget);
      for (final choice in AppThemeChoice.values) {
        expect(find.text(choice.label), findsOneWidget);
      }

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Add a task'), findsOneWidget);
    });

    testWidgets('the gear does not open the editor', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('picking a look recolours the whole app and is saved', (
      tester,
    ) async {
      final settings = MemorySettingsStore();
      await tester.pumpWidget(bootApp(settings: settings));
      await tester.pumpAndSettle();

      final ink = AppTheme.schemeFor(AppThemeChoice.ink, Brightness.light);
      expect(homeScheme(tester).primary, ink.primary);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocean'));
      await tester.pumpAndSettle();

      final ocean = AppTheme.schemeFor(AppThemeChoice.ocean, Brightness.light);
      expect(homeScheme(tester).primary, ocean.primary);
      expect(homeScheme(tester).surface, ocean.surface);
      expect(settings.values[ThemeChoice.settingKey], 'ocean');

      // The tick moved to the new choice.
      final ticked = tester
          .widgetList<BrandedOptionRow>(find.byType(BrandedOptionRow))
          .where((row) => row.selected)
          .map((row) => row.label);
      expect(ticked, ['Ocean']);
    });

    testWidgets('the app comes up in the look it was left in', (tester) async {
      await tester.pumpWidget(bootApp(theme: AppThemeChoice.forest));
      await tester.pumpAndSettle();

      final forest = AppTheme.schemeFor(
        AppThemeChoice.forest,
        Brightness.light,
      );
      expect(homeScheme(tester).primary, forest.primary);
    });
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
