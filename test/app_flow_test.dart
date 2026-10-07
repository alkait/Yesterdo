import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remind_me/app.dart';
import 'package:remind_me/core/app_theme.dart';
import 'package:remind_me/core/date_labels.dart';
import 'package:remind_me/core/day.dart';
import 'package:remind_me/data/due.dart';
import 'package:remind_me/data/reminder_sound.dart';
import 'package:remind_me/reminders/reminder_scheduler.dart';
import 'package:remind_me/state/developer_mode.dart';
import 'package:remind_me/state/last_sound.dart';
import 'package:remind_me/state/providers.dart';
import 'package:remind_me/state/recent_searches.dart';
import 'package:remind_me/state/theme_choice.dart';
import 'package:remind_me/state/todos_controller.dart';
import 'package:remind_me/ui/branded/branded.dart';
import 'package:remind_me/ui/home_page.dart';
import 'package:remind_me/ui/search_page.dart';
import 'package:remind_me/ui/settings_page.dart';
import 'package:remind_me/ui/widgets/date_header.dart';
import 'package:remind_me/ui/widgets/task_actions.dart';
import 'package:remind_me/ui/widgets/todo_list_view.dart';
import 'package:remind_me/ui/widgets/todo_card.dart';
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
  bool developer = false,
}) => ProviderScope(
  overrides: [
    todoStoreProvider.overrideWithValue(store ?? MemoryTodoStore()),
    settingsStoreProvider.overrideWithValue(settings ?? MemorySettingsStore()),
    reminderSchedulerProvider.overrideWithValue(
      scheduler ?? MemoryReminderScheduler(),
    ),
    deviceBridgeProvider.overrideWithValue(device ?? MemoryDeviceBridge()),
    imagesDirectoryProvider.overrideWithValue(device?.directory ?? ''),
    if (clock != null) clockProvider.overrideWithValue(clock),
    initialThemeChoiceProvider.overrideWithValue(theme),
    initialSoundProvider.overrideWithValue(sound),
    initialDeveloperModeProvider.overrideWithValue(developer),
  ],
  child: const YesterdoApp(),
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

/// Draws frames until a card for [title] is on screen, or gives up after a
/// few, so what is checked next is the card's very first frame.
Future<void> pumpUntilTile(WidgetTester tester, String title) async {
  for (var frame = 0; frame < 10; frame++) {
    await tester.pump();
    final tile = find.ancestor(
      of: find.text(title),
      matching: find.byType(TodoTile),
    );
    if (tile.evaluate().isNotEmpty) return;
  }
}

/// The providers behind the running app.
ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(HomePage, skipOffstage: false)),
);

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
  int? day,
}) async {
  await tester.tap(find.text('Add a task'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), title);
  await tester.pump();
  if (day != null) await chooseDay(tester, day);
  if (due != null) await chooseDue(tester, due);
  if (repeat != null) await chooseRepeat(tester, repeat);
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// Opens the date chooser from the editor and picks [day] off the grid.
Future<void> chooseDay(WidgetTester tester, int day) async {
  await tester.tap(find.text('Date'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('pick-day-$day')));
  await tester.pumpAndSettle();
}

/// Sets [due] the way a person does: the time on its sheet, then, if there
/// is one to set, the reminder and the sound on theirs. The wheel is turned
/// by hand rather than dragged, since what matters here is what comes back.
Future<void> chooseDue(WidgetTester tester, Due due) async {
  await tester.tap(find.text('Time'));
  await tester.pumpAndSettle();
  tester
      .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
      .onDateTimeChanged(
        DateTime(2000, 1, 1, due.minute ~/ 60, due.minute % 60),
      );
  await tester.pump();
  await finishSheet(tester);
  if (due.reminders.isEmpty && due.sound == ReminderSound.system) return;
  await tester.tap(find.text('Reminder'));
  await tester.pumpAndSettle();
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
    // The reminder sheet's own Done is still in the tree underneath.
    await tester.tap(find.text('Done').last);
    await tester.pumpAndSettle();
  }
  await finishSheet(tester);
}

/// A sheet can be taller than a small screen, so Done is scrolled to.
Future<void> finishSheet(WidgetTester tester) async {
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

/// Turns the page forward or back, a swipe a day, settling after each.
Future<void> stepDay(WidgetTester tester, int days) async {
  for (var step = 0; step < days.abs(); step++) {
    await swipeDay(tester, days > 0 ? 1 : -1);
    await tester.pumpAndSettle();
  }
}

/// One swipe across the day header: leftwards for tomorrow, rightwards
/// for yesterday. Not settled, so a test can look mid-turn.
Future<void> swipeDay(WidgetTester tester, int direction) => tester.fling(
  find.byType(DateHeader).first,
  Offset(direction > 0 ? -300 : 300, 0),
  800,
);

/// How much of the editor's prompt is showing. It is always in the tree, so
/// that the field beside it never moves; only its opacity says whether it is
/// meant to be seen.
double hintOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.text('What needs doing?'),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

/// The element behind the words being written. It has to be the same one
/// from keystroke to keystroke: a field rebuilt in a new place drops its
/// connection to the keyboard, and the keyboard goes down with it.
Element fieldElement(WidgetTester tester) =>
    tester.element(find.byType(EditableText).first);

/// Swipes a card to uncover the button for [action] and taps it. Done, Not
/// done and Edit live on the leading side, Delete on the trailing side.
Future<void> actOn(
  WidgetTester tester,
  String title,
  String action, {
  bool settle = true,
}) async {
  // Done and Not done are the circle on the card; the rest are swiped for.
  if (action == 'Done' || action == 'Not done') {
    await tester.tap(circleOn(title));
  } else {
    final (direction, icon) = switch (action) {
      'Edit' => (const Offset(200, 0), Icons.edit_outlined),
      'Delete' => (const Offset(-160, 0), Icons.delete_outline_rounded),
      _ => throw ArgumentError.value(action, 'action'),
    };
    await swipe(tester, title, direction);
    await tester.tap(find.byIcon(icon));
  }
  if (settle) {
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// The done circle on a task's card.
Finder circleOn(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(TodoTile)),
  matching: find.byType(BrandedCheckBox),
);

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

  testWidgets('the empty editor prompts for words', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    expect(hintOpacity(tester), 1);

    // The prompt goes as soon as there are words, and the guard character
    // the field carries does not count as any. It stays in the tree, so the
    // field beside it keeps its place and its caret.
    await tester.enterText(find.byType(TextField), 'B');
    await tester.pump();
    expect(hintOpacity(tester), 0);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(hintOpacity(tester), 1);
  });

  testWidgets('the keyboard stays up as the first letter is typed', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    final field = fieldElement(tester);
    expect(
      tester.testTextInput.isVisible,
      isTrue,
      reason: 'asked for on arrival',
    );

    // Typed the way the keyboard does, into whatever holds the caret, so
    // nothing hands the field back to itself afterwards.
    tester.testTextInput.enterText('B');
    await tester.pump();

    expect(fieldElement(tester), same(field));
    expect(tester.testTextInput.isVisible, isTrue);
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

  testWidgets('a new task goes on top', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
  });

  testWidgets('giving a task a repeat keeps its place', (tester) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Post letter');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);

    await actOn(tester, 'Call Sam', 'Edit');
    await chooseRepeat(tester, 'Every day');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);
    expect(tileFor(tester, 'Call Sam').todo.repeats, isTrue);

    // And taking the repeat off again keeps it too.
    await actOn(tester, 'Call Sam', 'Edit');
    await chooseRepeat(tester, 'Never');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);
    expect(tileFor(tester, 'Call Sam').todo.repeats, isFalse);
  });

  testWidgets('the read view shows the due and the repeat, read only', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    await addTask(
      tester,
      'Take the pills',
      repeat: 'Every day',
      due: Due(minute: minuteOf(10, 0), reminders: const {0}),
    );

    await tester.tap(find.text('Take the pills'));
    await tester.pumpAndSettle();
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('At 10:00 AM'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    // The due and repeat rows open nothing; only History carries a chevron.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('every card carries a done circle, empty until checked', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    expect(circleOn('Buy milk'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.tap(circleOn('Buy milk'));
    await tester.pump();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
  });

  testWidgets('tapping a card opens it to be read, nothing more', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await tester.tap(find.text('Buy milk'));
    await tester.pumpAndSettle();

    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(find.text('Time'), findsNothing, reason: 'nothing set, no rows');

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
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

    await addTask(tester, 'Post letter');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

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

  testWidgets('marking done plays the done sound; undoing it is silent', (
    tester,
  ) async {
    final device = MemoryDeviceBridge();
    await tester.pumpWidget(bootApp(device: device));
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');

    await actOn(tester, 'Buy milk', 'Done');
    expect(device.doneSounds, 1);
    await actOn(tester, 'Buy milk', 'Not done');
    expect(device.doneSounds, 1);
  });

  testWidgets('a checked card flies to its place rather than jumping', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await tester.tap(circleOn('Call Sam'));
    await tester.pump();
    // Struck in place first; the order is untouched.
    expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
    expect(find.byType(TodoCard), findsNWidgets(2));

    // Then the new order arrives, and a copy of the card is on its way
    // over the list, with a spacer holding where it was.
    await tester.pump(reorderDelay);
    await tester.pump();
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
    expect(find.byType(TodoCard), findsNWidgets(3), reason: 'the copy');
    expect(find.byKey(const ValueKey('flight-spacer-t2')), findsOneWidget);

    // Landed: the copy is gone and the card is in its place.
    await tester.pump(Brand.flight);
    await tester.pumpAndSettle();
    expect(find.byType(TodoCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey('flight-spacer-t2')), findsNothing);
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
  });

  testWidgets('the newest completed task goes to the very bottom', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Post letter');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

    await actOn(tester, 'Buy milk', 'Done');
    expect(visibleTitles(tester), ['Call Sam', 'Post letter', 'Buy milk']);

    await actOn(tester, 'Call Sam', 'Done');
    expect(visibleTitles(tester), ['Post letter', 'Buy milk', 'Call Sam']);
  });

  testWidgets('unmarking lifts a task back above the completed ones', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

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
    expect(
      find.widgetWithText(TextField, '${BrandedRichController.guard}Buy milk'),
      findsOneWidget,
    );

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

  testWidgets('an open card casts a touch of shadow, a done one none', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');
    await actOn(tester, 'Call Sam', 'Done');

    BoxDecoration faceOf(String title) {
      final box = tester.widget<Container>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text(title),
                matching: find.byType(BrandedCard),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      return box.decoration! as BoxDecoration;
    }

    final scheme = homeScheme(tester);
    final open = faceOf('Buy milk');
    expect(open.color, scheme.surface);
    expect(open.boxShadow, hasLength(1));
    expect(open.boxShadow!.single.color.a, closeTo(Brand.shadowAlpha, 0.01));
    expect(open.boxShadow!.single.blurRadius, Brand.shadowBlur);

    final done = faceOf('Call Sam');
    expect(done.color, scheme.surfaceContainerHighest);
    expect(done.boxShadow, isNull);
  });

  testWidgets('a card shows two lines at most, ellipsised past that', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    const long =
        'Buy milk and bread and eggs and butter and cheese and jam and honey '
        'and tea and coffee and sugar and flour and rice and pasta and beans '
        'and lentils and onions and garlic and tomatoes and peppers and '
        'apples and pears and bananas and oranges and lemons and limes';
    await addTask(tester, 'Buy milk');
    await addTask(tester, long);

    final rendered = titleTextOf(tester, long);
    expect(rendered.maxLines, Brand.cardLines);
    expect(rendered.overflow, TextOverflow.ellipsis);
    // Two lines drawn, the rest cut.
    final box = tester.getSize(find.text(long));
    final oneLine = tester.getSize(find.text('Buy milk')).height;
    expect(box.height, greaterThan(oneLine * 1.5));
    expect(box.height, lessThan(oneLine * 2.5));
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

    await addTask(tester, 'Post letter');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

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

    await addTask(tester, 'Post letter');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

    await dragCardDown(tester, from: 'Buy milk', over: 'Post letter');

    expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);

    // The new order survives leaving the day and coming back, so it reached
    // the store rather than living only in memory.
    await stepDay(tester, 1);
    await stepDay(tester, -1);

    expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);
  });

  testWidgets('a reordered task keeps its slot after being unchecked', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Post letter');
    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

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

    await addTask(tester, 'Call Sam');
    await addTask(tester, 'Buy milk');

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

  testWidgets('the leading side offers edit alone; the circle is done', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    await addTask(tester, 'Call Sam');

    await tester.tap(circleOn('Call Sam'));
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Buy milk', 'Call Sam']);
    expect(tileFor(tester, 'Call Sam').todo.done, isTrue);

    // The same circle undoes it.
    await tester.tap(circleOn('Call Sam'));
    await tester.pump(reorderDelay);
    await tester.pumpAndSettle();
    expect(visibleTitles(tester), ['Call Sam', 'Buy milk']);
    expect(tileFor(tester, 'Call Sam').todo.done, isFalse);

    // The swipe has no done button any more, only edit.
    await swipe(tester, 'Buy milk', const Offset(200, 0));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
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

      await addTask(tester, 'Pay the rent', repeat: 'Every day');
      await addTask(tester, 'Team sync', repeat: 'Every week');
      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await addTask(tester, 'Draft the summary');

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

    testWidgets('a custom repeat comes back on the chosen days alone', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      final today = todayDate().epochDay;

      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Dentist');
      await tester.tap(find.text('Repeat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(find.text('Chosen days'), findsOneWidget);
      expect(
        tester
            .widget<BrandedTextButton>(
              find.byKey(const ValueKey('custom-days-done')),
            )
            .enabled,
        isFalse,
        reason: 'nothing chosen yet',
      );
      // Two days this month, or next if the month is nearly over.
      final first = today + 1;
      final third = today + 3;
      for (final day in [first, third]) {
        final cell = find.byKey(ValueKey('pick-day-$day'));
        if (cell.evaluate().isEmpty) {
          await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ValueKey('pick-day-$day')));
        await tester.pump();
      }
      expect(find.text('2 days chosen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('custom-days-done')));
      await tester.pumpAndSettle();
      expect(find.text('On chosen days'), findsNothing, reason: 'sheet row');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('On chosen days'), findsOneWidget, reason: 'editor');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget, reason: 'not today');
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Dentist']);
      expect(tileFor(tester, 'Dentist').todo.repeats, isTrue);
      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget);
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Dentist']);
      await stepDay(tester, 1);
      expect(find.text('Nothing planned'), findsOneWidget);

      // Deleting the middle... the last showing asks about the earlier one.
      await stepDay(tester, -1);
      await actOn(tester, 'Dentist', 'Delete');
      expect(find.text('Delete this and earlier ones'), findsOneWidget);
      expect(find.text('Delete this and later ones'), findsNothing);
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

      await addTask(tester, 'Call Sam');
      await addTask(tester, 'Buy milk');
      await addTask(tester, 'Take the pills', repeat: 'Every day');

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

  testWidgets(
    'in developer mode the rehearsal button rings the reminder in ten seconds',
    (tester) async {
      final scheduler = MemoryReminderScheduler(
        status: ReminderPermission.granted,
      );
      await tester.pumpWidget(
        bootApp(scheduler: scheduler, clock: () => at(9, 0), developer: true),
      );
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Call Sam',
        due: Due(minute: minuteOf(14, 30), sound: ReminderSound.bell),
      );

      await swipe(tester, 'Call Sam', const Offset(-260, 0));
      await tester.tap(find.byIcon(Icons.alarm_on_rounded));
      await tester.pumpAndSettle();

      // The sound is asked for, opening on the task's own.
      final ticked = tester
          .widgetList<BrandedOptionRow>(find.byType(BrandedOptionRow))
          .where((row) => row.selected)
          .map((row) => row.label);
      expect(ticked, ['Bell']);
      await tester.tap(find.byKey(const ValueKey('sound-harp')));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final rehearsal = scheduler.rehearsed.single;
      expect(rehearsal.fireAt, at(9, 0).add(rehearsalDelay));
      expect(rehearsal.title, 'Call Sam');
      expect(
        rehearsal.dueLabel,
        'Due 2:30 PM on ${weekdayName(todayDate().weekday)}, '
        '${shortDate(todayDate())}',
      );
      expect(rehearsal.sound, ReminderSound.harp);
      expect(rehearsal.payload, '${todayDate().epochDay}:t1');
    },
  );

  testWidgets('without developer mode there is no rehearsal button', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    await addTask(tester, 'Call Sam');
    await swipe(tester, 'Call Sam', const Offset(-260, 0));
    expect(find.byIcon(Icons.alarm_on_rounded), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('settings says the version the app was built as', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appVersionProvider.overrideWithValue('2.3.4')],
        child: bootApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('2.3.4'), findsOneWidget);
  });

  testWidgets('ten taps on the version turn developer mode on, and it sticks', (
    tester,
  ) async {
    final settings = MemorySettingsStore();
    await tester.pumpWidget(bootApp(settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Turn developer mode off'), findsNothing);

    for (var tap = 0; tap < DeveloperMode.tapsToEnable - 1; tap++) {
      await tester.tap(find.text('Version'));
      await tester.pump();
    }
    expect(
      find.text('Turn developer mode off'),
      findsNothing,
      reason: 'nine is not ten',
    );
    await tester.tap(find.text('Version'));
    await tester.pumpAndSettle();
    expect(find.text('Turn developer mode off'), findsOneWidget);
    expect(settings.values[DeveloperMode.settingKey], 'on');

    // The button turns it off again.
    await tester.tap(find.text('Turn developer mode off'));
    await tester.pumpAndSettle();
    expect(find.text('Turn developer mode off'), findsNothing);
    expect(settings.values[DeveloperMode.settingKey], 'off');
    expect(await DeveloperMode.load(settings), isFalse);
    expect(
      await DeveloperMode.load(
        MemorySettingsStore({DeveloperMode.settingKey: 'on'}),
      ),
      isTrue,
    );
  });

  testWidgets('the due and repeat sheets come down only by their buttons', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget, reason: 'stays');
    await tester.drag(find.byType(CupertinoDatePicker), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await finishSheet(tester);
    expect(find.byType(CupertinoDatePicker), findsNothing);

    await tester.tap(find.text('Repeat'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Every week'), findsOneWidget, reason: 'stays');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Every week'), findsNothing);
  });

  group('the date on the editor', () {
    final today = todayDate().epochDay;

    testWidgets('a new task starts on the day being looked at', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Turned to tomorrow, the editor starts there instead.
      await stepDay(tester, 1);
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      expect(find.text('Tomorrow'), findsWidgets);
    });

    testWidgets('a repeating task takes its days from its rule', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Stretch');
      await tester.pump();
      expect(find.text('Date'), findsOneWidget);

      await chooseRepeat(tester, 'Every day');
      expect(find.text('Date'), findsNothing);
    });

    testWidgets('a new task written for another day goes there', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk', day: today + 2);

      expect(visibleTitles(tester), isEmpty, reason: 'not on today');
      await stepDay(tester, 2);
      expect(visibleTitles(tester), ['Buy milk']);
    });

    testWidgets('editing a task onto another day sends it there', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');

      await actOn(tester, 'Buy milk', 'Edit');
      await chooseDay(tester, today + 1);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(visibleTitles(tester), isEmpty);
      await stepDay(tester, 1);
      expect(visibleTitles(tester), ['Buy milk']);
    });
  });

  group('the banner for a task on another day', () {
    final today = todayDate().epochDay;

    testWidgets('says which task went where, and offers to go', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk', day: today + 2);

      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);

      await tester.tap(find.text('Go'));
      // Pointed out the frame it first stands on the day.
      await pumpUntilTile(tester, 'Buy milk');
      expect(tileFor(tester, 'Buy milk').spotlit, isTrue);
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Buy milk']);
      expect(tileFor(tester, 'Buy milk').spotlit, isFalse);
      expect(
        find.byKey(const ValueKey('day-notice')),
        findsNothing,
        reason: 'nothing left to say once you are there',
      );
    });

    testWidgets('Not today says where it sent the task', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');

      await swipe(tester, 'Buy milk', const Offset(260, 0));
      await tester.tap(find.text('NOT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('pick-day-${today + 2}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);

      await tester.tap(find.text('Go'));
      await pumpUntilTile(tester, 'Buy milk');
      expect(tileFor(tester, 'Buy milk').spotlit, isTrue);
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Buy milk']);
    });

    testWidgets('a rule sent elsewhere is pointed out as a rule', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(
        tester,
        'Water the plants',
        repeat: 'Every day',
        day: today + 2,
      );

      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
      await tester.tap(find.text('Go'));
      await pumpUntilTile(tester, 'Water the plants');
      // The rule shows today as well, and today is still sliding out, so
      // there are two cards for a moment; the one arriving is the one lit.
      final tiles = tester.widgetList<TodoTile>(
        find.ancestor(
          of: find.text('Water the plants'),
          matching: find.byType(TodoTile),
        ),
      );
      expect(tiles.where((tile) => tile.spotlit).single.todo.repeats, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('it survives the card leaving while the write is in flight', (
      tester,
    ) async {
      // A real write takes frames, so the card is gone by the time there is
      // anything to say. Whatever says it cannot belong to that card.
      await tester.pumpWidget(
        bootApp(
          store: MemoryTodoStore(writeDelay: const Duration(seconds: 1)),
          clock: () => at(9, 0),
        ),
      );
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');

      await swipe(tester, 'Buy milk', const Offset(260, 0));
      await tester.tap(find.text('NOT'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('pick-day-${today + 1}')));
      await tester.pumpAndSettle();
      // The card has gone by now; the write has not landed.
      expect(visibleTitles(tester), isEmpty);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
    });

    testWidgets('only the first line of a long task is shown', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk\nand bread\nand jam', day: today + 1);

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.text('and bread'), findsNothing);
    });

    testWidgets('a task saved onto this very day says nothing', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');

      expect(find.byKey(const ValueKey('day-notice')), findsNothing);
    });

    testWidgets('a push sideways or down sends it away', (tester) async {
      for (final way in const <Offset>[
        Offset(200, 0),
        Offset(-200, 0),
        Offset(0, 120),
      ]) {
        await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
        await tester.pumpAndSettle();
        await addTask(tester, 'Buy milk', day: today + 1);
        expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);

        await tester.drag(find.byKey(const ValueKey('day-notice')), way);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('day-notice')),
          findsNothing,
          reason: 'pushed $way',
        );
      }
    });

    testWidgets('a small push settles back rather than dismissing', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk', day: today + 1);

      await tester.drag(
        find.byKey(const ValueKey('day-notice')),
        const Offset(20, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
    });

    testWidgets('a push upwards is not a way out', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk', day: today + 1);

      await tester.drag(
        find.byKey(const ValueKey('day-notice')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
    });

    testWidgets('it floats over the day instead of pushing it up', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(TodoListView));

      await addTask(tester, 'Buy milk', day: today + 1);
      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
      expect(tester.getRect(find.byType(TodoListView)), before);
    });

    testWidgets('it goes of its own accord after a while', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk', day: today + 1);

      expect(find.byKey(const ValueKey('day-notice')), findsOneWidget);
      await tester.pump(Brand.noticeDwell);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-notice')), findsNothing);
    });
  });

  group('not today', () {
    final today = todayDate().epochDay;

    /// Swipes a card open on the leading side and taps the NOT TODAY glyph,
    /// which sits there beside Edit.
    Future<void> notToday(WidgetTester tester, String title) async {
      await swipe(tester, title, const Offset(260, 0));
      await tester.tap(find.text('NOT'));
      await tester.pumpAndSettle();
    }

    testWidgets('the button sits on the leading side, beside edit', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');

      await swipe(tester, 'Buy milk', const Offset(260, 0));
      expect(find.text('NOT'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // Delete keeps the trailing side to itself.
      await swipe(tester, 'Buy milk', const Offset(-200, 0));
      expect(find.text('NOT'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

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

    testWidgets('the grid will not take the day itself', (tester) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await notToday(tester, 'Buy milk');

      await tester.tap(find.byKey(ValueKey('pick-day-$today')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('pick-day-$today')), findsOneWidget);
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

    testWidgets('the past is open: a task can go back to yesterday', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Buy milk');
      await notToday(tester, 'Buy milk');

      // Yesterday may sit in last month, off the grid that opened.
      final yesterday = find.byKey(ValueKey('pick-day-${today - 1}'));
      if (yesterday.evaluate().isEmpty) {
        await tester.tap(find.bySemanticsLabel('Previous month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(yesterday);
      await tester.pumpAndSettle();

      expect(find.text('Nothing planned'), findsOneWidget);
      await stepDay(tester, -1);
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

    await swipeDay(tester, 1);
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

    await swipeDay(tester, -1);
    await tester.pump(Brand.turn ~/ 2);
    expect(
      tester.getCenter(find.text('Today')).dx,
      lessThan(tester.getCenter(find.text('Tomorrow')).dx),
      reason: 'and goes back out the way it came',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a swipe moves a day at a time and each day keeps its own list', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();

    await addTask(tester, 'Buy milk');
    // No arrows: they read as Back. The swipe is the way about.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);

    await stepDay(tester, 1);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Nothing planned'), findsOneWidget);

    await stepDay(tester, -1);
    expect(find.text('Today'), findsOneWidget);
    expect(visibleTitles(tester), ['Buy milk']);

    await stepDay(tester, -1);
    expect(find.text('Yesterday'), findsOneWidget);
    // Turning is its own way about, so there is nothing to go back to.
    expect(find.byKey(const ValueKey('day-back')), findsNothing);
  });

  testWidgets('a day reached from the month grid offers Back to return', (
    tester,
  ) async {
    await tester.pumpWidget(bootApp());
    await tester.pumpAndSettle();
    await addTask(tester, 'Buy milk');
    expect(find.byKey(const ValueKey('day-back')), findsNothing);

    await stepDay(tester, -1);
    expect(find.text('Yesterday'), findsOneWidget);

    // Five days on, from yesterday.
    final target = todayDate().epochDay + 4;
    await tester.tap(find.byType(DateHeader));
    await tester.pumpAndSettle();
    if (find.byKey(ValueKey('pick-day-$target')).evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.chevron_right_rounded).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(ValueKey('pick-day-$target')));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsNothing);
    expect(find.byKey(const ValueKey('day-back')), findsOneWidget);

    // Back returns to where the list was sent from, and then is gone.
    await tester.tap(find.byKey(const ValueKey('day-back')));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-back')), findsNothing);

    // A swipe after a jump lets go of the way back.
    await tester.tap(find.byType(DateHeader));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-back')), findsOneWidget);
    await stepDay(tester, 1);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-back')), findsNothing);
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

    testWidgets('the editor offers a time, then a reminder, above repeat', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();

      expect(find.text('Time'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Set a time first'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Time')).dy,
        lessThan(tester.getTopLeft(find.text('Reminder')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Reminder')).dy,
        lessThan(tester.getTopLeft(find.text('Repeat')).dy),
      );
      // Nothing to remind about until there is a time.
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reminder-0')), findsNothing);
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
      expect(find.text('None'), findsOneWidget, reason: 'no reminder yet');
      expect(find.text('Set a time first'), findsNothing);
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
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reminder-15')));
      await tester.pump();
      await finishSheet(tester);
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
      await tester.tap(find.text('Reminder'));
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

      // A new task's reminder chooser opens on Harp without being told.
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await finishSheet(tester);
      await tester.tap(find.text('Reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Harp'), findsOneWidget);
      await finishSheet(tester);
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
      await tester.tap(find.text('Time'));
      await tester.pumpAndSettle();
      await finishSheet(tester);
      await tester.tap(find.text('Reminder'));
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
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(9, 30)));
      await addTask(tester, 'Buy milk');
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
      await store.insert(
        day: today,
        title: 'Call Sam',
        due: Due(minute: minuteOf(9, 30)),
      );
      await store.insert(day: today, title: 'Buy milk');
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

      // The card shows the first block alone; the sheet shows it all.
      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('attention-title')),
          matching: find.text('Call Sam'),
        ),
        findsOneWidget,
        reason: 'the first line only',
      );
      expect(find.text('Due 8:30 AM'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Snooze'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      // View sits at the title's right end and opens the task in full.
      final view = find.byIcon(Icons.visibility_outlined);
      expect(view, findsOneWidget);
      final title = tester.getRect(
        find.byKey(const ValueKey('attention-title')),
      );
      expect(tester.getCenter(view).dx, greaterThan(title.right));
      expect(tester.getCenter(view).dy, closeTo(title.center.dy, title.height));
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attention-title')), findsNothing);
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('about the invoice'), findsOneWidget);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
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
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));
      await addTask(tester, 'Buy milk');

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      // The stretches say when each would call again.
      expect(find.text('9:10 AM'), findsOneWidget);
      expect(find.text('9:30 AM'), findsOneWidget);
      expect(find.text('10:00 AM'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('snooze-10')));
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

    testWidgets('snooze can be an hour, or a time picked for later today', (
      tester,
    ) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-60')));
      await tester.pumpAndSettle();
      expect(find.text('10:00 AM'), findsOneWidget);
      expect(tileFor(tester, 'Call Sam').todo.due!.minute, minuteOf(10, 0));

      // Later today: a time of one's own, which must still be to come.
      await addTask(tester, 'Post letter', due: Due(minute: minuteOf(8, 0)));
      await tester.tap(find.text('Post letter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Snooze'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('snooze-later')));
      await tester.pumpAndSettle();
      final wheel = find.byType(CupertinoDatePicker);
      expect(wheel, findsOneWidget);
      tester
          .widget<CupertinoDatePicker>(wheel)
          .onDateTimeChanged(DateTime(2000, 1, 1, 8, 45));
      await tester.pump();
      expect(
        tester
            .widget<BrandedTextButton>(
              find.byKey(const ValueKey('later-today-done')),
            )
            .enabled,
        isFalse,
        reason: 'gone by',
      );
      tester
          .widget<CupertinoDatePicker>(wheel)
          .onDateTimeChanged(DateTime(2000, 1, 1, 15, 15));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('later-today-done')));
      await tester.pumpAndSettle();
      expect(find.text('3:15 PM'), findsOneWidget);
      expect(tileFor(tester, 'Post letter').calling, isFalse);
    });

    testWidgets('dismiss quiets it for the day but keeps its time', (
      tester,
    ) async {
      holdStill(tester);
      await tester.pumpWidget(bootApp(clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));
      await addTask(tester, 'Buy milk');

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
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));
      await addTask(tester, 'Post letter');
      await addTask(tester, 'Buy milk');
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
      await tester.tap(find.text('Time'));
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

      await tester.tap(find.text('Reminder'));
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
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('attention-title')),
            matching: find.text('Call Sam'),
          ),
          findsOneWidget,
        );
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
          imagesDirectoryProvider.overrideWithValue(''),
          clockProvider.overrideWithValue(() => at(9, 0)),
        ],
      );
      addTearDown(container.dispose);
      container.read(attentionRequestProvider.notifier).raise(today, todo.key);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const YesterdoApp(),
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

  group('pinning', () {
    final today = todayDate().epochDay;

    Future<void> pinFromView(WidgetTester tester, String title) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pin')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
    }

    testWidgets('a task pinned on its own screen heads the day', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await addTask(tester, 'Post letter');
      await addTask(tester, 'Call Sam');
      await addTask(tester, 'Buy milk');
      expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);

      await pinFromView(tester, 'Post letter');
      expect(visibleTitles(tester), ['Post letter', 'Buy milk', 'Call Sam']);
      expect(tileFor(tester, 'Post letter').todo.pinned, isTrue);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

      // A task written after it still goes under it.
      await addTask(tester, 'Water plants');
      expect(visibleTitles(tester).first, 'Post letter');

      // Unpinned, it goes back to where it stood.
      await pinFromView(tester, 'Post letter');
      expect(visibleTitles(tester), [
        'Water plants',
        'Buy milk',
        'Call Sam',
        'Post letter',
      ]);
      expect(find.byIcon(Icons.push_pin_rounded), findsNothing);
    });

    testWidgets('done lets go of the pin, and undoing it does not pin again', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await addTask(tester, 'Post letter');
      await addTask(tester, 'Buy milk');
      await pinFromView(tester, 'Post letter');

      await tester.tap(circleOn('Post letter'));
      await tester.pump(reorderDelay);
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Post letter').todo.pinned, isFalse);

      // A done task has no pin to offer.
      await tester.tap(find.text('Post letter'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin')), findsNothing);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      await tester.tap(circleOn('Post letter'));
      await tester.pump(reorderDelay);
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Post letter').todo.pinned, isFalse);
      expect(visibleTitles(tester), ['Buy milk', 'Post letter']);
    });

    testWidgets('the sheet pins a calling task and stays up', (tester) async {
      holdStill(tester);
      final device = MemoryDeviceBridge();
      await tester.pumpWidget(bootApp(device: device, clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam', due: Due(minute: minuteOf(8, 30)));

      await tester.tap(find.text('Call Sam'));
      await tester.pumpAndSettle();
      final pin = find.byKey(const ValueKey('attention-pin'));
      // It sits just before View.
      expect(
        tester.getCenter(pin).dx,
        lessThan(tester.getCenter(find.byIcon(Icons.visibility_outlined)).dx),
      );

      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
      expect(tileFor(tester, 'Call Sam').todo.pinned, isTrue);
      expect(
        (jsonDecode(device.glances.last) as Map<String, Object?>)['pinned'],
        hasLength(1),
      );

      await tester.tap(pin);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('attention-title')), findsOneWidget);
      expect(tileFor(tester, 'Call Sam').todo.pinned, isFalse);
    });

    testWidgets('a repeating task is pinned for its day alone', (tester) async {
      final store = MemoryTodoStore();
      await tester.pumpWidget(bootApp(store: store));
      await tester.pumpAndSettle();
      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await addTask(tester, 'Buy milk');

      await pinFromView(tester, 'Take the pills');
      expect(visibleTitles(tester), ['Take the pills', 'Buy milk']);
      expect((await store.todosOn(today + 1)).single.pinned, isFalse);
    });

    testWidgets('the editor pins a new task and unpins it again', (
      tester,
    ) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await addTask(tester, 'Post letter');

      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('pin-row')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await addTask(tester, 'Call Sam');
      expect(visibleTitles(tester), ['Buy milk', 'Call Sam', 'Post letter']);
      expect(tileFor(tester, 'Buy milk').todo.pinned, isTrue);

      await swipe(tester, 'Buy milk', const Offset(200, 0));
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pin-row')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Buy milk').todo.pinned, isFalse);
      expect(visibleTitles(tester), ['Call Sam', 'Buy milk', 'Post letter']);
    });

    testWidgets('a repeating task pinned in the editor is pinned that day', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      await tester.pumpWidget(bootApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Take the pills');
      await tester.pump();
      await chooseRepeat(tester, 'Every day');
      await tester.ensureVisible(find.byKey(const ValueKey('pin-row')));
      await tester.tap(find.byKey(const ValueKey('pin-row')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tileFor(tester, 'Take the pills').todo.pinned, isTrue);
      expect((await store.todosOn(today + 1)).single.pinned, isFalse);
    });

    testWidgets('a task set to carry over in the editor is written so', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      await tester.pumpWidget(bootApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Post letter');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('carry-row')));
      await tester.tap(find.byKey(const ValueKey('carry-row')));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Post letter').todo.carryOver, isTrue);

      // A repeating task has no carry over to offer, and loses it.
      await actOn(tester, 'Post letter', 'Edit');
      expect(find.byKey(const ValueKey('carry-row')), findsOneWidget);
      await chooseRepeat(tester, 'Every day');
      expect(find.byKey(const ValueKey('carry-row')), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Post letter').todo.carryOver, isFalse);
    });

    testWidgets('carry over is worked on the task\'s own screen', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      await tester.pumpWidget(bootApp(store: store));
      await tester.pumpAndSettle();
      await addTask(tester, 'Post letter');
      await addTask(tester, 'Take the pills', repeat: 'Every day');
      await tester.tap(find.text('Post letter'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('carry-over')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(tileFor(tester, 'Post letter').todo.carryOver, isTrue);

      await tester.tap(find.text('Take the pills'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('carry-over')), findsNothing);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Done has nothing to offer either.
      await tester.tap(circleOn('Post letter'));
      await tester.pump(reorderDelay);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post letter'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('carry-over')), findsNothing);
    });

    testWidgets('a task left undone on an earlier day heads today', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      await store.insert(day: today - 2, title: 'Carried', carryOver: true);
      await store.insert(day: today - 1, title: 'Left', carryOver: false);
      await store.insert(day: today, title: 'Written today');
      await tester.pumpWidget(bootApp(store: store, clock: () => at(9, 0)));
      await tester.pumpAndSettle();
      expect(visibleTitles(tester), ['Carried', 'Written today']);
      expect(await store.todosOn(today - 2), isEmpty);
      expect(find.text('1 left from an earlier day'), findsOneWidget);
    });

    testWidgets('a drag keeps to its own side of the pins', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();
      await addTask(tester, 'Post letter');
      await addTask(tester, 'Water plants');
      await addTask(tester, 'Call Sam');
      await addTask(tester, 'Buy milk');
      await pinFromView(tester, 'Post letter');
      const pinnedFirst = [
        'Post letter',
        'Buy milk',
        'Call Sam',
        'Water plants',
      ];
      expect(visibleTitles(tester), pinnedFirst);

      // The pinned one cannot be dragged down among the rest.
      await dragCardDown(tester, from: 'Post letter', over: 'Water plants');
      expect(visibleTitles(tester), pinnedFirst);

      // And the rest still move among themselves.
      await dragCardDown(tester, from: 'Buy milk', over: 'Water plants');
      expect(visibleTitles(tester), [
        'Post letter',
        'Call Sam',
        'Buy milk',
        'Water plants',
      ]);
    });
  });

  group('search', () {
    Future<void> openSearch(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();
    }

    testWidgets('the magnifier sits before the gear and opens the search '
        'screen', (tester) async {
      await tester.pumpWidget(bootApp());
      await tester.pumpAndSettle();

      final magnifier = find.byIcon(Icons.search_rounded);
      final gear = find.byIcon(Icons.settings_outlined);
      expect(magnifier, findsOneWidget);
      final bar = tester.getRect(find.byType(BrandedBottomBar));
      expect(tester.getCenter(magnifier).dx, greaterThan(bar.center.dx));
      expect(
        tester.getCenter(magnifier).dx,
        lessThan(tester.getCenter(gear).dx),
      );

      await openSearch(tester);
      expect(find.byType(SearchPage), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      // Nothing has been searched for yet, so nothing is offered.
      expect(find.text('Recent'), findsNothing);
      // The keyboard is asked for once the slide-in is over.
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets('typing finds tasks on other days, and a tap turns the list '
        'to that day', (tester) async {
      final store = MemoryTodoStore();
      final today = todayDate().epochDay;
      await store.insert(day: today, title: 'Buy milk');
      await store.insert(day: today + 1, title: 'Call the dentist');
      await store.insert(day: today - 2, title: 'Pay the dentist');
      await tester.pumpWidget(bootApp(store: store));
      await tester.pumpAndSettle();
      await openSearch(tester);

      await tester.enterText(find.byType(TextField), 'dent');
      await tester.pumpAndSettle();
      expect(find.text('Buy milk'), findsNothing);
      expect(find.text('Call the dentist'), findsOneWidget);
      expect(find.text('Pay the dentist'), findsOneWidget);
      // Latest day first.
      expect(
        tester.getTopLeft(find.text('Call the dentist')).dy,
        lessThan(tester.getTopLeft(find.text('Pay the dentist')).dy),
      );
      expect(find.text('Tomorrow'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nothing like it');
      await tester.pumpAndSettle();
      expect(find.text('Nothing found'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'dent');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Call the dentist'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(visibleTitles(tester), ['Call the dentist']);
      // The spotlight was asked for, and the list has answered it.
      expect(container(tester).read(spotlightProvider), isNull);
    });

    testWidgets('the found card is pointed out on its day, once', (
      tester,
    ) async {
      final store = MemoryTodoStore();
      final today = todayDate().epochDay;
      await store.insert(day: today, title: 'Buy milk');
      await store.insert(day: today, title: 'Call the dentist');
      await tester.pumpWidget(bootApp(store: store));
      await tester.pumpAndSettle();
      await openSearch(tester);
      await tester.enterText(find.byType(TextField), 'dent');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Call the dentist'));
      expect(container(tester).read(spotlightProvider), isNotNull);
      // The card is built with its spotlight the frame the list answers,
      // and the ask is cleared once that frame is out.
      await tester.pump();
      expect(tileFor(tester, 'Call the dentist').spotlit, isTrue);
      expect(tileFor(tester, 'Buy milk').spotlit, isFalse);
      expect(container(tester).read(spotlightProvider), isNull);
      // Nothing points it out again.
      await tester.pump();
      expect(tileFor(tester, 'Call the dentist').spotlit, isFalse);
      // The card's breath runs its course anyway and settles.
      final card = find.ancestor(
        of: find.text('Call the dentist'),
        matching: find.byType(BrandedCard),
      );
      Color border() {
        final box = tester.widget<Container>(
          find.descendant(of: card, matching: find.byType(Container)).first,
        );
        return (box.decoration! as BoxDecoration).border!.top.color;
      }

      final still = homeScheme(tester).outlineVariant;
      await tester.pump(Brand.breath ~/ 2);
      expect(border(), isNot(still));
      await tester.pumpAndSettle();
      expect(border(), still);
    });

    testWidgets('a search is remembered and can be run again', (tester) async {
      final store = MemoryTodoStore();
      final settings = MemorySettingsStore();
      await store.insert(day: todayDate().epochDay, title: 'Buy milk');
      await tester.pumpWidget(bootApp(store: store, settings: settings));
      await tester.pumpAndSettle();
      await openSearch(tester);

      // Typing alone remembers nothing; the return key does.
      await tester.enterText(find.byType(TextField), 'milk');
      await tester.pumpAndSettle();
      expect(await RecentSearches.load(settings), isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(await RecentSearches.load(settings), ['milk']);

      // Clearing the words brings the recent searches up.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsOneWidget);
      expect(find.byKey(const ValueKey('recent-milk')), findsOneWidget);
      expect(find.text('Buy milk'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('recent-milk')));
      await tester.pumpAndSettle();
      expect(find.text('Buy milk'), findsOneWidget);

      // Opening a result remembers the search too, once.
      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();
      expect(await RecentSearches.load(settings), ['milk']);

      await openSearch(tester);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('Recent'), findsNothing);
      expect(await RecentSearches.load(settings), isEmpty);
    });
  });
}
