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
- A monthly rule is a set of days, stored as a bitmask in `month_days`: bit 0 is
  the 1st, up to the 28th, plus `RepeatRule.lastDayOfMonthBit` for the last day of
  every month. The 29th, 30th and 31st cannot be chosen, so no rule ever has to
  clamp. Their dots are drawn greyed in the chooser and ignore the finger.
- The repeat sheet's row always says "Every month". Tapping it opens
  `MonthDaysPage` as its own screen, which hands the set back through the
  navigator; the sheet and the editor then show the days as small print. The
  chooser never lets the last remaining day be cleared.
- The schema is versioned. Add an `onUpgrade` branch and cover it in
  `test/migration_test.dart`, which runs against real SQLite. The fake-clock hang
  only affects widget tests, so a plain test with the ffi driver is fine.

## Due times and reminders

- A due time is a `Due`: minutes after midnight, plus an optional reminder in
  minutes before it. It sits in `due_time` and `reminder` on both `todos` and
  `recurrences`. A projected occurrence carries its rule's time; a written-down
  one carries its own copy, like the words, so a snooze is for that day alone.
- The time belongs to the series. Editing a repeating task's time changes every
  day it appears on and clears every wave-away, because a new time is a new call.
- A task is calling when its moment has passed on the day being looked at, it is
  open, and `dismissed` is not set. `Todo.isCallingOn` is the one place that
  decides; a card reads it, never the clock. Future days never call.
- Calling tasks head the open group, earliest first, through `todoOrderOn`.
  `compareTodos` stays the plain order and `mergeDay` takes an optional `now`.
  `TodosController` keeps a timer set for the next task to fall due on the day,
  so the card rises at the minute without a rebuild being provoked.
- Every reading of the clock goes through `clockProvider`. Tests bind a clock
  they turn by hand; `DateTime.now()` in a widget or a controller is a bug.
- Snooze pushes the time on ten minutes from now on the current day, or from its
  own time on any other day, never past the end of the day, and sets the
  reminder to fire at the new time. Dismiss sets `dismissed` and keeps the time
  on the card. Done, snooze and dismiss are per day.
- Reminders are local notifications through `flutter_local_notifications`, the
  one plugin the app carries. Nothing else may be added for it.
- The system is never told about a change directly. `ReminderPlanner` derives the
  whole plan from the store, today through fourteen days ahead, capped under the
  system's limit, and `ReminderSync` hands it over with `replaceAll`. It runs
  after every write, on launch, and when the app comes back to the front.
- Go through the `ReminderScheduler` interface. The app binds
  `LocalReminderScheduler`, tests bind `MemoryReminderScheduler` and read what
  was handed over.
- Permission is asked for the first time a reminder is chosen, from the editor,
  never at launch.
- `AppDelegate` sets itself as the notification centre's delegate before
  handing off to Flutter. Without that line a tapped notification opens the app
  and nothing else; the plugin never hears of it and Dart is never told.
- A notification's payload is `day:key`. Tapping it raises an
  `AttentionRequest`; `AttentionListener` turns the list to that day, waits for
  it to load, pops any screen above the list and puts up the attention sheet. A
  task gone by then opens the day and nothing else.

## UI: the Branded rule

Every visual element is wrapped in a Branded widget, so a change to the look lands
in one place and shows up everywhere.

- Screens compose `BrandedText`, `BrandedIcon`, `BrandedIconButton`,
  `BrandedTextButton`,
  `BrandedFieldRow`, `BrandedOptionRow`,
  `BrandedAppBar`, `BrandedBottomBar`, `BrandedScaffold`, `BrandedCard`,
  `BrandedDragLift`, `BrandedReorderableList`, `BrandedSwipeActions`,
  `BrandedSelectionCircle`, `BrandedTextField`, `BrandedDivider`,
  `BrandedThemeSwatch`, `BrandedApp`, `showBrandedSheet` and `openBrandedPage`.
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
  in one switch in `brand.dart`. `accent` is the look's own colour and is for the
  one thing asking to be noticed, not decoration.
- Widgets name a `BrandedTextRole`, never a size or weight. The type ramp lives in
  `BrandedText.styleFor`.
- Metrics, durations and width caps come from the `Brand` constants. No magic
  numbers in a screen.
- Colours are defined only in `AppTheme.schemeFor`, keyed by `AppThemeChoice` and
  brightness. Every look needs a light and a dark palette; the system still picks
  which of the two is showing.
- The app ships in Blossom, `AppThemeChoice.fallback`, which is also what an
  unknown saved name falls back to.
- The look in force is `themeChoiceProvider`. `BrandedApp` is the only widget that
  reads it to build a theme; everything else gets its colours through the
  `ColorScheme`, so a new look needs no widget changes.
- `main` reads the saved look before the first frame and binds it to
  `initialThemeChoiceProvider`, so the app never flashes one look and switches.
- Flat means no elevation, no shadows, no ripple. Keep splash and highlight
  transparent.
- Cap content width for iPad rather than letting rows stretch. `BrandedScaffold`
  already does this; check a phone and a tablet before calling a layout done.
- No splash screen. The launch storyboard stays a blank system-coloured view.

## Interaction

- Writing a task never happens inline. Both adding and editing push
  `TaskEditorPage` as a full screen, which returns the text through the navigator.
  Save is greyed and inert until there are words; Cancel is never greyed.
- The editor's Due row sits above Repeat and opens a sheet: a time wheel, the
  reminder choices, Clear and Done. It hands back a `DuePick`, so backing out can
  be told from clearing. The row reads the time with the reminder as small print.
- A task row carries no checkbox and, unless it is calling, no tap of its own.
  Done, edit and delete live on the swipe buttons and nowhere else; there is no
  action sheet.
- A calling card is the one card that takes a tap. It puts up the attention
  sheet: the task's words in full, then Done, Snooze and Dismiss. The same sheet
  answers a tapped notification, so the context is there whichever way it came.
- A calling card breathes: `BrandedCard.calling` leans the border and face into
  the accent and back, without end, until answered. Under reduce motion it holds
  the leaning colour still. Widget tests that show a calling card must call
  `holdStill`, or `pumpAndSettle` never settles.
- The time sits in small print at the card's trailing end, with a bell when a
  reminder is set. Both take the accent while the card is calling.
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
- A card carries no drag grip. Pressing and holding anywhere on it lifts it, through
  `BrandedDragLift`, and the whole width is left to the words.
- Only open tasks can be lifted. Completed ones are ranked by when they were
  finished, and calling ones hold the top, so lifting either would promise a move
  the list cannot keep. A drag that lands among them is clamped back into the
  band between.
- The lift waits for the long-press timeout, which leaves a plain sideways swipe
  free for the row's buttons.
- A swipe never acts on its own. It uncovers buttons and nothing happens until one
  is tapped, so a swipe can always be taken back. Swiping right uncovers done and
  edit, swiping left uncovers delete.
- The card squeezes to make room rather than sliding off the screen edge, so it
  keeps both of its rounded ends.
- One row is open at a time. The list owns a `BrandedSwipeGroup` and hands it to
  every row, which closes the last one when another opens.
- The three task actions are named once in `task_actions.dart`, so their icons and
  labels cannot drift.
- Deleting a repeating task asks first, with up to four scopes: this one, this and
  earlier ones, this and later ones, or every one. It and the attention sheet are
  the only places a choice is put to the user. A one-off deletes without being
  asked.
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

## Settings

- A setting is a named string in the `settings` table, read and written through
  the `SettingsStore` interface. The app binds `SqliteSettingsStore`, tests bind
  `MemorySettingsStore`.
- The settings screen is `SettingsPage`, opened from the gear at the right end of
  the bottom bar. The gear sits in the bar's `trailing` slot, outside the add tap
  target, so it can never open the editor.
- A theme choice applies the moment it is tapped. There is no save step.

## Tests

- Widget tests must use `MemoryTodoStore`. Real sqflite hangs under the widget
  tester's fake clock, and the failure looks like a timeout, not an error.
- Widget tests that touch a time bind `clockProvider` to a moment on the real
  today, through `at(hour, minute)` in the flow test. The list opens on the real
  today, so a fixed date would put the task on a different day from the clock.
- The analyzer must be clean and `fvm flutter test` must pass before work is done.

## Code shape

- One widget concern per file. Split a file rather than let it grow.
- Weigh any new dependency against the offline and performance constraints first.
