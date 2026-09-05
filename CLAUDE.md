# Yesterdo

A day-at-a-time todo list for iPhone and iPad. Offline, local, no account, no sync.

## Name

- The app is Yesterdo: the display name in `Info.plist`, the app title in
  `YesterdoApp`, and the bundle identifier `com.alkait.yesterdo`. The Dart
  package `remind_me`, the database file and the method channel keep their
  old names; they are internal and never seen.

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
- A new task goes on top: `insert` and `insertSeries` take the position above
  everything on the day, rows and rules alike, so positions may go negative.
  Only their order means anything. A task sent to another day joins the end,
  unless it is brought back from the backlog, when it goes on top.
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
- Giving a one-off a repeat, or taking a repeat off, keeps the task's place:
  the new row or rule is written at the old position.
- A monthly rule is a set of days, stored as a bitmask in `month_days`: bit 0 is
  the 1st, up to the 28th, plus `RepeatRule.lastDayOfMonthBit` for the last day of
  every month. The 29th, 30th and 31st cannot be chosen, so no rule ever has to
  clamp. Their dots are drawn greyed in the chooser and ignore the finger.
- A custom rule, `RepeatKind.custom`, fires on exact days and nothing else,
  kept sorted and comma-joined in `days`. Its run is its first day to its last,
  so the cuts that delete earlier or later showings work on it unchanged, and
  `chosenDays` is what is left inside the run. The Custom row on the repeat
  sheet opens `CustomDaysPage`, a month grid where any number of days from the
  day being looked at are tapped on and off; Done stays greyed with none.
- The month grid is one widget, `MonthGrid`, with the month bar and weekday
  strip beside it, shared by the day jump, the move and the custom repeat.
  Which days are marked and which may be tapped is the caller's to say.
- The repeat sheet's row always says "Every month". Tapping it opens
  `MonthDaysPage` as its own screen, which hands the set back through the
  navigator; the sheet and the editor then show the days as small print. The
  chooser never lets the last remaining day be cleared.
- The schema is versioned. Add an `onUpgrade` branch and cover it in
  `test/migration_test.dart`, which runs against real SQLite. The fake-clock hang
  only affects widget tests, so a plain test with the ffi driver is fine.

## Due times and reminders

- A due time is a `Due`: minutes after midnight, a set of reminders in minutes
  before it, and a `ReminderSound`. It sits in `due_time`, `reminder` and
  `sound` on both `todos` and `recurrences`. The reminder set is a bitmask, one
  bit per entry of `Due.reminderChoices`, in that order; add a choice at the end
  or every saved set shifts. A projected occurrence carries its rule's time; a
  written-down one carries its own copy, like the words, so a snooze is for that
  day alone.
- The sounds are short CAF files under `ios/Runner/Sounds`, listed as resources
  in the Xcode project so they land at the bundle root, which is where the
  system looks. A new sound is a new file there and a new `ReminderSound` case.
- Nothing is shown while the app is in front. The plugin's presentation
  options are all off in `LocalReminderScheduler.initializationSettings` and on
  every notification; the card calls on screen instead.
- The time belongs to the series. Editing a repeating task's time changes every
  day it appears on and clears every wave-away, because a new time is a new call.
- A task is calling when its moment has passed on the day being looked at, it is
  open, and `dismissed` is not set. The moment is its earliest reminder that
  falls on that day, or the time itself when there is none, through
  `Due.callInstantOn`; a reminder the day before belongs to that day.
  `Todo.isCallingOn` is the one place that decides; a card reads it, never
  the clock. Future days never call.
- Calling tasks head the open group, earliest first, through `todoOrderOn`.
  `compareTodos` stays the plain order and `mergeDay` takes an optional `now`.
  `TodosController` keeps a timer set for the next task to fall due on the day,
  so the card rises at the minute without a rebuild being provoked.
- Every reading of the clock goes through `clockProvider`. Tests bind a clock
  they turn by hand; `DateTime.now()` in a widget or a controller is a bug.
- Snooze asks how long: ten minutes, half an hour, an hour, or "Later today",
  which is a time of one's own on the wheel and must still be to come. The
  minute is counted from now on the day being looked at, never past the end of
  the day, and the reminder is set to fire at the new time. Dismiss sets `dismissed` and keeps the time
  on the card. Done, snooze and dismiss are per day.
- Reminders are local notifications through `flutter_local_notifications`, the
  one plugin the app carries. Nothing else may be added for it. What only the
  device can do, the app icon, playing a sound out loud, and whether permission
  was ever asked, goes through `DeviceBridge`, a method channel handled in
  `AppDelegate`. The app binds `MethodChannelDeviceBridge`, tests bind
  `MemoryDeviceBridge`.
- The system is never told about a change directly. `ReminderPlanner` derives the
  whole plan from the store, today through fourteen days ahead, capped under the
  system's limit, and `ReminderSync` hands it over with `replaceAll`. It runs
  after every write, on launch, and when the app comes back to the front.
- Go through the `ReminderScheduler` interface. The app binds
  `LocalReminderScheduler`, tests bind `MemoryReminderScheduler` and read what
  was handed over.
- The icon's number is how many of today's tasks are not done, waved-away
  ones included. `ReminderSync` sets it through `DeviceBridge.setBadge` on
  the same refresh as the notifications, so it is right whenever the app has
  just run and goes stale at midnight until the app is next opened. The
  system shows it only once notifications are allowed; permission is asked
  with the badge in it, and `AppDelegate` grants the badge without a prompt
  to an app allowed before it was asked for.
- Permission is asked for the first time a reminder is chosen, from the editor,
  never at launch. The settings screen shows where it stands through
  `reminderPermissionProvider`, which is invalidated whenever the app comes back
  to the front: not asked yet asks, refused or allowed opens the system's page.
- `AppDelegate` sets itself as the notification centre's delegate before
  handing off to Flutter. Without that line a tapped notification opens the app
  and nothing else; the plugin never hears of it and Dart is never told.
- A notification's payload is `day:key`. Tapping it raises an
  `AttentionRequest`; `AttentionListener` turns the list to that day, waits for
  it to load, pops any screen above the list and puts up the attention sheet. A
  task gone by then opens the day and nothing else.

## Left behind

- What was left undone on earlier days is a `Backlog`, read from the store
  through `Backlog.read`: the last thirty days, tasks not done, waved-away
  ones included. A one-off is an entry of its own; a rule's missed showings
  are gathered under one entry with a count. `backlogProvider` holds it and
  is invalidated by `TodosController` after every write.
- It is raised only on today, as `BacklogRow` above the cards, saying how
  many are left. Tapping it opens `BacklogPage` as a full screen, one card
  per entry, which stays while cards are seen to and goes back by itself
  once none are left. Tapping a card asks what to do on a sheet. Swiping a
  card left uncovers View, which opens `TaskViewPage.of` on the task as it
  stands on its day: read only, no Edit, boxes that do not tick. The cards
  sit in the same `BrandedReorderableList` the day uses, with no drag lift,
  so a swipe feels the same on both.
- A one-off offers Done, Bring to today, Send to future, which asks for a day
  after today on the month grid, and Delete. Brought or sent, it lands on top
  of that day, through `moveToDay` with `toTop`. A rule's entry offers Done,
  Ignore and Delete, each applied to every missed showing: Done writes each
  down finished, Delete hides each, as deleting one showing does, and Ignore
  writes nothing at all, leaving every showing open on its day. The rule goes
  on after each. The options carry no small print; the caption above them,
  "Missed on 3 earlier days" or "Missed yesterday", says what they act on.
  Nothing rolls over on its own, and the icon's number stays today's.
- Ignore is a day on the rule, `ignored_through` in `recurrences`, set to the
  newest day the entry stood for and only ever moved forwards. `Backlog.read`
  passes over a rule's showings on that day and before. The review is about
  the past, so ignoring answers exactly the count that was reported: a day
  missed after it is a fresh miss and is raised again.

## Rich words

- A task's words are a `TaskBody`: a list of blocks, each a paragraph or a
  checklist item, each holding a `StyledText` of plain words plus styled runs.
  A run is a start, an end and a `Styles`: bold, italic, underline, one of three
  named highlights, a link. Runs never overlap and never carry no style.
- The body is stored as JSON in `body` on both `todos` and `recurrences`. The
  plain `title` beside it is derived from the body, never the other way round,
  and is what sorting, notifications and anything without styles read. A row
  with no body is read as its plain title, so old rows need no rewriting.
- `StyledText.replaced` is the one place an edit moves runs. Words typed inside
  a run take its style, and so do words typed straight after it, unless the bar
  set otherwise. Do not adjust runs anywhere else.
- Editing is what-you-see through `BrandedRichController`, a text controller
  that diffs each change against the last, shifts the runs to follow, and paints
  them in `buildTextSpan`. The field underneath is a plain text field, so
  selection, cursor, autocorrect and undo stay the system's.
- Each block is its own field, stacked by `BodyEditor`. A guarded field keeps an
  invisible character in front of the words, because the soft keyboard says
  nothing when backspace is pressed in an empty field; deleting the guard is how
  the start of a block is heard, and the words then join the block above.
  Return hands the words after the caret to a new block of the same kind; on an
  empty checklist item it ends the list instead. There is no selection across
  blocks and undo is per block.
- The format bar, `BrandedFormatBar`, sits over the keyboard on the editor and
  drives the block with the caret: bold, italic, underline, highlight (yellow,
  green, blue, off, in turn), link, checklist and picture. It is dark until a block has
  the caret. A link is asked for on a sheet; with nothing selected the address
  is typed in as the link.
- Highlight colours are the same three in every look, deeper in the dark, in
  `AppTheme.highlightFor`. They are meant to read as a marker pen, not as part
  of the look.
- A card shows the first block, styles and all, through `BrandedRichText`,
  with its box if it is a checklist item, and "2 of 5" in the small print when
  there is a checklist. Tapping a card that is not calling opens `TaskViewPage`,
  where the words are read in full, boxes tick through
  `TodosController.setBody`, links open through the device bridge, and Edit
  leads on. A tick is a thing of the day, like done: a showing of a rule is
  written down and keeps its ticks, and the series is not touched. Under the
  words, the due time and the repeat are shown as the editor's rows without
  chevrons, through `BrandedFieldRow` with no `onTap`; the rule is read
  through `ruleForProvider`. Only what is set is shown.

- A picture is a block of its own, `Block.image`, holding the file name of a
  JPEG in the images folder under the app's documents. The device takes,
  chooses and pastes pictures itself, through `DeviceBridge` and `ImageBridge`
  in Swift, sizing each down and keeping it; Dart only ever sees file names.
  `imagesDirectoryProvider` says where they are, read in `main` before the
  first frame. No picker plugin.
- The bar's picture key asks where the picture comes from on a sheet: camera,
  photos or paste. It lands after the block with the caret, with a paragraph
  after it to carry on writing in. Backspace against a picture takes it out.
- Taking a picture out never deletes its file, since Cancel may put it back,
  and a rule and its written-down showings share files. `ImageSweep` clears
  every file no task or rule refers to, once, after the first frame of each
  launch, through `TodoStore.allImages`.
- Pictures are not words: they are left out of the plain title, a task of
  pictures alone says "Picture" where its words would be, and the card shows
  the card carries no picture.

## UI: the Branded rule

Every visual element is wrapped in a Branded widget, so a change to the look lands
in one place and shows up everywhere.

- Screens compose `BrandedText`, `BrandedIcon`, `BrandedIconButton`,
  `BrandedTextButton`,
  `BrandedFieldRow`, `BrandedOptionRow`,
  `BrandedAppBar`, `BrandedBottomBar`, `BrandedScaffold`, `BrandedCard`,
  `BrandedDragLift`, `BrandedReorderableList`, `BrandedSwipeActions`,
  `BrandedSelectionCircle`, `BrandedTextField`, `BrandedDivider`,
  `BrandedThemeSwatch`, `BrandedRichText`, `BrandedRichField`,
  `BrandedRichController`, `BrandedFormatBar`, `BrandedCheckBox`, `BrandedImage`,
  `BrandedSlideSwitcher`, `BrandedTimeWheel`, `BrandedApp`, `showBrandedSheet`
  and `openBrandedPage`.
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
- The app ships in Ink, `AppThemeChoice.fallback`, which is also what an
  unknown saved name falls back to.
- The look in force is `themeChoiceProvider`. `BrandedApp` is the only widget that
  reads it to build a theme; everything else gets its colours through the
  `ColorScheme`, so a new look needs no widget changes.
- `main` reads the saved look before the first frame and binds it to
  `initialThemeChoiceProvider`, so the app never flashes one look and switches.
- Flat means no Material elevation and no ripple. Keep splash and highlight
  transparent. The one shadow is the open card's, a touch drawn by
  `BrandedCard` from the `Brand.shadow` constants; nothing else casts one.
- Cap content width for iPad rather than letting rows stretch. `BrandedScaffold`
  already does this; check a phone and a tablet before calling a layout done.
- No splash screen. The launch storyboard stays a blank system-coloured view.

## Interaction

- Writing a task never happens inline. Both adding and editing push
  `TaskEditorPage` as a full screen, which returns the body through the navigator.
  Save is greyed and inert until there are words; Cancel is never greyed.
- The editor asks for the keyboard only once its slide-in has finished, by
  listening to the route's animation. Raised during the transition it fights the
  slide and the whole thing judders. No `autofocus` on that field.
- A reminder at the time itself is named by the time, `At 8:00 AM`, never "at
  the time". The label needs the minute, so it lives on `Due`, not as a static.
- The due and repeat sheets come down only through their own buttons; a swipe
  or a tap outside does nothing there. Every other sheet is dismissible.
- The editor's Due row sits above Repeat and opens a sheet: a time wheel, the
  reminder choices, any number of which can be ticked, a Sound row that opens its
  own sheet and plays each sound as it is tapped, then Clear and Done. It hands
  back a `DuePick`, so backing out can be told from clearing. The row reads the
  time with the reminders summed up as small print.
- A task row carries no checkbox of its own for done. Done, edit and delete
  live on the swipe buttons and nowhere else; there is no action sheet. A tap on
  a card opens it to be read, or puts up the attention sheet if it is calling.
- A calling card's tap puts up the attention sheet instead of the read view:
  the task's words in full, then Done, Snooze and Dismiss. The same sheet
  answers a tapped notification, so the context is there whichever way it came.
- A calling card breathes: `BrandedCard.calling` leans the border and face into
  the accent and back, without end, until answered. Under reduce motion it holds
  the leaning colour still. Widget tests that show a calling card must call
  `holdStill`, or `pumpAndSettle` never settles.
- The words get the card's whole width. Everything else about a task, the repeat
  glyph, a bell when a reminder is set and the time, sits in small print on a
  second line underneath, and takes the accent while the card is calling.
- Each task is a bordered card, not a row with a rule between, lifted off the
  page by the one shadow in the app. Completed cards are recessed onto the
  raised surface colour and carry no shadow.
- A card shows up to `Brand.cardLines` lines of the words, two, in the `card`
  text role, and ellipsises past that. A task may still hold more text, written
  on the editor screen. `Todo.firstLine` is what a notification says.
- `BrandedText` picks its own reading direction from its content, so an Arabic or
  Hebrew task sits against the right edge of its card. Never pass a direction in
  from a screen.
- Direction comes from the first strong letter, not the first character. Digits,
  punctuation and emoji carry no direction and are skipped, so `"1. مرحبا"` reads
  right to left. `brandedTextDirection` is the one place that decides.
- A sideways flick across the day, above the bottom bar, turns the page a day
  at a time through `DaySwiper`. On a card the card's own swipe wins, as the
  nearer gesture. The arrows and the month grid remain.
- A change of day slides: the old page out, the new one in from the side the
  change came from, through `BrandedSlideSwitcher` keyed on the day. Forwards
  in time comes from the right. The header and the list are told which day they
  are for, and the list keeps showing what it last showed while its day slides
  out, so the outgoing page never flashes the new day's tasks.
- Swiping left uncovers Not Today, a stacked NOT / TODAY glyph, then Delete.
  Not Today is only there on an open task. It opens the month grid through
  `showDayPicker`, which takes any day, past or to come, but greys the day
  itself and offers no shortcut to today; picking a day moves the task there,
  to the end of that day's open group, through `TodoStore.moveToDay`. Backing
  out moves nothing. The picker takes an `isAllowed` predicate, so each
  caller says which days are open.
- A rule cannot have one showing moved. Not Today on a repeating task hides
  today's showing and writes a one-off copy of the words and time on the chosen
  day. The copy has left the series: it repeats never and later edits to the
  series do not reach it. This is never asked about.
- The attention sheet offers Not Today too, between Snooze and Dismiss, with the
  same grid and the same move.
- In developer mode an alarm button sits between Not Today and Delete. It asks
  which sound, then rings the task's own reminder in it ten seconds later,
  shown even in front, through `ReminderScheduler.rehearse`, so the
  notification path can be tried without waiting for a real time.
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
  edit, swiping left uncovers not today and delete.
- The card squeezes to make room rather than sliding off the screen edge, so it
  keeps both of its rounded ends.
- One row is open at a time. The list owns a `BrandedSwipeGroup` and hands it to
  every row, which closes the last one when another opens.
- The task actions are named once in `task_actions.dart`, so their icons and
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
- A repeating card carries a repeat glyph in its small print, never beside the
  words.
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
- Settings ends with an About section showing the version, `appVersion` in
  `lib/core/app_version.dart`, kept by hand beside `pubspec.yaml`, as a
  plain label with no chevron, so nobody is invited to tap it. Ten taps on it
  still turn developer mode on, saved under `developer` through
  `developerModeProvider`; a single button under the version then turns it
  off. Developer mode only ever adds tools, never changes behaviour.
- The sound chosen last is saved under `sound` and is what a new reminder
  starts from, through `lastSoundProvider`; `main` reads it before the first
  frame like the look.
- The looks are offered on a sheet from the Theme row. A choice applies the
  moment it is tapped, and the sheet stays up so the change is seen behind it.
  There is no save step.
- Each look has its own app icon, drawn flat in the look's colour with a white
  check. Ink is the primary `AppIcon`; the others are alternate icon sets
  named `AppIcon-<look>`, listed in the project's alternate icon names setting.
  Choosing a look swaps the icon through `DeviceBridge`. The system puts up its
  own alert when it does; that cannot be avoided.
- `BrandedAppBar` gives its two sides equal room, so the title sits on the
  screen's centre line whether or not anything stands beside it. The date under
  the day headline uses the short month name.

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
