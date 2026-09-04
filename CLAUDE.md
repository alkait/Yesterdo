# RemindMe

A day-at-a-time todo list for iPhone and iPad. Offline, local, no account, no sync.

## Git

- Always work on `main`. Never create a branch.
- Never open a pull request. Commit straight to `main`.
- Commit when asked to, not on your own.

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
- Ordering lives only in `compareTodos`. Open tasks keep their position order,
  completed ones sit below them, and the one just checked heads that struck group.
  Ties break on id so a list never reshuffles between rebuilds. Do not re-sort ad
  hoc in a widget.
- Dragging renumbers positions 0, 1, 2 and writes them through `TodoStore.reorder`
  in one batch. Do not write positions one row at a time.

## Repeating tasks

- A repeat is stored as a rule in `recurrences`, never as a row per day. A day is
  read as its own rows plus every rule that fires on it, composed once in
  `mergeDay` so both stores answer alike.
- A rule always has a `start_day`. Without one it would reach back over every past
  day the user walks to.
- Nothing is written until someone acts. Completing, renaming, deleting or dragging
  a projected occurrence materialises it first, through `TodoStore.materialize`.
- Deleting one occurrence writes a hidden row. A rule cannot be unwritten for a
  single day.
- Deleting this and later ones sets the rule's `end_day` to the day before and
  drops written-down occurrences from that day on. Deleting this and earlier ones
  is its mirror: `start_day` moves to the day after and occurrences up to it go. A
  cut that would leave the rule with no days at all removes it outright.
- `Todo.id` is null while a task is only projected. Key widgets, swipe state and
  sort ties on `Todo.key`, never on the id. The key survives materialisation.
- Words and rule both belong to the series, so editing a repeating task changes
  every day it appears on. Only done, not done and delete-this-one are per day.
- Monthly on the 31st clamps to the last day of shorter months.
- The schema is versioned. Add an `onUpgrade` branch and cover it in
  `test/migration_test.dart`, which runs against real SQLite. The fake-clock hang
  only affects widget tests, so a plain test with the ffi driver is fine.

## UI: the Branded rule

Every visual element is wrapped in a Branded widget, so a change to the look lands
in one place and shows up everywhere.

- Screens compose `BrandedText`, `BrandedIcon`, `BrandedIconButton`,
  `BrandedTextButton`, `BrandedActionButton`, `BrandedActionGrid`,
  `BrandedFieldRow`, `BrandedOptionRow`,
  `BrandedAppBar`, `BrandedBottomBar`, `BrandedScaffold`, `BrandedCard`,
  `BrandedDragHandle`, `BrandedReorderableList`, `BrandedSwipeActions`,
  `BrandedSelectionCircle`, `BrandedTextField`, `BrandedDivider`, `BrandedApp`,
  `showBrandedSheet` and `openBrandedPage`.
- Raw `Text`, `Icon`, `TextField`, `Scaffold`, `AppBar`, `Divider`, `Dismissible`,
  `MaterialApp`, `MaterialPageRoute`, `ListView.`, `ReorderableListView`,
  `ReorderableDragStartListener` and `showModalBottomSheet` are banned outside
  `lib/ui/branded/`. So are `TextStyle`, `Colors.`, hex `Color(0x…)` and
  `Theme.of`.
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

## Interaction

- Writing a task never happens inline. Both adding and editing push
  `TaskEditorPage` as a full screen, which returns the text through the navigator.
- A task row carries no checkbox. Double tapping it opens the action sheet, which is
  where done, edit and delete live.
- Single tap on a row is deliberately unbound. Binding it would make Flutter hold
  every tap for the double-tap timeout, which is the opposite of blazing fast.
- Each task is a bordered card, not a row with a rule between. Completed cards are
  recessed onto the raised surface colour.
- A card shows one line and one line only. Anything past the first break comes off
  through `Todo.firstLine`, and a long line ellipsises. A task may still hold more
  text, written on the editor screen.
- `BrandedText` picks its own reading direction from its content, so an Arabic or
  Hebrew task sits against the right edge of its card. Never pass a direction in
  from a screen.
- Direction comes from the first strong letter, not the first character. Digits,
  punctuation and emoji carry no direction and are skipped, so `"1. مرحبا"` reads
  right to left. `brandedTextDirection` is the one place that decides.
- The drag grip stays on the right whatever the text direction. Flipping it per card
  would make the grips jump sides in a mixed list.
- Only open tasks carry a drag handle. Completed ones are ranked by when they were
  finished, so a handle there would promise a move the list cannot keep. A drag that
  lands among them is clamped back into the open group.
- Reordering starts from the handle only, which leaves a plain sideways swipe free
  for the row's buttons.
- A swipe never acts on its own. It uncovers buttons and nothing happens until one
  is tapped, so a swipe can always be taken back. Swiping right uncovers done and
  edit, swiping left uncovers delete.
- The card squeezes to make room rather than sliding off the screen edge, so it
  keeps both of its rounded ends.
- One row is open at a time. The list owns a `BrandedSwipeGroup` and hands it to
  every row, which closes the last one when another opens.
- The three task actions are named once in `task_actions.dart`. The swipe buttons
  and the sheet both read from there so their icons and labels cannot drift.
- Deleting a repeating task asks first, with up to four scopes: this one, this and
  earlier ones, this and later ones, or every one. It is the only place a choice is
  put to the user. A one-off deletes without being asked.
- Offer a range whenever the rule has showings on that side, judged from the rule
  and not from whether any of them have been written down. To the person looking at
  it, tomorrow's showing is already there. The two ranges are decided
  independently: a rule's first day still offers "this and later ones".
- Drop a range only when its own side is empty, and ask nothing at all when a task
  is down to a single showing. `RepeatRule.hasOccurrenceBefore` and
  `hasOccurrenceAfter` answer this; do not reason about it in a widget.
- A repeating card carries a repeat glyph in the card's leading slot.
- A `late` field initialiser runs on first use, not at construction. Never let one
  read mutable state, or it will evaluate against a value the user has since
  changed.

## Tests

- Widget tests must use `MemoryTodoStore`. Real sqflite hangs under the widget
  tester's fake clock, and the failure looks like a timeout, not an error.
- The analyzer must be clean and `fvm flutter test` must pass before work is done.

## Code shape

- One widget concern per file. Split a file rather than let it grow.
- Weigh any new dependency against the offline and performance constraints first.
