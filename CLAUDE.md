# Yesterdo

A day-at-a-time todo list for iPhone and iPad. Offline, local, no account, no
sync. The code is the source of truth for what the app does; this file holds
only the rules for working on it.

## Name

- The app is Yesterdo: display name, app title and bundle identifier
  `com.alkait.yesterdo`. The Dart package `remind_me`, the database file and
  the method channel keep their old names; they are internal. Do not rename
  them.

## Git

- Always work on `main`. Never create a branch.
- Never open a pull request. Commit straight to `main`.
- Commit when asked to, not on your own.

## Toolchain

- Prefix every Flutter and Dart command with `fvm`. A bare `flutter` resolves
  to the machine default, not the pinned 3.47.2.
- iOS is the only enabled platform. Do not add Android, web, or desktop
  targets.
- `fvm flutter run` exits immediately without a TTY. To bring the app up,
  build with `fvm flutter build ios --debug --simulator`, then install and
  launch through `xcrun simctl`.
- A stale `build/` directory causes a lipo failure on the next build. Clear it
  with `fvm flutter clean`.

## State

- Riverpod is the only state mechanism. No Bloc, no Provider, no GetX, no
  InheritedWidget of our own.
- Declare every provider in `lib/state/providers.dart`. Widgets never
  construct providers inline.
- Local widget state is fine for a text field or an animation. Anything
  shared goes through a provider.
- Every reading of the clock goes through `clockProvider`. `DateTime.now()`
  in a widget or a controller is a bug.
- A `late` field initialiser runs on first use, not at construction. Never
  let one read mutable state.

## Data

- Storage stays local SQLite. No network calls, no cloud, no sync, no
  analytics packages.
- Go through the `TodoStore` interface. The app binds `SqliteTodoStore`,
  tests bind `MemoryTodoStore`. A new store method is added to both.
- A setting goes through the `SettingsStore` interface. The app binds
  `SqliteSettingsStore`, tests bind `MemorySettingsStore`.
- A day is an integer count of days since the Unix epoch. Do not key anything
  on a formatted date string.
- Positions are ranks: only their order means anything, and they may go
  negative. Ordering lives only in `compareTodos`; do not re-sort ad hoc in a
  widget. Reordering writes positions through `TodoStore.reorder` in one
  batch, never one row at a time.
- A repeat is a rule in `recurrences`, never a row per day. A day is composed
  once, in `mergeDay`, so both stores answer alike. A rule always has a
  `start_day`. Nothing is written for a projected occurrence until someone
  acts on it, through `TodoStore.materialize`.
- `Todo.id` is null while a task is only projected. Key widgets, swipe state
  and sort ties on `Todo.key`, never on the id.
- Questions about a rule's showings, such as whether it has any before or
  after a day, are answered on `RepeatRule`. Do not reason about them in a
  widget.
- The schema is versioned. Add an `onUpgrade` branch and cover it in
  `test/migration_test.dart`, which runs against real SQLite.
- The `Due.reminderChoices` bitmask is ordered. Add a choice at the end or
  every saved set shifts.
- A task's plain `title` is derived from its `TaskBody`, never the other way
  round. `StyledText.replaced` is the one place an edit moves style runs; do
  not adjust runs anywhere else.
- Pictures are the device's business, through `DeviceBridge` and
  `ImageBridge` in Swift. Dart only ever sees file names. No picker plugin.
  Never delete a picture file directly; `ImageSweep` clears unreferenced
  ones through `TodoStore.allImages`.

## Reminders and the device

- `flutter_local_notifications` is the one plugin the app carries. Nothing
  else may be added for it. What only the device can do goes through
  `DeviceBridge`, a method channel handled in `AppDelegate`. The app binds
  `MethodChannelDeviceBridge`, tests bind `MemoryDeviceBridge`.
- Go through the `ReminderScheduler` interface. The app binds
  `LocalReminderScheduler`, tests bind `MemoryReminderScheduler`.
- The system is never told about a change directly. `ReminderPlanner`
  derives the whole plan from the store and `ReminderSync` hands it over
  with `replaceAll`, after every write, on launch, and on return to the front.
- Nothing is shown while the app is in front. Keep the plugin's presentation
  options off.
- `Todo.isCallingOn` is the one place that decides whether a task is
  calling. A card reads it, never the clock.
- Permission is asked the first time a reminder is chosen, never at launch.
- `AppDelegate` sets itself as the notification centre's delegate before
  handing off to Flutter. Without that line Dart is never told of a tapped
  notification.
- A sound is a short CAF file under `ios/Runner/Sounds`, listed as a resource
  in the Xcode project so it lands at the bundle root. A new reminder sound
  is a new file there and a new `ReminderSound` case; a new done sound, a
  new `DoneSound` case. Anything brought in
  under a licence that asks for credit is credited in Settings, under About.

## UI: the Branded rule

Every visual element is wrapped in a Branded widget, so a change to the look
lands in one place and shows up everywhere.

- Screens compose the widgets exported from `lib/ui/branded/branded.dart`.
  Raw `Text`, `Icon`, `TextField`, `Scaffold`, `AppBar`, `Divider`,
  `Dismissible`, `MaterialApp`, `MaterialPageRoute`, `ListView.`,
  `ReorderableListView`, `ReorderableDragStartListener` and
  `showModalBottomSheet` are banned outside `lib/ui/branded/`. So are
  `TextStyle`, `Colors.`, hex `Color(0x…)` and `Theme.of`.
- `test/branded_rule_test.dart` enforces this. A new visual element means a
  new Branded widget, not an exception: add
  `lib/ui/branded/branded_<thing>.dart` and export it from the barrel.
- Widgets name a `BrandedTone`, never a colour, and a `BrandedTextRole`,
  never a size or weight. `accent` is for the one thing asking to be
  noticed, not decoration.
- Metrics, durations and width caps come from the `Brand` constants. No
  magic numbers in a screen.
- Colours are defined only in `AppTheme.schemeFor`, keyed by
  `AppThemeChoice` and brightness. Every look needs a light and a dark
  palette. `BrandedApp` is the only widget that reads `themeChoiceProvider`;
  everything else gets its colours through the `ColorScheme`.
- `main` reads saved settings before the first frame and binds them to the
  `initial…` providers, so the app never flashes one state and switches.
- Flat means no Material elevation and no ripple. Keep splash and highlight
  transparent. The one shadow is `BrandedCard`'s open-card shadow.
- Cap content width for iPad rather than letting rows stretch. Check a phone
  and a tablet before calling a layout done.
- No splash screen. The launch storyboard stays a blank system-coloured view.
- `BrandedText` picks its own reading direction from its content through
  `brandedTextDirection`. Never pass a direction in from a screen.
- A new look needs its own app icon set, `AppIcon-<look>`, listed in the
  project's alternate icon names setting.

## Interaction

- Writing a task never happens inline. Adding and editing push
  `TaskEditorPage` as a full screen.
- The editor asks for the keyboard only once its slide-in has finished, by
  listening to the route's animation. No `autofocus` on that field.
- Done is the circle on the card, and the attention sheet's Done. Edit and
  delete live on the swipe buttons and nowhere else; there is no action
  sheet.
- A card that changes place in the order flies there through `TodoFlight`.
  Do not let a card jump.
- A swipe never acts on its own. It uncovers buttons and nothing happens
  until one is tapped.
- The task actions are named once in `task_actions.dart`, so their icons and
  labels cannot drift.
- Developer mode only ever adds tools, never changes behaviour.
- `appVersion` in `lib/core/app_version.dart` is kept by hand beside
  `pubspec.yaml`.

## Tests

- Widget tests must use `MemoryTodoStore`. Real sqflite hangs under the
  widget tester's fake clock, and the failure looks like a timeout.
- Widget tests that touch a time bind `clockProvider` to a moment on the real
  today, through `at(hour, minute)` in the flow test.
- Widget tests that show a calling card must call `holdStill`, or
  `pumpAndSettle` never settles.
- The analyzer must be clean and `fvm flutter test` must pass before work is
  done.

## Code shape

- One widget concern per file. Split a file rather than let it grow.
- Weigh any new dependency against the offline and performance constraints
  first.
