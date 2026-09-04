import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/app.dart';
import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/reminder_sound.dart';
import 'package:remind_me/reminders/reminder_scheduler.dart';
import 'package:remind_me/state/last_sound.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/state/theme_choice.dart';
import 'package:remind_me/state/todos_controller.dart';
import 'package:remind_me/ui/branded/branded.dart';
import 'package:remind_me/ui/home_page.dart';
import 'package:remind_me/ui/settings_page.dart';
import 'package:remind_me/ui/widgets/date_header.dart';
import 'package:remind_me/ui/widgets/todo_list_view.dart';
import 'package:remind_me/ui/widgets/todo_tile.dart';

import 'support/memory_device_bridge.dart';
import 'support/memory_reminder_scheduler.dart';
import 'support/memory_settings_store.dart';
import 'support/memory_todo_store.dart';

Widget bootApp({
  MemoryTodoStore? store,
  MemorySettingsStore? settings,
  MemoryReminderScheduler? scheduler,
  MemoryDeviceBridge? device,
  DateTime Function()? clock,
  AppThemeChoice theme = AppThemeChoice.ink,
  ReminderSound sound = ReminderSound.system,
}) => ProviderScope(
  overrides: [
    todoStoreProvider.overrideWithValue(store ?? MemoryTodoStore()),
    settingsStoreProvider.overrideWithValue(settings ?? MemorySettingsStore()),
    reminderSchedulerProvider.overrideWithValue(
      scheduler ?? MemoryReminderScheduler(),
    ),
    deviceBridgeProvider.overrideWithValue(device ?? MemoryDeviceBridge()),
    if (clock != null) clockProvider.overrideWithValue(clock),
    initialThemeChoiceProvider.overrideWithValue(theme),
    initialSoundProvider.overrideWithValue(sound),
  ],
  child: const RemindMeApp(),
);

/// A moment on the real today, since the list opens on the real today.
DateTime at(int hour, int minute) {
  final today = todayDate();
  return DateTime(today.year, today.month, today.day, hour, minute);
}

const int _minutesPerHour = 60;
int minuteOf(int hour, int minute) => hour * _minutesPerHour + minute;

/// The card for [title], as built.
TodoTile tileFor(WidgetTester tester, String title) => tester.widget<TodoTile>(
  find.ancestor(of: find.text(title), matching: find.byType(TodoTile)),
);

/// Turns the pulse off, the way the system's reduce-motion setting does, so
/// the tester's settle has something to settle on. A calling card breathes
/// without end otherwise.
void holdStill(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

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
/// Pass [repeat] to also work the repeat picker, naming the option to choose,
/// and [due] to work the time chooser.
Future<void> addTask(
  WidgetTester tester,
  String title, {
  String? repeat,
  Due? due,
}) async {
  await tester.tap(find.text('Add a task'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.pump();
  if (due != null) await chooseDue(tester, due);
  if (repeat != null) await chooseRepeat(tester, repeat);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// Opens the time chooser from the editor, turns the wheel to [due] and
/// picks its reminder. The wheel is turned by hand rather than dragged, since
/// what matters here is what comes back.
Future<void> chooseDue(WidgetTester tester, Due due) async {
  await tester.tap(find.text('Due'));
  await tester.pumpAndSettle();
  tester
      .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
      .onDateTimeChanged(
        DateTime(2000, 1, 1, due.minute ~/ 60, due.minute % 60),
      );
  await tester.pump();
  for (final before in due.reminders) {
    await tester.tap(find.byKey(ValueKey('reminder-$before')));
    await tester.pump();
  }
  if (due.sound != ReminderSound.system) {
    await tester.ensureVisible(find.byKey(const ValueKey('reminder-sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reminder-sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('sound-${due.sound.name}')));
    await tester.pump();
    // The due sheet's own Done is still in the tree underneath.
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
  }
  await finishDueSheet(tester);
}

/// The due sheet is taller than a small screen, so Done is scrolled to.
Future<void> finishDueSheet(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Done'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

/// Opens the repeat picker from the editor and settles on one option.
///
/// "Every month" opens the day chooser on its own screen; [monthDays] names
/// the dots to tap there before coming back, on top of the default one.
Future<void> chooseRepeat(
  WidgetTester tester,
  String option, {
  List<String> monthDays = const [],
}) async {
  await tester.tap(find.text('Repeat'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
  if (option == 'Every month') {
    for (final day in monthDays) {
      await tester.tap(find.byKey(ValueKey('month-day-$day')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('month-days-done')));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

/// Whether the day chooser shows [day] as picked.
bool monthDayPicked(WidgetTester tester, int day) => tester
    .widget<BrandedSelectionCircle>(
      find.descendant(
        of: find.byKey(ValueKey('month-day-$day')),
        matching: find.byType(BrandedSelectionCircle),
      ),
    )
    .selected;

/// Walks the header to the next day on or after today whose day of the
/// month satisfies [test].
Future<DateTime> stepToDay(
  WidgetTester tester,
  bool Function(DateTime) test,
) async {
  final today = DateTime.now().startOfDay;
  var target = today;
  while (!test(target)) {
    target = target.addDays(1);
  }
  await stepDay(tester, target.epochDay - today.epochDay);
  return target;
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

/// Swipes a card to uncover the button for [action] and taps it. Done, Not
/// done and Edit live on the leading side, Delete on the trailing side.
Future<void> actOn(
  WidgetTester tester,
  String title,
  String action, {
  bool settle = true,
}) async {
  final (direction, icon) = switch (action) {
    'Done' => (const Offset(200, 0), Icons.check_rounded),
    'Not done' => (const Offset(200, 0), Icons.remove_done_rounded),
    'Edit' => (const Offset(200, 0), Icons.edit_outlined),
    'Delete' => (const Offset(-160, 0), Icons.delete_outline_rounded),
    _ => throw ArgumentError.value(action, 'action'),
  };
  await swipe(tester, title, direction);
  await tester.tap(find.byIcon(icon));
  if (settle) {
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Holds a card until it lifts, then drags it down over another one.
Future<void> dragCardDown(
  WidgetTester tester, {
  required String from,
  required String over,
}) async {
  final start = tester.getCenter(find.text(from));
  final target = tester.getCenter(find.text(over));

  final gesture = await tester.startGesture(start);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
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
    await tester.pump();
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

  testWidgets('tapping a card, once or twice, opens nothing', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    final tile = find.text('Buy milk');
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(visibleTitles(tester), ['Buy milk']);
  });

  testWidgets('save stays greyed until there are words', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();

    BrandedTextButton button(String label) => tester.widget<BrandedTextButton>(
      find.widgetWithText(BrandedTextButton, label),
    );
    expect(button('Save').enabled, isFalse);
    expect(button('Cancel').enabled, isTrue);
    expect(button('Cancel').tone, BrandedTone.primary);

    // Tapping the greyed button goes nowhere.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOneWidget);

    // Blank space does not count as words.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(button('Save').enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.pump();
    expect(button('Save').enabled, isTrue);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Buy milk']);
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

    await actOn(tester, 'Buy milk', 'Edit');

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Buy milk'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Buy oat milk');
    await tester.pump();
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

  testWidgets('open tasks can be lifted, completed ones cannot', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    expect(find.byType(BrandedDragLift), findsNWidgets(2));
    expect(
      find.byIcon(Icons.drag_indicator_rounded),
      findsNothing,
      reason: 'no grip takes room from the words',
    );

    await actOn(tester, 'Buy milk', 'Done');
    expect(find.byType(BrandedDragLift), findsOneWidget);
  });

  testWidgets('a quick press does not lift the card', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Post letter');

    // Moving before the hold is up is a scroll, not a reorder.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Buy milk')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('Post letter')));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);
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
    await tester.pump();
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

    testWidgets('the chooser offers this day, not a leftover from the rule', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      // A weekly rule carries no meaningful day of the month, so the chooser
      // must start from the day being looked at.
      final today = await stepToDay(tester, (date) => date.day <= 28);
      await addTask(tester, 'Team sync', repeat: 'Every week');
      await actOn(tester, 'Team sync', 'Edit');
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();

      expect(find.text('Every month'), findsOneWidget);
      await tester.tap(find.text('Every month'));
      await tester.pumpAndSettle();

      expect(monthDayPicked(tester, today.day), isTrue);
      for (var day = 1; day <= 28; day++) {
        if (day != today.day) expect(monthDayPicked(tester, day), isFalse);
      }
    });

    testWidgets('the chooser shows 29 to 31 greyed and will not take them', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await stepToDay(tester, (date) => date.day <= 28);
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every month'));
      await tester.pumpAndSettle();

      for (final day in [29, 30, 31]) {
        expect(find.byKey(ValueKey('month-day-$day')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('month-day-$day')));
        await tester.pumpAndSettle();
        expect(monthDayPicked(tester, day), isFalse, reason: 'day $day');
      }
      expect(find.text('Last day of every month'), findsOneWidget);
    });

    testWidgets('past the 28th the chooser starts on the last day', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await stepToDay(tester, (date) => date.day > 28);
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every month'));
      await tester.pumpAndSettle();

      final lastDay = tester.widget<BrandedOptionRow>(
        find.byKey(const ValueKey('month-last-day')),
      );
      expect(lastDay.selected, isTrue);
      for (var day = 1; day <= 28; day++) {
        expect(monthDayPicked(tester, day), isFalse);
      }
    });

    testWidgets('several days of the month all fire, and the sheet says so', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      final first = await stepToDay(tester, (date) => date.day == 1);
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pay the rent');
      await tester.pump();
      await chooseRepeat(tester, 'Every month', monthDays: ['15']);

      // Back on the editor, the field spells the days out.
      expect(find.text('Every month'), findsOneWidget);
      expect(find.text('On the 1st and 15th'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Pay the rent']);
      await stepDay(tester, 14);
      expect(visibleTitles(tester), ['Pay the rent'], reason: 'the 15th');
      await stepDay(tester, -1);
      expect(find.text('Nothing planned'), findsOneWidget);

      // And the next month's 1st.
      final next = DateTime(first.year, first.month + 1, 1);
      await stepDay(tester, next.epochDay - (first.epochDay + 13));
      expect(visibleTitles(tester), ['Pay the rent']);
    });

    testWidgets('the last day lands on the end of the next month too', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      final date = await stepToDay(
        tester,
        (date) => date.day == daysInMonth(date),
      );
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pay the rent');
      await tester.pump();
      await chooseRepeat(tester, 'Every month');
      expect(find.text('On the last day'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Pay the rent']);
      final next = DateTime(date.year, date.month + 2, 0);
      await stepDay(tester, next.epochDay - date.epochDay);
      expect(visibleTitles(tester), ['Pay the rent']);
      await stepDay(tester, -1);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('backing out of the chooser leaves the rule as it was', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await actOn(tester, 'Take the pills', 'Edit');
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Still on the sheet, still daily.
      final ticked = tester
          .widgetList<BrandedOptionRow>(find.byType(BrandedOptionRow))
          .where((row) => row.selected)
          .map((row) => row.label);
      expect(ticked, ['Every day']);
    });

    testWidgets('the chooser never lets every day be cleared', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      final today = await stepToDay(tester, (date) => date.day <= 28);
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every month'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('month-day-${today.day}')));
      await tester.pumpAndSettle();
      expect(monthDayPicked(tester, today.day), isTrue);
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
      await tester.pump();
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
      await actOn(tester, 'Take the pills', 'Delete');

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
      await actOn(tester, 'Take the pills', 'Delete');
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
      await actOn(tester, 'Take the pills', 'Delete');

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
      await actOn(tester, 'Take the pills', 'Delete');
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      await stepDay(tester, -1);
      await actOn(tester, 'Take the pills', 'Delete');

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
      await actOn(tester, 'Take the pills', 'Delete');
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      await stepDay(tester, -1);
      await actOn(tester, 'Take the pills', 'Delete');

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
      await actOn(tester, 'Take the pills', 'Delete');

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
      await actOn(tester, 'Take the pills', 'Delete');
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
      await actOn(tester, 'Take the pills', 'Delete');
      await tester.tap(find.text('Delete this and later ones'));
      await tester.pumpAndSettle();

      await stepDay(tester, -2);
      await actOn(tester, 'Take the pills', 'Delete');
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
      await actOn(tester, 'Buy milk', 'Delete');

      expect(find.text('This task repeats'), findsNothing);
      expect(find.text('Nothing planned'), findsOneWidget);
    });

    testWidgets('deleting every one clears it from other days too', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await actOn(tester, 'Take the pills', 'Delete');
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
      await actOn(tester, 'Take the pills', 'Edit');

      // The editor opens on the rule already in force.
      expect(find.text('Every day'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Take the vitamins');
      await tester.pump();
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
      await actOn(tester, 'Take the pills', 'Edit');
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
      await actOn(tester, 'Take the pills', 'Edit');
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

  testWidgets('a swipe across the day turns the page', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    // Below the cards, where nothing else wants the swipe.
    final open =
        tester.getCenter(find.byType(TodoListView)) + const Offset(0, 150);
    await tester.fling(find.byType(DateHeader), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow'), findsOneWidget);

    await tester.flingFrom(open, const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    await tester.flingFrom(open, const Offset(300, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('a slow pull far enough turns the page too', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    // Dragged and held, so there is no speed at the lift.
    final start = tester.getCenter(find.byType(TodoListView));
    final gesture = await tester.startGesture(start);
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(-12, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow'), findsOneWidget);

    // A short pull is taken back.
    final short = await tester.startGesture(start);
    await short.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await short.up();
    await tester.pumpAndSettle();
    expect(find.text('Tomorrow'), findsOneWidget);
  });

  testWidgets('a swipe on a card still works the card, not the day', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await tester.fling(find.text('Buy milk'), const Offset(-200, 0), 800);
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('the keyboard is asked for after the editor has arrived', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    FocusNode fieldFocus() =>
        tester.widget<TextField>(find.byType(TextField)).focusNode!;
    expect(fieldFocus().hasFocus, isFalse, reason: 'still sliding in');

    await tester.pumpAndSettle();
    expect(fieldFocus().hasFocus, isTrue);
  });

  group('not today', () {
    final today = todayDate().epochDay;

    /// Swipes a card open on the trailing side and taps the NOT TODAY glyph.
    Future<void> notToday(WidgetTester tester, String title) async {
      await swipe(tester, title, const Offset(-200, 0));
      await tester.tap(find.text('NOT'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends a task to a day picked on the grid', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam');

      await notToday(tester, 'Buy milk');
      expect(find.byKey(ValueKey('pick-day-${today + 1}')), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('pick-day-${today + 2}')));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Call Sam']);
      await stepDay(tester, 2);
      expect(visibleTitles(tester), ['Buy milk']);
    });

    testWidgets('the grid will not take the past or the day itself', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await notToday(tester, 'Buy milk');

      await tester.tap(find.byKey(ValueKey('pick-day-$today')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('pick-day-$today')), findsOneWidget);
      // Yesterday may sit in last month, off the grid that opened.
      final yesterday = find.byKey(ValueKey('pick-day-${today - 1}'));
      if (yesterday.evaluate().isNotEmpty) {
        await tester.tap(yesterday);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('pick-day-$today')), findsOneWidget);
      }
      expect(
        find.widgetWithText(BrandedTextButton, 'Today'),
        findsNothing,
        reason: 'no shortcut back',
      );

      // Swiped away: nothing moved.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Buy milk']);
    });

    testWidgets('a completed task has nowhere to go', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await actOn(tester, 'Buy milk', 'Done');

      await swipe(tester, 'Buy milk', const Offset(-200, 0));
      expect(find.text('NOT'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('a showing of a repeating task is copied off the series', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Take the pills', repeat: 'Every day');

      await notToday(tester, 'Take the pills');
      await tester.tap(find.byKey(ValueKey('pick-day-${today + 2}')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing planned'), findsOneWidget);

      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the pills'], reason: 'the rule');
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Take the pills', 'Take the pills']);
      final tiles = tester.widgetList<TodoTile>(find.byType(TodoTile));
      expect(tiles.where((t) => t.todo.repeats), hasLength(1));
      expect(tiles.where((t) => !t.todo.repeats), hasLength(1));
    });

    testWidgets('a calling task can be sent on from its sheet', (tester) async {
      holdStill(tester);
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Call Sam',
        due: Due(minute: minuteOf(8, 30), reminders: const {0}),
      );
      expect(tileFor(tester, 'Call Sam').calling, isTrue);

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not today'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('pick-day-${today + 1}')));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);
      expect(scheduler.pending.single.day, today + 1);
      expect(
        scheduler.pending.single.fireAt,
        dateFromEpochDayAt(today + 1, minuteOf(8, 30)),
      );
      await stepDay(tester, 1);
      expect(tileFor(tester, 'Call Sam').calling, isFalse);
    });
  });

  testWidgets('a change of day slides the old page out and the new one in', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
    await tester.pump();
    await tester.pump(Brand.turn ~/ 2);

    // Both pages are on screen midway, the old one moving off.
    expect(find.byType(DateHeader), findsNWidgets(2));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Tomorrow')).dx,
      greaterThan(tester.getCenter(find.text('Today')).dx),
      reason: 'tomorrow comes in from the right',
    );
    expect(find.text('Buy milk'), findsOneWidget, reason: 'the old list stays');

    await tester.pumpAndSettle();
    expect(find.byType(DateHeader), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pump();
    await tester.pump(Brand.turn ~/ 2);
    expect(
      tester.getCenter(find.text('Today')).dx,
      lessThan(tester.getCenter(find.text('Tomorrow')).dx),
      reason: 'and goes back out the way it came',
    );
    await tester.pumpAndSettle();
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
      expect(find.text('Reminders'), findsOneWidget);
      // The title sits on the centre line, Done or no Done beside it.
      final screen = tester.getSize(find.byType(SettingsPage));
      expect(
        tester.getCenter(find.text('Settings')).dx,
        closeTo(screen.width / 2, 1),
      );

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      for (final choice in AppThemeChoice.values) {
        expect(find.text(choice.label), findsAtLeastNWidgets(1));
      }
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('theme-ink')), findsNothing);

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
      final device = MemoryDeviceBridge();
      await tester.pumpWidget(bootApp(settings: settings, device: device));
      await tester.pumpAndSettle();

      final ink = AppTheme.schemeFor(AppThemeChoice.ink, Brightness.light);
      expect(homeScheme(tester).primary, ink.primary, reason: 'shipped');

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocean'));
      await tester.pumpAndSettle();

      final ocean = AppTheme.schemeFor(AppThemeChoice.ocean, Brightness.light);
      expect(homeScheme(tester).primary, ocean.primary);
      expect(homeScheme(tester).surface, ocean.surface);
      expect(settings.values[ThemeChoice.settingKey], 'ocean');
      expect(device.icon, AppThemeChoice.ocean, reason: 'the icon follows');

      // The tick moved to the new choice.
      final ticked = tester
          .widgetList<BrandedOptionRow>(find.byType(BrandedOptionRow))
          .where((row) => row.selected)
          .map((row) => row.label);
      expect(ticked, ['Ocean']);
    });

    testWidgets('the notifications row asks, then sends to Settings', (
      tester,
    ) async {
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(bootApp(scheduler: scheduler));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Not asked yet'), findsOneWidget);
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(scheduler.permissionAsks, 1);
      expect(find.text('Allowed'), findsOneWidget);

      // Once allowed, the row leads to the system's own page.
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(scheduler.settingsOpened, 1);
      expect(scheduler.permissionAsks, 1, reason: 'not asked twice');
    });

    testWidgets('a refusal is said so, and the row leads to Settings', (
      tester,
    ) async {
      final scheduler = MemoryReminderScheduler(
        status: ReminderPermission.denied,
      );
      await tester.pumpWidget(bootApp(scheduler: scheduler));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Not allowed'), findsOneWidget);
      expect(find.text('Turn on in Settings'), findsOneWidget);
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();
      expect(scheduler.settingsOpened, 1);
      expect(scheduler.permissionAsks, 0);
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

  group('due times', () {
    final today = todayDate().epochDay;

    testWidgets('the editor offers a time, above repeat', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();

      expect(find.text('Due'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Due')).dy,
        lessThan(tester.getTopLeft(find.text('Repeat')).dy),
      );
    });

    testWidgets('a time shows on the row, then on the card', (tester) async {
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Call Sam');
      await chooseDue(tester, Due(minute: minuteOf(14, 30)));

      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.text('None'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
      expect(scheduler.pending, isEmpty, reason: 'no reminder was asked for');
      expect(scheduler.permissionAsks, 0);
    });

    testWidgets('the card keeps a 24-hour clock when the device does', (
      tester,
    ) async {
      // The app reads the device's clock setting through the platform data
      // above it, which is where a test can set it.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: bootApp(clock: () => at(9, 0)),
        ),
      );
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(14, 30)));

      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('a reminder asks the system once and is laid down', (
      tester,
    ) async {
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Call Sam\nabout the invoice',
        due: Due(minute: minuteOf(14, 30), reminders: const {15}),
      );

      expect(scheduler.permissionAsks, 1);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(scheduler.pending, hasLength(1));
      expect(scheduler.pending.single.fireAt, at(14, 15));
      expect(scheduler.pending.single.title, 'Call Sam');
      expect(scheduler.pending.single.day, today);

      // The editor row says what was chosen.
      await actOn(tester, 'Call Sam', 'Edit');
      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.text('15 min before'), findsOneWidget);
    });

    testWidgets('the reminders laid down follow the list', (tester) async {
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Take the pills',
        repeat: 'Every day',
        due: Due(minute: minuteOf(20, 0), reminders: const {0}),
      );
      expect(
        scheduler.pending,
        hasLength(15),
        reason: 'today and the fortnight after it',
      );

      await actOn(tester, 'Take the pills', 'Done');
      expect(scheduler.pending, hasLength(14), reason: 'today is done with');

      await actOn(tester, 'Take the pills', 'Delete');
      await tester.tap(find.text('Delete every one'));
      await tester.pumpAndSettle();
      expect(scheduler.pending, isEmpty);
    });

    testWidgets('the time sits under the words, with the repeat mark', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Take the pills',
        repeat: 'Every day',
        due: Due(minute: minuteOf(14, 30), reminders: const {5}),
      );

      final words = tester.getRect(find.text('Take the pills'));
      final time = tester.getRect(find.text('2:30 PM'));
      expect(time.top, greaterThanOrEqualTo(words.bottom));
      expect(
        tester.getRect(find.byIcon(Icons.repeat_rounded)).top,
        greaterThanOrEqualTo(words.bottom),
        reason: 'nothing sits beside the words',
      );
      expect(
        tester.getRect(find.byIcon(Icons.notifications_none_rounded)).top,
        greaterThanOrEqualTo(words.bottom),
      );
    });

    testWidgets('several reminders can be chosen, each laid down', (
      tester,
    ) async {
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Call Sam',
        due: Due(minute: minuteOf(14, 30), reminders: const {0, 15, 60}),
      );

      expect(scheduler.pending.map((p) => p.fireAt), [
        at(13, 30),
        at(14, 15),
        at(14, 30),
      ]);
      await actOn(tester, 'Call Sam', 'Edit');
      expect(find.text('At 2:30 PM, 15 min, 1 hr before'), findsOneWidget);

      // Tapping a chosen one again takes it off.
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-15')));
      await tester.pump();
      await finishDueSheet(tester);
      expect(find.text('At 2:30 PM, 1 hr before'), findsOneWidget);
    });

    testWidgets('a day-ahead reminder is offered and fires the day before', (
      tester,
    ) async {
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await stepDay(tester, 1);
      await addTask(
        tester,
        'Dentist',
        due: Due(minute: minuteOf(10, 0), reminders: const {Due.minutesPerDay}),
      );
      expect(find.text('1 day before'), findsNothing);
      expect(scheduler.pending.single.fireAt, at(10, 0));
    });

    testWidgets('a sound can be picked and is heard on the way', (
      tester,
    ) async {
      final scheduler = MemoryReminderScheduler();
      final device = MemoryDeviceBridge();
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, device: device, clock: () => at(9, 0)),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Call Sam',
        due: Due(
          minute: minuteOf(14, 30),
          reminders: const {5},
          sound: ReminderSound.bell,
        ),
      );

      expect(device.previewed, [ReminderSound.bell]);
      expect(scheduler.pending.single.sound, ReminderSound.bell);

      await actOn(tester, 'Call Sam', 'Edit');
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(find.text('Bell'), findsOneWidget, reason: 'the sound row');
    });

    testWidgets('the sound chosen last time is offered next time', (
      tester,
    ) async {
      final settings = MemorySettingsStore();
      final scheduler = MemoryReminderScheduler(
        status: ReminderPermission.granted,
      );
      await tester.pumpWidget(
        bootApp(
          settings: settings,
          scheduler: scheduler,
          clock: () => at(9, 0),
        ),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Call Sam',
        due: Due(
          minute: minuteOf(14, 30),
          reminders: const {5},
          sound: ReminderSound.harp,
        ),
      );
      expect(settings.values[LastSound.settingKey], 'harp');

      // A new task's chooser opens on Harp without being told.
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(find.text('Harp'), findsOneWidget);
      await finishDueSheet(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('the sound comes back after a relaunch', (tester) async {
      final settings = MemorySettingsStore({LastSound.settingKey: 'bell'});
      expect(await LastSound.load(settings), ReminderSound.bell);
      expect(await LastSound.load(MemorySettingsStore()), ReminderSound.system);

      await tester.pumpWidget(bootApp(sound: ReminderSound.bell));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      expect(find.text('Bell'), findsOneWidget);
    });

    testWidgets('a task whose time has come heads the list, calling', (
      tester,
    ) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));

      expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
      expect(tileFor(tester, 'Call Sam').calling, isTrue);
      expect(tileFor(tester, 'Buy milk').calling, isFalse);
    });

    testWidgets('a task rises the minute it falls due', (tester) async {
      holdStill(tester);
      var now = at(9, 0);
      await tester.pumpWidget(bootApp(clock: () => now));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(9, 30)));
      expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
      expect(tileFor(tester, 'Call Sam').calling, isFalse);

      now = at(9, 30);
      await tester.pump(const Duration(minutes: 30));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
      expect(tileFor(tester, 'Call Sam').calling, isTrue);
    });

    testWidgets('coming back to the front reads the day again', (tester) async {
      holdStill(tester);
      var now = at(9, 0);
      final store = MemoryTodoStore();
      await store.insert(day: today, title: 'Buy milk');
      await store.insert(
        day: today,
        title: 'Call Sam',
        due: Due(minute: minuteOf(9, 30)),
      );
      await tester.pumpWidget(bootApp(store: store, clock: () => now));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);

      now = at(9, 45);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
    });

    testWidgets('a calling card breathes, and holds still if motion is off', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      await store.insert(
        day: today,
        title: 'Call Sam',
        due: Due(minute: minuteOf(8, 30)),
      );
      await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
      await tester.pump();
      await tester.pump(Brand.breath);
      expect(tester.hasRunningAnimations, isTrue);
      expect(tileFor(tester, 'Call Sam').calling, isTrue);

      holdStill(tester);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a plain card does not breathe', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(9, 30)));
      await tester.pump(Brand.breath);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('tapping a calling card puts up the sheet, words and all', (
      tester,
    ) async {
      holdStill(tester);
      final store = MemoryTodoStore();
      await store.insert(
        day: today,
        title: 'Call Sam\nabout the invoice',
        due: Due(minute: minuteOf(8, 30)),
      );
      await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      expect(find.text('Call Sam\nabout the invoice'), findsNothing);

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
      expect(find.text('Call Sam\nabout the invoice'), findsOneWidget);
      expect(find.text('Due 8:30 AM'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Snooze'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('done from the sheet completes it', (tester) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pump(reorderDelay);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('attention-title')), findsNothing);
      expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
      expect(tileFor(tester, 'Call Sam').todo.done, isTrue);
      expect(tileFor(tester, 'Call Sam').calling, isFalse);
    });

    testWidgets('snooze puts it off from now, and it calls again then', (
      tester,
    ) async {
      holdStill(tester);
      var now = at(9, 0);
      final scheduler = MemoryReminderScheduler();
      await tester.pumpWidget(bootApp(scheduler: scheduler, clock: () => now));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
      expect(tileFor(tester, 'Call Sam').calling, isFalse);
      expect(find.text('9:10 AM'), findsOneWidget);
      expect(scheduler.pending, hasLength(1), reason: 'a fresh notification');
      expect(scheduler.pending.single.fireAt, at(9, 10));

      now = at(9, 10);
      await tester.pump(const Duration(minutes: 10));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
      expect(tileFor(tester, 'Call Sam').calling, isTrue);
    });

    testWidgets('dismiss quiets it for the day but keeps its time', (
      tester,
    ) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
      expect(tileFor(tester, 'Call Sam').calling, isFalse);
      expect(find.text('8:30 AM'), findsOneWidget);

      // Tapping it now does nothing, like any other card.
      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attention-title')), findsNothing);
    });

    testWidgets('a snooze or dismissal on a repeating task is for today', (
      tester,
    ) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Take the pills',
        repeat: 'Every day',
        due: Due(minute: minuteOf(8, 30)),
      );
      await tester.tap(find.text('Take the pills'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Take the pills').todo.dismissed, isTrue);

      await stepDay(tester, 1);
      expect(tileFor(tester, 'Take the pills').todo.dismissed, isFalse);
      expect(find.text('8:30 AM'), findsOneWidget);
    });

    testWidgets('a calling card holds the top and cannot be lifted', (
      tester,
    ) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Post letter');
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));
      expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);

      await dragCardDown(tester, from: 'Call Sam', over: 'Post letter');
      expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);

      // A drag aimed above it lands just under it.
      final start = tester.getCenter(find.text('Post letter'));
      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getTopLeft(find.text('Call Sam')));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Call Sam', 'Post letter', 'Buy milk']);
    });

    testWidgets('editing a repeating task changes its time on every day', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Take the pills',
        repeat: 'Every day',
        due: Due(minute: minuteOf(14, 30)),
      );
      await actOn(tester, 'Take the pills', 'Edit');
      await chooseDue(tester, Due(minute: minuteOf(15, 0)));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('3:00 PM'), findsOneWidget);
      await stepDay(tester, 1);
      expect(find.text('3:00 PM'), findsOneWidget);
    });

    testWidgets('clearing the time takes it off the card', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(14, 30)));

      await actOn(tester, 'Call Sam', 'Edit');
      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('None'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('2:30 PM'), findsNothing);
    });

    testWidgets('backing out of the chooser leaves the time as it was', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Call Sam');
      await chooseDue(
        tester,
        Due(minute: minuteOf(14, 30), reminders: const {5}),
      );

      await tester.tap(find.text('Due'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-60')));
      await tester.pump();
      // Swiped away rather than finished.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('2:30 PM'), findsOneWidget);
      expect(find.text('5 min before'), findsOneWidget);
    });

    testWidgets(
      'a tapped notification turns to the day and puts up the sheet',
      (tester) async {
        holdStill(tester);
        final store = MemoryTodoStore();
        await store.insert(day: today, title: 'Buy milk');
        final tomorrow = await store.insert(
          day: today + 1,
          title: 'Call Sam\nabout the invoice',
          due: Due(minute: minuteOf(8, 30), reminders: const {0}),
        );
        await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
        await tester.pumpAndSettle();
        expect(find.text('Today'), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomePage)),
        );
        container
            .read(attentionRequestProvider.notifier)
            .raiseFromPayload('${today + 1}:${tomorrow.key}');
        await tester.pumpAndSettle();

        expect(find.text('Tomorrow'), findsOneWidget);
        expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
        expect(find.text('Call Sam\nabout the invoice'), findsOneWidget);
        expect(container.read(attentionRequestProvider), isNull);

        await tester.tap(find.text('Done'));
        await tester.pump(reorderDelay);
        await tester.pumpAndSettle();
        expect(tileFor(tester, 'Call Sam').todo.done, isTrue);
      },
    );

    testWidgets('a notification for a task since gone opens the day only', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      final gone = await store.insert(
        day: today + 1,
        title: 'Call Sam',
        due: Due(minute: minuteOf(8, 30), reminders: const {0}),
      );
      await store.remove(day: today + 1, todo: gone);
      await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
      await tester.pumpAndSettle();

      ProviderScope.containerOf(tester.element(find.byType(HomePage)))
          .read(attentionRequestProvider.notifier)
          .raise(today + 1, gone.key);
      await tester.pumpAndSettle();

      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.byKey(const ValueKey('attention-title')), findsNothing);
    });

    testWidgets('a notification tapped while the editor is open closes it', (
      tester,
    ) async {
      holdStill(tester);
      final store = MemoryTodoStore();
      final todo = await store.insert(
        day: today,
        title: 'Call Sam',
        due: Due(minute: minuteOf(8, 30), reminders: const {0}),
      );
      await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(HomePage, skipOffstage: false)),
      ).read(attentionRequestProvider.notifier).raise(today, todo.key);
      await tester.pumpAndSettle();

      expect(find.text('New task'), findsNothing);
      expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
    });

    testWidgets('a notification raised before the first frame is answered', (
      tester,
    ) async {
      holdStill(tester);
      final store = MemoryTodoStore();
      final todo = await store.insert(
        day: today,
        title: 'Call Sam',
        due: Due(minute: minuteOf(8, 30), reminders: const {0}),
      );
      final container = ProviderContainer(
        overrides: [
          todoStoreProvider.overrideWithValue(store),
          settingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          reminderSchedulerProvider.overrideWithValue(
            MemoryReminderScheduler(),
          ),
          clockProvider.overrideWithValue(() => at(9, 0)),
        ],
      );
      addTearDown(container.dispose);
      container.read(attentionRequestProvider.notifier).raise(today, todo.key);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RemindMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
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
