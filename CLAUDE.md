# RemindMe

A day-at-a-time todo list for iPhone and iPad. Offline, local, no account, no sync.

## Toolchain

- Prefix every Flutter and Dart command with `fvm`. A bare `flutter` resolves to the
  machine default, not the pinned 3.47.2.
- iOS is the only enabled platform. Do not add Android, web, or desktop targets.
- `fvm flutter run` exits immediately without a TTY. To bring the app up, build with
  `fvm flutter build ios --debug --simulator`, then install and launch through
  `xcrun simctl`.
- A stale `build/` directory causes a lipo failure on the next build. Clear it with
  `fvm flutter clean`.

## State

- Riverpod is the only state mechanism. No Bloc, no Provider, no GetX, no
  InheritedWidget of our own.
- Declare every provider in `lib/state/providers.dart`. Widgets never construct
  providers inline.
- Local widget state is fine for a text field or an animation. Anything shared goes
  through a provider.

## Data

- Storage stays local SQLite. No network calls, no cloud, no sync, no analytics
  packages.
- Go through the `TodoStore` interface. The app binds `SqliteTodoStore`, tests bind
  `MemoryTodoStore`.
- A day is an integer count of days since the Unix epoch. Do not key anything on a
  formatted date string.
- Ordering lives only in `compareTodos`. Do not re-sort ad hoc in a widget.

## UI: the Branded rule

Every visual element is wrapped in a Branded widget, so a change to the look lands
in one place and shows up everywhere.

- Screens compose `BrandedText`, `BrandedIcon`, `BrandedIconButton`,
  `BrandedTextButton`, `BrandedAppBar`, `BrandedBottomBar`, `BrandedScaffold`,
  `BrandedRow`, `BrandedCheckbox`, `BrandedSelectionCircle`, `BrandedTextField`,
  `BrandedDivider`, `BrandedDismissible`, `BrandedApp` and `showBrandedSheet`.
- Raw `Text`, `Icon`, `TextField`, `Scaffold`, `AppBar`, `Divider`, `Dismissible`,
  `MaterialApp` and `showModalBottomSheet` are banned outside `lib/ui/branded/`.
  So are `TextStyle`, `Colors.`, hex `Color(0x…)` and `Theme.of`.
- `test/branded_rule_test.dart` enforces this. It fails the build on a violation, so
  a new visual element means a new Branded widget, not an exception.
- Need a new kind of element? Add `lib/ui/branded/branded_<thing>.dart`, export it
  from `lib/ui/branded/branded.dart`, then use it. The barrel is checked by the same
  test.
- Widgets name a `BrandedTone`, never a colour. Tones resolve to the `ColorScheme`
  in one switch in `brand.dart`.
- Widgets name a `BrandedTextRole`, never a size or weight. The type ramp lives in
  `BrandedText.styleFor`.
- Metrics, durations and width caps come from the `Brand` constants. No magic
  numbers in a screen.
- Colours are defined only in `AppTheme`, and every colour needs a light and a dark
  value.
- Flat means no elevation, no shadows, no ripple. Keep splash and highlight
  transparent.
- Cap content width for iPad rather than letting rows stretch. `BrandedScaffold`
  already does this; check a phone and a tablet before calling a layout done.
- No splash screen. The launch storyboard stays a blank system-coloured view.

## Tests

- Widget tests must use `MemoryTodoStore`. Real sqflite hangs under the widget
  tester's fake clock, and the failure looks like a timeout, not an error.
- The analyzer must be clean and `fvm flutter test` must pass before work is done.

## Code shape

- One widget concern per file. Split a file rather than let it grow.
- Weigh any new dependency against the offline and performance constraints first.
