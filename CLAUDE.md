# Yesterdo

A day-at-a-time todo list for iPhone and iPad. Local first and no account of
its own: a device signed into iCloud syncs its tasks with the others on the
same account, and one that is not stays local. The code is the source of
truth for what the app does; this file holds only the rules for working on
it.

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
- Do not drive the simulator by hand: no scripted clicks or keystrokes
  through AppleScript or the like. Widget tests are the check; the app on
  a device is tried by the user.
- A stale `build/` directory causes a lipo failure on the next build. Clear it
  with `fvm flutter clean`.

## Deploy

- Every deploy raises the version in `pubspec.yaml` first, by the size of
  what changed since the last one: patch for fixes, minor for a new
  feature, major for a change to how the app works or to its data that
  cannot be gone back on. The build number after the `+` goes up by one
  every time.
- Deploy means run `tool/deploy.sh` and answer with the link it prints. It
  builds an ad hoc IPA through `ios/ExportOptions.plist` and uploads it to
  the ios-app-hoster on the Pi (`~/Documents/code/alkait/ios-app-hoster`,
  served at `https://ios-apps.alkait.xyz`). Every deploy gives a new link,
  and the page behind it lists the earlier builds too.
- The hoster token is `HOSTER_TOKEN` in `.env`, which git ignores. It is
  never committed or written into a reply.
- The link installs only on devices registered with the team. A new device
  is registered first, then the app is deployed again.

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

- Storage is local SQLite. The one thing that leaves the device is the
  sync, through CloudKit; no other network calls, no analytics packages.
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
- A pin is a thing of the day, like done: it lives on the row, never on a
  rule, so a rule's showing is written down to be pinned. Done lets go of
  it, in `Todo.toggled`, and undoing done does not bring it back. A day
  reads calling, pinned, open, done; that order is `compareTodos` and
  `todoOrderOn`, and a drag keeps to its own band. A pin goes with a task
  to another day.
- Carry over is a one-off's own flag, `carryOver`, never a rule's. A task
  left undone with it on is brought to the head of today by
  `TodoStore.carryForward`, however long ago it was left, before any day
  is read: the controller runs it on build and on every reload, and nothing
  announces it. `composeCarryForward` and `composeDaysAhead` are the one
  place each lives, so both stores answer alike. The planners read the days
  ahead through `daysAhead`, so a carried task is reminded of and pinned
  on tomorrow before the app is opened; Due now is not read ahead, since a
  widget cannot tell one showing from the next. Left behind passes a
  carrying task over.
- `Todo.id` is null while a task is only projected. Key widgets, swipe state
  and sort ties on `Todo.key`, never on the id.
- Questions about a rule's showings, such as whether it has any before or
  after a day, are answered on `RepeatRule`. Do not reason about them in a
  widget.
- The schema is versioned. Add an `onUpgrade` branch and cover it in
  `test/migration_test.dart`, which runs against real SQLite.
- Every row has a `uid`, which is what it is called on every device; the
  integer `id` is this device's own and never crosses. A rule's showing is
  named by `occurrenceUid`, from the rule's uid and the day, so two devices
  acting on the same showing write one row, not two. `Todo.key` stays on
  the local id.
- The `Due.reminderChoices` bitmask is ordered. Add a choice at the end or
  every saved set shifts.
- A task's plain `title` is derived from its `TaskBody`, never the other way
  round. `StyledText.replaced` is the one place an edit moves style runs; do
  not adjust runs anywhere else.
- A search match is decided in `matchesSearch` and nowhere else. A store
  may narrow its read first, as `SqliteTodoStore` does with `LIKE`, but
  every row it lets through is checked there. Results are composed once,
  in `composeSearch`, so both stores answer alike: a rule answers once, on
  its showing nearest today, never once per day.
- Recent searches are a setting, through `RecentSearches`. A search is
  remembered when submitted or when a result is opened, never as typed.
- Pictures are the device's business, through `DeviceBridge` and
  `ImageBridge` in Swift. Dart only ever sees file names. No picker plugin.
  Never delete a picture file directly; `ImageSweep` clears unreferenced
  ones through `TodoStore.allImages`.

## Sync

- Sync is on whenever the device is signed into iCloud, with no switch. It
  goes through CloudKit's private database, in Swift, behind `CloudBridge`
  and the `remindme/cloud` channel. Swift only moves records; what a record
  holds, and whose write wins, is Dart's. No plugin.
- Every write in a store stamps the row's `updated_at` and logs its uid in
  the change log; a removal logs a tombstone. `pendingChanges` reads the
  log, `clearPending` lets go of what was sent, `applyRemote` takes in what
  came. A new store method that writes does the same, in both stores.
- `takesIncoming` is the one place that decides whose write wins: the
  latest write, and a removal beats an edit either way. A row not written
  here since the last send is always taken, so both sides end up alike.
- `CloudSync` is the one thing that talks to the transport: it pulls, then
  pushes, so what goes up has been judged against what was there. It is
  nudged after every write, on launch, on return to the front and on a
  silent push, and never awaited by the interface. After a pull that
  changed the store, `onPulled` reads the day again; `main` wires it.
- Only tasks and rules cross. Settings are each device's own. Pictures go
  with their record as assets and come down under the same file names, so
  Dart still only ever sees names; the sweep runs before the first pull.
- The CloudKit container is `iCloud.com.alkait.yesterdo`, in the
  Development environment for the ad hoc builds. The entitlements say so,
  and so must `iCloudContainerEnvironment` in `ios/ExportOptions.plist`,
  since the export re-signs the app and switches it to Production
  otherwise, where no record type is ever made on the fly. Deploying the
  schema to Production is a step in the CloudKit console, not in code.
- Tests bind `MemoryCloudTransport` over a `MemoryCloud` and sync two
  stores through it; widget tests leave `cloudTransportProvider` alone,
  which is no cloud at all.

## Reminders and the device

- `flutter_local_notifications` is the one plugin the app carries. Nothing
  else may be added for it. What only the device can do goes through
  `DeviceBridge`, a method channel handled in `AppDelegate`; the cloud has
  its own, `remindme/cloud`. The app binds `MethodChannelDeviceBridge`,
  tests bind `MemoryDeviceBridge`.
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

## Widgets

- There are two widgets, Due now and Pinned, in one WidgetKit extension,
  `ios/YesterdoWidget`. Due now keeps the kind `YesterdoWidget` it first
  shipped under; changing a kind takes the widget off every screen. No plugin, and no second copy of the app's rules:
  Dart works out what they show, Swift only draws it.
- The app and the extension share one file, `glance.json`, in the app group
  `group.com.alkait.yesterdo`. It is the only thing that crosses; the
  extension never opens the database.
- `GlancePlanner` derives the whole glance from the store and `GlanceSync`
  hands it over with `showOnWidgets`, after every write, on launch, on
  return to the front, and when the look changes. A widget is never told
  about a single change.
- The glance reaches from the backlog's own window back to tomorrow, so a
  task left calling from an earlier day still shows and the widgets are
  still right after midnight without the app being opened.
- Only tasks that can call cross over as `tasks`. A task with no time, one
  already done, one waved away and a missed showing that was let go are no
  use to Due now and are never sent. The pinned tasks of today and
  tomorrow cross beside them as `pinned`, time or no time, each with the
  moment its day begins; Pinned draws the ones of the day being drawn.
- Due now shows the tasks calling for attention and nothing else; with
  nothing calling it says so. A task from another day says its day beside
  its time, since a widget can carry a task left calling from an earlier
  day; that is drawing, so it is Swift's, judged against the entry's date.
- `Todo.isCallingOn` stays the one place that decides what calling means.
  The planner turns it into a moment, `callsAt`, and the widget only ever
  compares that with the moment being drawn. The timeline holds an entry at
  every `callsAt` to come, which is what lets a task fall due on the Lock
  Screen with the app closed.
- Colours reach the widgets as the accent from `AppTheme.schemeFor`, in both
  brightnesses, since the system decides which a widget is drawn in.
- A tapped widget opens `yesterdo://task/<day>:<key>`, the payload
  `taskPayload` names for notifications too. A shape that lists several
  tasks gives each row its own `Link`; `widgetURL` alone opens the first
  whatever was tapped. `SceneDelegate` holds it and
  Dart takes it with `takeTappedTask`; it is handed over once.
- `GlanceSync` cannot be refreshed from `ThemeChoice`: it is drawn in the
  chosen look, so it already depends on it. `main` listens instead.

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
- The editor's rows are Date, Time, Reminder, Repeat and Pin, one thing
  each. Pin is a switch, absent for a done task.
  A reminder hangs off the time: its row is inert until a time is set, and
  clearing the time clears the reminders with it. `Due` still holds all
  three together in the data.
- The editor asks for the keyboard only once its slide-in has finished, by
  listening to the route's animation. No `autofocus` on that field.
- Pin lives on the read view as the same switch row the editor has, on
  the attention sheet beside View, and on the editor's Pin row, and
  nowhere else. From the editor it rides
  the `TaskDraft`; for a repeating task it pins the showing on the day,
  never the rule. On the sheet it toggles and the sheet stays up,
  so the sheet reads its task afresh from `todosProvider`. A done task and
  one opened from Left behind offer no pin.
- Carry over is a switch under Pin, in the editor and on the read view,
  and nowhere else. It is absent for a done task and, like Date, for a
  repeating one; choosing a repeat drops it. No mark on the card.
- Done is the circle on the card, and the attention sheet's Done. Edit and
  delete live on the swipe buttons and nowhere else; there is no action
  sheet.
- A card that changes place in the order flies there through `TodoFlight`.
  Do not let a card jump. A checklist item on the read view flies the same
  way when a tick sends it to the foot of its list; `singleMove` is the one
  judge of what counts as a move.
- The banner that says where a task went floats over Left behind as well
  as over the day, so a task brought to today or sent on from there is
  announced where the sending was done. Its Go comes out to the list.
  Left behind never turns the list or leaves on its own, even once it is
  empty: Back or Go is the way out.
- A card pointed out, as one a search found or one the banner's Go leads
  to, is `spotlit`: it takes the calling card's breath a couple of times
  and settles. It is asked for through `spotlightProvider` and the list
  answers it once. Do not invent a second way of drawing the eye to a card.
- The day header has no arrows: they read as Back. A swipe across the
  page is the way to the next or the previous day. Every jump to a day,
  from the month grid, a search, the banner's Go, Left behind or a
  notification, goes through `SelectedDay.select`, which remembers the day
  left in `sentFromProvider`; the header then offers Back, which returns
  there through `goBack`. A swipe lets the way back go.
- A swipe never acts on its own. It uncovers buttons and nothing happens
  until one is tapped.
- A tick is made on the read view and nowhere else. The editor draws
  every box open: a tick already made is carried through an edit unseen,
  and a ticked line pasted in comes in open. A rule never holds a tick;
  `Recurrence` unticks whatever it is built from, and `saveSeries` gives
  each written showing the new words with its own ticks, through
  `TaskBody.withTicksOf`.
- Words pasted into the editor make a block per line, and a line headed by
  a bullet or a box becomes a checklist item. `LineMarker` is the one place
  that knows the marks; the controller only cuts at the breaks.
- A tick on the read view is heard the way done is, through `playDone`
  and the same sound setting; an untick is silent.
- On the read view an open checklist item lifts on a press and hold and
  moves among the open items of its own run, never past a paragraph or a
  picture. A ticked item sinks to the foot of its run and holds it, as a
  done task holds the foot of the day, remembering where it stood in
  `Block.home`; unticked, it goes back to about there. Both go through `TaskBody`, `reordered` and `ticked`,
  and are written through `setBody`, so a rule's showing changes for that
  day alone and the series keeps its order. A task opened from Left behind
  neither ticks nor moves. A reorderable list's drop index already counts
  the lifted item as gone; do not adjust it again.
- Share, on the read view, hands over the words alone through
  `TaskBody.shareText`: a line per block, a box before a checklist item,
  pictures left out. No day, time or repeat crosses. The sheet is the
  system's, reached through `DeviceBridge.share`.
- The task actions are named once in `task_actions.dart`, so their icons and
  labels cannot drift.
- Developer mode only ever adds tools, never changes behaviour.
- The version shown in Settings is read from the bundle through
  `DeviceBridge.appVersion` and bound to `appVersionProvider` in `main`.
  `pubspec.yaml` is the one place it is written.

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

## Answering

- Keep replies short. Answer what was asked and stop.
- Do not end an answer with an offer, a next step or a question. If a
  decision is genuinely needed, ask it plainly and on its own.
